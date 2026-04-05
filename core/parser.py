from __future__ import annotations

import logging
from typing import Iterable, Optional, Sequence

from .models import FFTBin, FFTFrame, ParserTelemetry, RawSPITransaction
from .protocol import (
    DEFAULT_SOF,
    DEFAULT_TYPE,
    DEFAULT_VERSION,
    PART_IMAG,
    PART_REAL,
    decode_data_word,
    mask_u32,
)


class FrameParseError(ValueError):
    category = "frame"


class HeaderValidationError(FrameParseError):
    category = "header"


class CountMismatchError(FrameParseError):
    category = "count"


class PayloadValidationError(FrameParseError):
    category = "payload"


class SPIFrameParser:
    def __init__(
        self,
        *,
        expected_sof: int = DEFAULT_SOF,
        expected_version: int = DEFAULT_VERSION,
        expected_type: int = DEFAULT_TYPE,
        include_raw_words: bool = False,
        logger: Optional[logging.Logger] = None,
    ) -> None:
        self.expected_sof = expected_sof
        self.expected_version = expected_version
        self.expected_type = expected_type
        self.include_raw_words = include_raw_words
        self.logger = logger or logging.getLogger(__name__)
        self.telemetry = ParserTelemetry()

    def parse_transaction(self, transaction: RawSPITransaction) -> FFTFrame:
        return self.parse_words(
            transaction.words,
            timestamp_host_ns=transaction.timestamp_host_ns,
            source=transaction.source,
            metadata=transaction.metadata,
        )

    def parse_words(
        self,
        words: Sequence[int],
        *,
        timestamp_host_ns: int,
        source: str,
        metadata: Optional[dict[str, object]] = None,
    ) -> FFTFrame:
        normalized_words = tuple(mask_u32(word) for word in words)
        self.telemetry.note_received(source=source, timestamp_host_ns=timestamp_host_ns)

        try:
            if len(normalized_words) < 3:
                raise HeaderValidationError(
                    f"Frame must contain at least 3 header words, got {len(normalized_words)}."
                )

            header0, header1, header2 = normalized_words[:3]
            sof = (header0 >> 16) & 0xFFFF
            version = (header0 >> 8) & 0xFF
            frame_type = header0 & 0xFF

            if sof != self.expected_sof:
                raise HeaderValidationError(
                    f"Invalid SOF: expected 0x{self.expected_sof:04X}, got 0x{sof:04X}."
                )
            if version != self.expected_version:
                raise HeaderValidationError(
                    f"Invalid VERSION: expected 0x{self.expected_version:02X}, got 0x{version:02X}."
                )
            if frame_type != self.expected_type:
                raise HeaderValidationError(
                    f"Invalid TYPE: expected 0x{self.expected_type:02X}, got 0x{frame_type:02X}."
                )

            seq = (header1 >> 16) & 0xFFFF
            count_words = header1 & 0xFFFF
            flags = (header2 >> 16) & 0xFFFF
            exp = header2 & 0xFFFF

            payload_words = normalized_words[3:]
            payload_count = len(payload_words)
            if payload_count != count_words:
                mismatch_kind = "truncated" if payload_count < count_words else "longer than COUNT"
                raise CountMismatchError(
                    f"Payload is {mismatch_kind}: COUNT={count_words}, received={payload_count}."
                )
            if count_words % 2 != 0:
                raise CountMismatchError(
                    f"COUNT must be even because each bin has real+imag words, got {count_words}."
                )

            bins: list[FFTBin] = []
            current_real_word = None
            for index, raw_word in enumerate(payload_words):
                decoded = decode_data_word(raw_word)
                expected_bin_id = index // 2
                expected_part = PART_REAL if index % 2 == 0 else PART_IMAG

                if decoded.bin_id != expected_bin_id:
                    raise PayloadValidationError(
                        f"Unexpected BIN_ID at payload index {index}: expected {expected_bin_id}, got {decoded.bin_id}."
                    )
                if decoded.part != expected_part:
                    expected_name = "real" if expected_part == PART_REAL else "imag"
                    got_name = "real" if decoded.part == PART_REAL else "imag"
                    raise PayloadValidationError(
                        f"Unexpected PART at payload index {index}: expected {expected_name}, got {got_name}."
                    )

                if decoded.part == PART_REAL:
                    current_real_word = decoded
                    continue

                if current_real_word is None:
                    raise PayloadValidationError("Imaginary payload word arrived before its real pair.")

                bins.append(
                    FFTBin(
                        bin_id=decoded.bin_id,
                        real=current_real_word.value,
                        imag=decoded.value,
                        flags_real=current_real_word.flags_local,
                        flags_imag=decoded.flags_local,
                    )
                )
                current_real_word = None

            if current_real_word is not None:
                raise PayloadValidationError("Frame ended with a dangling real payload word.")

            frame = FFTFrame(
                seq=seq,
                count_words=count_words,
                flags=flags,
                exp=exp,
                bins=tuple(bins),
                timestamp_host_ns=timestamp_host_ns,
                source=source,
                raw_words=normalized_words if self.include_raw_words else None,
                metadata=dict(metadata or {}),
            )
            self.telemetry.note_success(seq=seq, timestamp_host_ns=timestamp_host_ns)
            return frame
        except FrameParseError as exc:
            self.telemetry.note_invalid(category=exc.category, timestamp_host_ns=timestamp_host_ns)
            self.logger.warning("Invalid SPI FFT frame from %s: %s", source, exc)
            raise

    def parse_many(self, transactions: Iterable[RawSPITransaction]) -> list[FFTFrame]:
        return [self.parse_transaction(transaction) for transaction in transactions]
