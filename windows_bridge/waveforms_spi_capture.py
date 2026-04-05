from __future__ import annotations

import time
from ctypes import byref, c_int, c_ubyte
from dataclasses import dataclass
from typing import Iterator, Optional, Sequence

from core.models import RawSPITransaction
from core.protocol import bytes_to_words

from .waveforms_sdk import WaveFormsDevice, WaveFormsDeviceError


@dataclass(frozen=True)
class CaptureConfig:
    cs_pin: int = 0
    clk_pin: int = 1
    data_pin: int = 2
    sample_rate_hz: int = 40_000_000
    buffer_size: int = 131_072
    bits_per_word: int = 32
    cpol: int = 0
    cpha: int = 0
    byteorder: str = "big"
    device_index: int = -1
    chunk_timeout_s: float = 0.5
    source: str = "real"
    library_path: str | None = None
    demo_mode: bool = False
    demo_device_name: str | None = None

    @classmethod
    def from_mapping(cls, values: dict[str, object] | None) -> "CaptureConfig":
        payload = dict(values or {})
        return cls(
            cs_pin=int(payload.get("cs_pin", cls.cs_pin)),
            clk_pin=int(payload.get("clk_pin", cls.clk_pin)),
            data_pin=int(payload.get("data_pin", cls.data_pin)),
            sample_rate_hz=int(payload.get("sample_rate_hz", cls.sample_rate_hz)),
            buffer_size=int(payload.get("buffer_size", cls.buffer_size)),
            bits_per_word=int(payload.get("bits_per_word", cls.bits_per_word)),
            cpol=int(payload.get("cpol", cls.cpol)),
            cpha=int(payload.get("cpha", cls.cpha)),
            byteorder=str(payload.get("byteorder", cls.byteorder)),
            device_index=int(payload.get("device_index", cls.device_index)),
            chunk_timeout_s=float(payload.get("chunk_timeout_s", cls.chunk_timeout_s)),
            source=str(payload.get("source", cls.source)),
            library_path=payload.get("library_path") if payload.get("library_path") else None,
            demo_mode=bool(payload.get("demo_mode", cls.demo_mode)),
            demo_device_name=str(payload["demo_device_name"]) if payload.get("demo_device_name") else None,
        )


@dataclass
class RawCaptureStats:
    chunks_captured: int = 0
    samples_captured: int = 0
    transactions_emitted: int = 0
    partial_words_seen: int = 0

    def snapshot(self) -> dict[str, int]:
        return {
            "chunks_captured": self.chunks_captured,
            "samples_captured": self.samples_captured,
            "transactions_emitted": self.transactions_emitted,
            "partial_words_seen": self.partial_words_seen,
        }


class SPILogicDecoder:
    def __init__(self, config: CaptureConfig) -> None:
        self.config = config
        self._prev_cs_active: bool | None = None
        self._prev_clk_level: int | None = None
        self._current_bits: list[int] = []
        self._frame_start_timestamp_ns: int | None = None

    def feed_samples(
        self,
        samples: Sequence[int],
        *,
        timestamp_host_ns: int | None = None,
        source: str | None = None,
    ) -> list[RawSPITransaction]:
        transactions: list[RawSPITransaction] = []
        timestamp = int(timestamp_host_ns or time.time_ns())
        source_name = source or self.config.source

        for sample in samples:
            cs_active = ((sample >> self.config.cs_pin) & 0x1) == 0
            clk_level = (sample >> self.config.clk_pin) & 0x1
            data_level = (sample >> self.config.data_pin) & 0x1

            if self._prev_cs_active is None:
                self._prev_cs_active = cs_active
                self._prev_clk_level = clk_level
                if cs_active:
                    self._frame_start_timestamp_ns = timestamp
                continue

            if not self._prev_cs_active and cs_active:
                self._current_bits = []
                self._frame_start_timestamp_ns = timestamp

            if cs_active and self._prev_clk_level is not None and self._is_sample_edge(self._prev_clk_level, clk_level):
                self._current_bits.append(data_level)

            if self._prev_cs_active and not cs_active:
                transaction = self._finalize_transaction(
                    timestamp_host_ns=timestamp,
                    source=source_name,
                )
                if transaction is not None:
                    transactions.append(transaction)

            self._prev_cs_active = cs_active
            self._prev_clk_level = clk_level

        return transactions

    def _is_sample_edge(self, prev_clk_level: int, clk_level: int) -> bool:
        leading_edge = prev_clk_level == self.config.cpol and clk_level != self.config.cpol
        trailing_edge = prev_clk_level != self.config.cpol and clk_level == self.config.cpol
        return leading_edge if self.config.cpha == 0 else trailing_edge

    def _finalize_transaction(self, *, timestamp_host_ns: int, source: str) -> RawSPITransaction | None:
        if not self._current_bits:
            self._current_bits = []
            return None

        full_bytes = len(self._current_bits) // 8
        raw_bytes = bytearray()
        for index in range(full_bytes):
            byte = 0
            offset = index * 8
            for bit in self._current_bits[offset : offset + 8]:
                byte = (byte << 1) | bit
            raw_bytes.append(byte)

        truncated_bits = len(self._current_bits) - (full_bytes * 8)
        full_word_bytes = (len(raw_bytes) // 4) * 4
        word_bytes = bytes(raw_bytes[:full_word_bytes])
        partial_word_bits = truncated_bits + ((len(raw_bytes) - full_word_bytes) * 8)
        words = bytes_to_words(word_bytes, byteorder=self.config.byteorder) if word_bytes else tuple()

        transaction = RawSPITransaction(
            words=words,
            timestamp_host_ns=int(self._frame_start_timestamp_ns or timestamp_host_ns),
            source=source,
            metadata={
                "bit_count": len(self._current_bits),
                "partial_word_bits": partial_word_bits,
            },
        )
        self._current_bits = []
        self._frame_start_timestamp_ns = None
        return transaction


class WaveFormsSPICapture:
    def __init__(self, config: CaptureConfig) -> None:
        self.config = config
        self.decoder = SPILogicDecoder(config)
        self.stats = RawCaptureStats()

    def decode_samples(
        self,
        samples: Sequence[int],
        *,
        timestamp_host_ns: int | None = None,
        source: str | None = None,
    ) -> list[RawSPITransaction]:
        self.stats.chunks_captured += 1
        self.stats.samples_captured += len(samples)
        transactions = self.decoder.feed_samples(samples, timestamp_host_ns=timestamp_host_ns, source=source)
        self.stats.transactions_emitted += len(transactions)
        self.stats.partial_words_seen += sum(
            1 for item in transactions if int(item.metadata.get("partial_word_bits", 0)) > 0
        )
        return transactions

    def capture_transactions(self, *, max_transactions: int | None = None) -> Iterator[RawSPITransaction]:
        with WaveFormsDevice(
            device_index=self.config.device_index,
            library_path=self.config.library_path,
            demo_mode=self.config.demo_mode,
            demo_device_name=self.config.demo_device_name,
        ) as device:
            self.arm_device(device)
            for transaction in self.read_transactions_from_device(
                device,
                max_transactions=max_transactions,
                source=self.config.source,
            ):
                yield transaction

    def arm_device(self, device: WaveFormsDevice) -> None:
        self._configure_digital_in(device)
        dwf = device.dwf
        handle = device.handle
        device.ensure_success(
            dwf.FDwfDigitalInConfigure(handle, c_int(0), c_int(1)),
            operation="FDwfDigitalInConfigure",
        )

    def read_transactions_from_device(
        self,
        device: WaveFormsDevice,
        *,
        max_transactions: int | None = None,
        source: str | None = None,
        timeout_s: float | None = None,
    ) -> list[RawSPITransaction]:
        emitted = 0
        transactions: list[RawSPITransaction] = []
        deadline = time.monotonic() + timeout_s if timeout_s is not None else None

        while max_transactions is None or emitted < max_transactions:
            if deadline is not None and time.monotonic() >= deadline:
                break

            samples = self._read_available_samples(device)
            if not samples:
                time.sleep(0.005)
                continue

            chunk_transactions = self.decode_samples(samples, source=source)
            transactions.extend(chunk_transactions)
            emitted += len(chunk_transactions)
        return transactions

    def _configure_digital_in(self, device: WaveFormsDevice) -> None:
        dwf = device.dwf
        handle = device.handle
        device.ensure_success(dwf.FDwfDigitalInReset(handle), operation="FDwfDigitalInReset")
        hz_sys = c_int()
        try:
            device.ensure_success(dwf.FDwfDigitalInInternalClockInfo(handle, byref(hz_sys)), operation="FDwfDigitalInInternalClockInfo")
            divider = max(1, round(float(hz_sys.value) / float(self.config.sample_rate_hz)))
        except Exception:
            divider = 1
        device.ensure_success(dwf.FDwfDigitalInDividerSet(handle, c_int(divider)), operation="FDwfDigitalInDividerSet")
        device.ensure_success(
            dwf.FDwfDigitalInSampleFormatSet(handle, c_int(8)),
            operation="FDwfDigitalInSampleFormatSet",
        )
        device.ensure_success(
            dwf.FDwfDigitalInBufferSizeSet(handle, c_int(self.config.buffer_size)),
            operation="FDwfDigitalInBufferSizeSet",
        )

    def _read_available_samples(self, device: WaveFormsDevice) -> list[int]:
        dwf = device.dwf
        handle = device.handle
        deadline = time.monotonic() + self.config.chunk_timeout_s
        valid_samples = c_int()
        status = c_int()
        while time.monotonic() < deadline:
            device.ensure_success(dwf.FDwfDigitalInStatus(handle, c_int(1), byref(status)), operation="FDwfDigitalInStatus")
            device.ensure_success(
                dwf.FDwfDigitalInStatusSamplesValid(handle, byref(valid_samples)),
                operation="FDwfDigitalInStatusSamplesValid",
            )
            if valid_samples.value > 0:
                break
            time.sleep(0.005)

        if valid_samples.value <= 0:
            return []

        sample_count = min(valid_samples.value, self.config.buffer_size)
        data = (c_ubyte * sample_count)()
        try:
            device.ensure_success(
                dwf.FDwfDigitalInStatusData(handle, data, c_int(sample_count)),
                operation="FDwfDigitalInStatusData",
            )
        except WaveFormsDeviceError:
            return []
        return list(data)
