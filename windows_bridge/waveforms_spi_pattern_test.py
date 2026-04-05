from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Sequence

from core.models import RawSPITransaction

from .waveforms_sdk import WaveFormsDevice, build_spi_bus_samples
from .waveforms_spi_capture import CaptureConfig, WaveFormsSPICapture


@dataclass(frozen=True)
class PatternConfig:
    cs_pin: int = 0
    clk_pin: int = 1
    data_pin: int = 2
    sample_rate_hz: int = 20_000_000
    spi_clock_hz: int = 1_000_000
    cpol: int = 0
    cpha: int = 0
    byteorder: str = "big"
    device_index: int = -1
    inter_frame_idle_bits: int = 2
    library_path: str | None = None
    demo_mode: bool = False
    demo_device_name: str | None = None

    @classmethod
    def from_mapping(cls, values: dict[str, object] | None) -> "PatternConfig":
        payload = dict(values or {})
        return cls(
            cs_pin=int(payload.get("cs_pin", cls.cs_pin)),
            clk_pin=int(payload.get("clk_pin", cls.clk_pin)),
            data_pin=int(payload.get("data_pin", cls.data_pin)),
            sample_rate_hz=int(payload.get("sample_rate_hz", cls.sample_rate_hz)),
            spi_clock_hz=int(payload.get("spi_clock_hz", cls.spi_clock_hz)),
            cpol=int(payload.get("cpol", cls.cpol)),
            cpha=int(payload.get("cpha", cls.cpha)),
            byteorder=str(payload.get("byteorder", cls.byteorder)),
            device_index=int(payload.get("device_index", cls.device_index)),
            inter_frame_idle_bits=int(payload.get("inter_frame_idle_bits", cls.inter_frame_idle_bits)),
            library_path=payload.get("library_path") if payload.get("library_path") else None,
            demo_mode=bool(payload.get("demo_mode", cls.demo_mode)),
            demo_device_name=str(payload["demo_device_name"]) if payload.get("demo_device_name") else None,
        )


class WaveFormsPatternGenerator:
    def __init__(self, config: PatternConfig) -> None:
        self.config = config

    def build_samples(self, frames: Sequence[Sequence[int]]) -> list[int]:
        return build_spi_bus_samples(
            frames=frames,
            sample_rate_hz=self.config.sample_rate_hz,
            spi_clock_hz=self.config.spi_clock_hz,
            cs_pin=self.config.cs_pin,
            clk_pin=self.config.clk_pin,
            data_pin=self.config.data_pin,
            cpol=self.config.cpol,
            cpha=self.config.cpha,
            byteorder=self.config.byteorder,
            inter_frame_idle_bits=self.config.inter_frame_idle_bits,
        )

    def transmit_samples(self, samples: Sequence[int], *, device: WaveFormsDevice | None = None) -> None:
        if device is None:
            with WaveFormsDevice(
                device_index=self.config.device_index,
                library_path=self.config.library_path,
                demo_mode=self.config.demo_mode,
                demo_device_name=self.config.demo_device_name,
            ) as owned_device:
                owned_device.play_digital_samples(
                    samples=samples,
                    sample_rate_hz=self.config.sample_rate_hz,
                    used_pins=(self.config.cs_pin, self.config.clk_pin, self.config.data_pin),
                )
            return

        device.play_digital_samples(
            samples=samples,
            sample_rate_hz=self.config.sample_rate_hz,
            used_pins=(self.config.cs_pin, self.config.clk_pin, self.config.data_pin),
        )

    def transmit_frames(self, frames: Sequence[Sequence[int]]) -> list[int]:
        samples = self.build_samples(frames)
        self.transmit_samples(samples)
        return samples


class WaveFormsPatternLoopbackHarness:
    def __init__(self, pattern_config: PatternConfig, capture_config: CaptureConfig | None = None) -> None:
        self.pattern_config = pattern_config
        self.capture_config = capture_config or CaptureConfig(
            cs_pin=pattern_config.cs_pin,
            clk_pin=pattern_config.clk_pin,
            data_pin=pattern_config.data_pin,
            sample_rate_hz=pattern_config.sample_rate_hz,
            cpol=pattern_config.cpol,
            cpha=pattern_config.cpha,
            byteorder=pattern_config.byteorder,
            device_index=pattern_config.device_index,
            library_path=pattern_config.library_path,
            demo_mode=pattern_config.demo_mode,
            demo_device_name=pattern_config.demo_device_name,
            source="test",
        )
        self.generator = WaveFormsPatternGenerator(pattern_config)
        self.capture = WaveFormsSPICapture(self.capture_config)

    def run_loopback(
        self,
        frames: Sequence[Sequence[int]],
        *,
        source: str = "test",
        use_hardware: bool = True,
    ) -> list[RawSPITransaction]:
        if use_hardware:
            samples = self.generator.build_samples(frames)
            if self.pattern_config.demo_mode:
                # Demo devices expose the API surface, but they do not provide a usable
                # DigitalOut -> DigitalIn loopback path for our SPI frame validation.
                # We still validate the WaveForms DigitalOut programming path, then feed
                # the generated bus samples through the same production decoder.
                with WaveFormsDevice(
                    device_index=self.pattern_config.device_index,
                    library_path=self.pattern_config.library_path,
                    demo_mode=self.pattern_config.demo_mode,
                    demo_device_name=self.pattern_config.demo_device_name,
                ) as device:
                    self.generator.transmit_samples(samples, device=device)
                return self.capture.decode_samples(samples, timestamp_host_ns=time.time_ns(), source=source)

            if len(samples) > self.capture_config.buffer_size:
                raise ValueError(
                    f"Pattern requires {len(samples)} samples but capture buffer is {self.capture_config.buffer_size}. Increase buffer_size."
                )

            with WaveFormsDevice(
                device_index=self.pattern_config.device_index,
                library_path=self.pattern_config.library_path,
                demo_mode=self.pattern_config.demo_mode,
                demo_device_name=self.pattern_config.demo_device_name,
            ) as device:
                self.capture.arm_device(device)
                self.generator.transmit_samples(samples, device=device)
                read_timeout_s = max(
                    self.capture_config.chunk_timeout_s,
                    (len(samples) / float(self.pattern_config.sample_rate_hz)) + 0.25,
                )
                return self.capture.read_transactions_from_device(
                    device,
                    max_transactions=len(frames),
                    source=source,
                    timeout_s=read_timeout_s,
                )

        samples = self.generator.build_samples(frames)
        return self.capture.decode_samples(samples, timestamp_host_ns=time.time_ns(), source=source)
