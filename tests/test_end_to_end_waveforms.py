from __future__ import annotations

import os
import unittest
from queue import Queue

from core.bridge_client import WindowsBridgeClient
from core.models import FFTBin
from core.parser import SPIFrameParser
from core.pipeline import FramePipeline
from core.protocol import build_frame_words
from core.publisher import QueuePublisher
from windows_bridge.bridge_server import BridgeServer, WaveFormsBridgeBackend
from windows_bridge.waveforms_sdk import WaveFormsDemoUnavailable, WaveFormsError, WaveFormsLibraryNotFound
from windows_bridge.waveforms_spi_capture import CaptureConfig
from windows_bridge.waveforms_spi_pattern_test import PatternConfig, WaveFormsPatternLoopbackHarness


class SoftwareLoopbackBackend(WaveFormsBridgeBackend):
    def handle_command(self, command):
        if command.get("command") != "start_pattern_test":
            return super().handle_command(command)

        frames = [tuple(int(word) & 0xFFFFFFFF for word in frame) for frame in command.get("frames", [])]
        pattern_config = PatternConfig.from_mapping(command.get("pattern_config"))
        capture_config = CaptureConfig.from_mapping(command.get("capture_config"))
        harness = WaveFormsPatternLoopbackHarness(pattern_config, capture_config)
        return harness.run_loopback(frames, source="test", use_hardware=False)


class FramePipelineEndToEndTest(unittest.TestCase):
    def test_pipeline_consumes_pattern_generator_loopback_over_tcp_bridge(self) -> None:
        try:
            server = BridgeServer(("127.0.0.1", 0), backend=SoftwareLoopbackBackend())
        except PermissionError as exc:
            self.skipTest(f"Local TCP listener blocked by environment: {exc}")
        except OSError as exc:
            self.skipTest(f"Unable to start local bridge server in this environment: {exc}")

        thread = server.serve_in_thread()
        self.addCleanup(server.shutdown)
        self.addCleanup(server.server_close)
        self.addCleanup(thread.join, 1.0)

        bins_a = (
            FFTBin(bin_id=0, real=5, imag=-7, flags_real=1, flags_imag=2),
            FFTBin(bin_id=1, real=19, imag=-23, flags_real=3, flags_imag=4),
        )
        bins_b = (
            FFTBin(bin_id=0, real=-11, imag=13),
            FFTBin(bin_id=1, real=-29, imag=31),
        )
        frames = [
            build_frame_words(seq=10, bins=bins_a, flags=0x11, exp=0x22),
            build_frame_words(seq=11, bins=bins_b, flags=0x33, exp=0x44),
        ]

        queue: Queue = Queue()
        publisher = QueuePublisher(queue)
        client = WindowsBridgeClient(host="127.0.0.1", port=server.server_address[1])
        parser = SPIFrameParser()
        pipeline = FramePipeline(client=client, parser=parser, publisher=publisher)

        parsed = pipeline.run_pattern_test(
            frames=frames,
            pattern_config={
                "cs_pin": 0,
                "clk_pin": 1,
                "data_pin": 2,
                "sample_rate_hz": 8_000_000,
                "spi_clock_hz": 1_000_000,
            },
            capture_config={
                "cs_pin": 0,
                "clk_pin": 1,
                "data_pin": 2,
                "sample_rate_hz": 8_000_000,
            },
            max_frames=2,
            use_hardware=False,
        )

        self.assertEqual(len(parsed), 2)
        self.assertEqual(parsed[0].seq, 10)
        self.assertEqual(parsed[1].seq, 11)
        self.assertEqual(parsed[0].bins[0].imag, -7)
        self.assertEqual(parsed[1].bins[1].real, -29)
        self.assertEqual(queue.qsize(), 2)
        self.assertEqual(parser.telemetry.frames_parsed_ok, 2)
        pipeline.close()

    @unittest.skipUnless(
        os.environ.get("RUN_WAVEFORMS_E2E") == "1",
        "Set RUN_WAVEFORMS_E2E=1 on Windows with Analog Discovery connected to run the real WaveForms test.",
    )
    def test_real_waveforms_pattern_generator_loopback(self) -> None:
        frame_words = build_frame_words(
            seq=1,
            bins=(
                FFTBin(bin_id=0, real=7, imag=-9),
                FFTBin(bin_id=1, real=123, imag=-321),
            ),
            flags=0x55,
            exp=0x66,
        )
        harness = WaveFormsPatternLoopbackHarness(
            PatternConfig(
                cs_pin=0,
                clk_pin=1,
                data_pin=2,
                sample_rate_hz=20_000_000,
                spi_clock_hz=1_000_000,
            ),
            CaptureConfig(
                cs_pin=0,
                clk_pin=1,
                data_pin=2,
                sample_rate_hz=20_000_000,
                source="test",
            ),
        )
        try:
            transactions = harness.run_loopback([frame_words], source="test", use_hardware=True)
        except WaveFormsLibraryNotFound as exc:
            self.skipTest(str(exc))
        except WaveFormsDemoUnavailable as exc:
            self.skipTest(f"WaveForms demo device unavailable: {exc}")
        except WaveFormsError as exc:
            self.skipTest(f"WaveForms SDK/hardware unavailable: {exc}")

        parser = SPIFrameParser()
        frame = parser.parse_transaction(transactions[0])
        self.assertEqual(frame.seq, 1)
        self.assertEqual(frame.bins[1].imag, -321)

    @unittest.skipUnless(
        os.environ.get("RUN_WAVEFORMS_DEMO_E2E") == "1",
        "Set RUN_WAVEFORMS_DEMO_E2E=1 on Windows when the WaveForms SDK demo device is available.",
    )
    def test_demo_waveforms_pattern_generator_loopback(self) -> None:
        frame_words = build_frame_words(
            seq=2,
            bins=(
                FFTBin(bin_id=0, real=1, imag=-2),
                FFTBin(bin_id=1, real=3, imag=-4),
            ),
            flags=0xAA,
            exp=0xBB,
        )
        harness = WaveFormsPatternLoopbackHarness(
            PatternConfig(
                cs_pin=0,
                clk_pin=1,
                data_pin=2,
                sample_rate_hz=4_000_000,
                spi_clock_hz=1_000_000,
                demo_mode=True,
                demo_device_name="Analog Discovery 2",
            ),
            CaptureConfig(
                cs_pin=0,
                clk_pin=1,
                data_pin=2,
                sample_rate_hz=4_000_000,
                source="demo",
                demo_mode=True,
                demo_device_name="Analog Discovery 2",
            ),
        )
        try:
            transactions = harness.run_loopback([frame_words], source="demo", use_hardware=True)
        except WaveFormsLibraryNotFound as exc:
            self.skipTest(str(exc))
        except WaveFormsDemoUnavailable as exc:
            self.skipTest(f"WaveForms demo device unavailable: {exc}")
        except WaveFormsError as exc:
            self.skipTest(f"WaveForms SDK demo path unavailable: {exc}")

        parser = SPIFrameParser()
        frame = parser.parse_transaction(transactions[0])
        self.assertEqual(frame.seq, 2)
        self.assertEqual(frame.bins[1].imag, -4)


if __name__ == "__main__":
    unittest.main()
