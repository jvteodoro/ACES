from __future__ import annotations

import ctypes
import importlib.util
import os
import sys
import time
from ctypes import byref, c_char, c_double, c_int, c_ubyte
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence

DEFAULT_LIBRARY_CANDIDATES = (
    os.environ.get("DWF_LIBRARY_PATH"),
    r"C:\Program Files (x86)\Digilent\WaveFormsSDK",
    r"C:\Program Files\Digilent\WaveFormsSDK",
    r"C:\Program Files (x86)\Digilent\WaveForms3\dwf.dll",
    r"C:\Program Files\Digilent\WaveForms3\dwf.dll",
    "dwf",
    "dwf.dll",
    r"C:\Program Files (x86)\Digilent\WaveFormsSDK\lib\x64\dwf.dll",
    r"C:\Program Files\Digilent\WaveFormsSDK\lib\x64\dwf.dll",
)

DEFAULT_DWFCONSTANTS_CANDIDATES = (
    os.environ.get("DWF_PYTHON_SAMPLES_PATH"),
    r"C:\Program Files (x86)\Digilent\WaveFormsSDK\samples\py",
    r"C:\Program Files\Digilent\WaveFormsSDK\samples\py",
    "/mnt/c/Program Files (x86)/Digilent/WaveFormsSDK/samples/py",
    "/mnt/c/Program Files/Digilent/WaveFormsSDK/samples/py",
)


class WaveFormsError(RuntimeError):
    pass


class WaveFormsLibraryNotFound(WaveFormsError):
    pass


class WaveFormsDeviceError(WaveFormsError):
    pass


class WaveFormsDemoUnavailable(WaveFormsDeviceError):
    pass


def _coerce_c_int(value: object, fallback: int) -> int:
    if value is None:
        return fallback
    return int(getattr(value, "value", value))


def _load_dwfconstants_module():
    try:
        import dwfconstants as module  # type: ignore

        return module
    except ImportError:
        pass

    for candidate in DEFAULT_DWFCONSTANTS_CANDIDATES:
        if not candidate:
            continue

        candidate_path = Path(candidate)
        module_path = candidate_path / "dwfconstants.py" if candidate_path.is_dir() else candidate_path
        if not module_path.is_file():
            continue

        spec = importlib.util.spec_from_file_location("dwfconstants", module_path)
        if spec is None or spec.loader is None:
            continue

        module = importlib.util.module_from_spec(spec)
        sys.modules.setdefault("dwfconstants", module)
        spec.loader.exec_module(module)
        return module

    return None


_DWFCONSTANTS = _load_dwfconstants_module()
DwfDigitalOutTypeCustom = _coerce_c_int(
    getattr(_DWFCONSTANTS, "DwfDigitalOutTypeCustom", None),
    5,
)
ENUMFILTER_TYPE = _coerce_c_int(
    getattr(_DWFCONSTANTS, "enumfilterType", None),
    0x8000000,
)
ENUMFILTER_DEMO = _coerce_c_int(
    getattr(_DWFCONSTANTS, "enumfilterDemo", None),
    0x4000000,
)


def _expand_library_candidate(candidate: str) -> list[str]:
    path = Path(candidate)
    if path.suffix.lower() == ".dll":
        return [str(path)]

    if path.name.lower() == "waveformssdk":
        return [
            str(path / "lib" / "x64" / "dwf.dll"),
            str(path / "lib" / "dwf.dll"),
            str(path / "dwf.dll"),
        ]

    if path.is_dir():
        return [
            str(path / "dwf.dll"),
            str(path / "lib" / "x64" / "dwf.dll"),
        ]

    return [candidate]


def _load_library(library_path: str | None = None) -> ctypes.CDLL:
    raw_candidates = [library_path] if library_path else list(DEFAULT_LIBRARY_CANDIDATES)
    last_error: Exception | None = None
    expanded_candidates: list[str] = []
    for candidate in raw_candidates:
        if not candidate:
            continue
        expanded_candidates.extend(_expand_library_candidate(str(candidate)))

    for candidate in expanded_candidates:
        try:
            return ctypes.cdll.LoadLibrary(candidate)
        except OSError as exc:
            last_error = exc
            continue
    raise WaveFormsLibraryNotFound(
        "Unable to load WaveForms SDK library. Set DWF_LIBRARY_PATH to the WaveFormsSDK root or directly to dwf.dll."
    ) from last_error


def pack_bits_lsb_first(bits: Sequence[int]) -> bytes:
    packed = bytearray((len(bits) + 7) // 8)
    for index, bit in enumerate(bits):
        if bit:
            packed[index // 8] |= 1 << (index % 8)
    return bytes(packed)


def extract_channel_bits(samples: Sequence[int], *, pin: int) -> list[int]:
    mask = 1 << pin
    return [1 if sample & mask else 0 for sample in samples]


def build_spi_bus_samples(
    *,
    frames: Sequence[Sequence[int]],
    sample_rate_hz: int,
    spi_clock_hz: int,
    cs_pin: int,
    clk_pin: int,
    data_pin: int,
    cpol: int = 0,
    cpha: int = 0,
    byteorder: str = "big",
    inter_frame_idle_bits: int = 2,
    idle_level_data: int = 0,
) -> list[int]:
    if sample_rate_hz < 2 * spi_clock_hz:
        raise ValueError("sample_rate_hz must be at least 2x spi_clock_hz.")

    samples_per_half = max(1, round(sample_rate_hz / (2 * spi_clock_hz)))
    cs_idle = 1
    cs_active = 0
    clk_idle = cpol & 0x1
    clk_active = 1 - clk_idle

    def sample_word(*, cs: int, clk: int, data: int) -> int:
        value = 0
        if cs:
            value |= 1 << cs_pin
        if clk:
            value |= 1 << clk_pin
        if data:
            value |= 1 << data_pin
        return value

    samples: list[int] = []
    idle_samples = max(1, inter_frame_idle_bits * 2 * samples_per_half)
    samples.extend(sample_word(cs=cs_idle, clk=clk_idle, data=idle_level_data) for _ in range(idle_samples))

    for frame in frames:
        frame_bytes = b"".join(int(word & 0xFFFFFFFF).to_bytes(4, byteorder=byteorder, signed=False) for word in frame)
        bits: list[int] = []
        for byte in frame_bytes:
            for bit_index in range(7, -1, -1):
                bits.append((byte >> bit_index) & 0x1)

        if not bits:
            continue

        for bit in bits:
            if cpha == 0:
                samples.extend(sample_word(cs=cs_active, clk=clk_idle, data=bit) for _ in range(samples_per_half))
                samples.extend(sample_word(cs=cs_active, clk=clk_active, data=bit) for _ in range(samples_per_half))
            else:
                samples.extend(sample_word(cs=cs_active, clk=clk_active, data=bit) for _ in range(samples_per_half))
                samples.extend(sample_word(cs=cs_active, clk=clk_idle, data=bit) for _ in range(samples_per_half))

        samples.extend(sample_word(cs=cs_idle, clk=clk_idle, data=idle_level_data) for _ in range(idle_samples))

    return samples


@dataclass
class WaveFormsDevice:
    device_index: int = -1
    library_path: str | None = None
    demo_mode: bool = False
    demo_device_name: str | None = None
    _dwf: ctypes.CDLL | None = None
    _handle: c_int | None = None

    @property
    def dwf(self) -> ctypes.CDLL:
        if self._dwf is None:
            self._dwf = _load_library(self.library_path)
        return self._dwf

    @property
    def handle(self) -> c_int:
        if self._handle is None:
            raise WaveFormsDeviceError("WaveForms device is not open.")
        return self._handle

    def __enter__(self) -> "WaveFormsDevice":
        self.open()
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()

    def open(self) -> None:
        if self._handle is not None:
            return

        if self.demo_mode:
            self._open_demo_device()
            return

        handle = c_int()
        result = self.dwf.FDwfDeviceOpen(c_int(self.device_index), byref(handle))
        if result == 0 or handle.value == 0:
            raise WaveFormsDeviceError(self.last_error_message())
        self._handle = handle

    def _open_demo_device(self) -> None:
        demo_count = c_int()
        self.ensure_success(
            self.dwf.FDwfEnum(c_int(ENUMFILTER_TYPE | ENUMFILTER_DEMO), byref(demo_count)),
            operation="FDwfEnum(enumfilterType|enumfilterDemo)",
        )
        if demo_count.value <= 0:
            raise WaveFormsDemoUnavailable("WaveForms SDK did not expose any demo device.")

        selected_index = self._select_demo_index(demo_count.value)
        handle = c_int()
        result = self.dwf.FDwfDeviceOpen(c_int(selected_index), byref(handle))
        if result == 0 or handle.value == 0:
            raise WaveFormsDemoUnavailable(self.last_error_message())
        self._handle = handle

    def _select_demo_index(self, device_count: int) -> int:
        if self.device_index >= 0:
            if self.device_index >= device_count:
                raise WaveFormsDemoUnavailable(
                    f"Requested demo device index {self.device_index} but only {device_count} demo devices were enumerated."
                )
            return self.device_index

        if self.demo_device_name:
            target = self.demo_device_name.casefold()
            for index in range(device_count):
                if self.enum_device_name(index).casefold() == target:
                    return index
            for index in range(device_count):
                if target in self.enum_device_name(index).casefold():
                    return index
            raise WaveFormsDemoUnavailable(
                f"Requested demo device {self.demo_device_name!r} was not present in the enumerated demo device list."
            )

        return 0

    def enum_device_name(self, index: int) -> str:
        buffer = (c_char * 64)()
        self.ensure_success(
            self.dwf.FDwfEnumDeviceName(c_int(index), buffer),
            operation="FDwfEnumDeviceName",
        )
        return bytes(buffer).split(b"\x00", 1)[0].decode("utf-8", errors="replace")

    def close(self) -> None:
        if self._handle is None:
            return
        try:
            self.dwf.FDwfDeviceClose(self._handle)
        finally:
            self._handle = None

    def last_error_message(self) -> str:
        try:
            buffer = (c_char * 512)()
            self.dwf.FDwfGetLastErrorMsg(buffer)
            return bytes(buffer).split(b"\x00", 1)[0].decode("utf-8", errors="replace")
        except Exception:
            return "Unknown WaveForms error."

    def ensure_success(self, result: int, *, operation: str) -> None:
        if result == 0:
            raise WaveFormsDeviceError(f"{operation} failed: {self.last_error_message()}")

    def get_digital_internal_clock_hz(self) -> float:
        hz = c_double()
        self.ensure_success(
            self.dwf.FDwfDigitalOutInternalClockInfo(self.handle, byref(hz)),
            operation="FDwfDigitalOutInternalClockInfo",
        )
        return float(hz.value)

    def get_digital_out_custom_size(self, *, channel: int) -> int:
        bit_count = c_int()
        self.ensure_success(
            self.dwf.FDwfDigitalOutDataInfo(self.handle, c_int(channel), byref(bit_count)),
            operation="FDwfDigitalOutDataInfo",
        )
        return int(bit_count.value)

    def configure_digital_out_custom_pattern(
        self,
        *,
        channel: int,
        bits: Sequence[int],
        sample_rate_hz: int,
    ) -> None:
        packed = pack_bits_lsb_first(bits)
        divider = max(1, round(self.get_digital_internal_clock_hz() / sample_rate_hz))
        data_buffer = (c_ubyte * len(packed)).from_buffer_copy(packed)
        self.ensure_success(self.dwf.FDwfDigitalOutEnableSet(self.handle, c_int(channel), c_int(1)), operation="FDwfDigitalOutEnableSet")
        self.ensure_success(
            self.dwf.FDwfDigitalOutTypeSet(self.handle, c_int(channel), c_int(DwfDigitalOutTypeCustom)),
            operation="FDwfDigitalOutTypeSet",
        )
        self.ensure_success(
            self.dwf.FDwfDigitalOutDividerSet(self.handle, c_int(channel), c_int(divider)),
            operation="FDwfDigitalOutDividerSet",
        )
        self.ensure_success(
            self.dwf.FDwfDigitalOutDataSet(self.handle, c_int(channel), data_buffer, c_int(len(bits))),
            operation="FDwfDigitalOutDataSet",
        )

    def play_digital_samples(
        self,
        *,
        samples: Sequence[int],
        sample_rate_hz: int,
        used_pins: Iterable[int],
    ) -> None:
        self.ensure_success(self.dwf.FDwfDigitalOutReset(self.handle), operation="FDwfDigitalOutReset")
        for pin in used_pins:
            channel_bits = extract_channel_bits(samples, pin=pin)
            max_bits = self.get_digital_out_custom_size(channel=pin)
            if max_bits > 0 and len(channel_bits) > max_bits:
                raise WaveFormsDeviceError(
                    f"DigitalOut channel {pin} supports up to {max_bits} custom bits, but {len(channel_bits)} were requested."
                )
            self.configure_digital_out_custom_pattern(
                channel=pin,
                bits=channel_bits,
                sample_rate_hz=sample_rate_hz,
            )
        self.ensure_success(self.dwf.FDwfDigitalOutConfigure(self.handle, c_int(1)), operation="FDwfDigitalOutConfigure")
        duration_s = len(samples) / float(sample_rate_hz)
        time.sleep(duration_s + 0.05)
