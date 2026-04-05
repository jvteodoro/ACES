from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, Sequence

from .models import FFTBin


DEFAULT_SOF = 0xA55A
DEFAULT_VERSION = 0x01
DEFAULT_TYPE = 0x01

PART_REAL = 0
PART_IMAG = 1

MAX_BIN_ID = 0x1FF
VALUE_BITS = 18
VALUE_MIN = -(1 << (VALUE_BITS - 1))
VALUE_MAX = (1 << (VALUE_BITS - 1)) - 1


@dataclass(frozen=True)
class DecodedPayloadWord:
    bin_id: int
    part: int
    flags_local: int
    value: int


def mask_u32(value: int) -> int:
    return int(value) & 0xFFFFFFFF


def sign_extend(value: int, bits: int) -> int:
    mask = (1 << bits) - 1
    value &= mask
    sign_bit = 1 << (bits - 1)
    return value - (1 << bits) if value & sign_bit else value


def encode_signed(value: int, bits: int) -> int:
    min_value = -(1 << (bits - 1))
    max_value = (1 << (bits - 1)) - 1
    if value < min_value or value > max_value:
        raise ValueError(f"Signed value {value} does not fit in {bits} bits.")
    return value & ((1 << bits) - 1)


def pack_header_word0(
    *,
    sof: int = DEFAULT_SOF,
    version: int = DEFAULT_VERSION,
    frame_type: int = DEFAULT_TYPE,
) -> int:
    return mask_u32(((sof & 0xFFFF) << 16) | ((version & 0xFF) << 8) | (frame_type & 0xFF))


def pack_header_word1(*, seq: int, count: int) -> int:
    return mask_u32(((seq & 0xFFFF) << 16) | (count & 0xFFFF))


def pack_header_word2(*, flags: int = 0, exp: int = 0) -> int:
    return mask_u32(((flags & 0xFFFF) << 16) | (exp & 0xFFFF))


def encode_data_word(*, bin_id: int, part: int, flags_local: int = 0, value: int) -> int:
    if bin_id < 0 or bin_id > MAX_BIN_ID:
        raise ValueError(f"bin_id must be in [0, {MAX_BIN_ID}], got {bin_id}.")
    if part not in (PART_REAL, PART_IMAG):
        raise ValueError(f"part must be 0 or 1, got {part}.")
    encoded_value = encode_signed(value, VALUE_BITS)
    return mask_u32(
        ((bin_id & 0x1FF) << 23)
        | ((part & 0x1) << 22)
        | ((flags_local & 0xF) << 18)
        | encoded_value
    )


def decode_data_word(word: int) -> DecodedPayloadWord:
    word = mask_u32(word)
    return DecodedPayloadWord(
        bin_id=(word >> 23) & 0x1FF,
        part=(word >> 22) & 0x1,
        flags_local=(word >> 18) & 0xF,
        value=sign_extend(word & 0x3FFFF, VALUE_BITS),
    )


def assemble_frame_words(
    *,
    seq: int,
    payload_words: Sequence[int],
    flags: int = 0,
    exp: int = 0,
    sof: int = DEFAULT_SOF,
    version: int = DEFAULT_VERSION,
    frame_type: int = DEFAULT_TYPE,
) -> tuple[int, ...]:
    payload = tuple(mask_u32(word) for word in payload_words)
    header = (
        pack_header_word0(sof=sof, version=version, frame_type=frame_type),
        pack_header_word1(seq=seq, count=len(payload)),
        pack_header_word2(flags=flags, exp=exp),
    )
    return header + payload


def build_frame_words(
    *,
    seq: int,
    bins: Sequence[FFTBin],
    flags: int = 0,
    exp: int = 0,
    sof: int = DEFAULT_SOF,
    version: int = DEFAULT_VERSION,
    frame_type: int = DEFAULT_TYPE,
) -> tuple[int, ...]:
    payload_words: list[int] = []
    for fft_bin in bins:
        payload_words.append(
            encode_data_word(
                bin_id=fft_bin.bin_id,
                part=PART_REAL,
                flags_local=fft_bin.flags_real,
                value=fft_bin.real,
            )
        )
        payload_words.append(
            encode_data_word(
                bin_id=fft_bin.bin_id,
                part=PART_IMAG,
                flags_local=fft_bin.flags_imag,
                value=fft_bin.imag,
            )
        )
    return assemble_frame_words(
        seq=seq,
        payload_words=payload_words,
        flags=flags,
        exp=exp,
        sof=sof,
        version=version,
        frame_type=frame_type,
    )


def build_bins(values: Iterable[tuple[int, int]], *, start_bin_id: int = 0) -> tuple[FFTBin, ...]:
    bins: list[FFTBin] = []
    for offset, (real, imag) in enumerate(values):
        bins.append(FFTBin(bin_id=start_bin_id + offset, real=real, imag=imag))
    return tuple(bins)


def words_to_bytes(words: Sequence[int], *, byteorder: str = "big") -> bytes:
    chunks = [mask_u32(word).to_bytes(4, byteorder=byteorder, signed=False) for word in words]
    return b"".join(chunks)


def bytes_to_words(raw: bytes | bytearray, *, byteorder: str = "big") -> tuple[int, ...]:
    data = bytes(raw)
    if len(data) % 4 != 0:
        raise ValueError(f"Byte payload length must be a multiple of 4, got {len(data)}.")
    return tuple(int.from_bytes(data[index : index + 4], byteorder=byteorder, signed=False) for index in range(0, len(data), 4))
