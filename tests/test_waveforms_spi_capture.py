from __future__ import annotations

import time
import unittest

from core.models import FFTBin
from core.parser import SPIFrameParser
from core.protocol import build_frame_words
from windows_bridge.waveforms_sdk import build_spi_bus_samples
from windows_bridge.waveforms_spi_capture import CaptureConfig, WaveFormsSPICapture


class WaveFormsSPICaptureDecodeTest(unittest.TestCase):
    def setUp(self) -> None:
        self.config = CaptureConfig(
            cs_pin=0,
            clk_pin=1,
            data_pin=2,
            sample_rate_hz=8_000_000,
            bits_per_word=32,
            cpol=0,
            cpha=0,
            byteorder="big",
            source="sim",
        )
        self.capture = WaveFormsSPICapture(self.config)
        self.parser = SPIFrameParser()

    def test_decoder_reassembles_one_transaction_into_original_words(self) -> None:
        words = build_frame_words(
            seq=9,
            bins=(
                FFTBin(bin_id=0, real=17, imag=-19, flags_real=1, flags_imag=2),
                FFTBin(bin_id=1, real=-21, imag=23, flags_real=3, flags_imag=4),
            ),
            flags=0x1234,
            exp=0x0056,
        )
        samples = build_spi_bus_samples(
            frames=[words],
            sample_rate_hz=self.config.sample_rate_hz,
            spi_clock_hz=1_000_000,
            cs_pin=self.config.cs_pin,
            clk_pin=self.config.clk_pin,
            data_pin=self.config.data_pin,
            cpol=self.config.cpol,
            cpha=self.config.cpha,
            byteorder=self.config.byteorder,
        )

        transactions = self.capture.decode_samples(samples, timestamp_host_ns=1000, source="sim")

        self.assertEqual(len(transactions), 1)
        self.assertEqual(transactions[0].words, words)
        self.assertEqual(transactions[0].metadata["partial_word_bits"], 0)

        frame = self.parser.parse_transaction(transactions[0])
        self.assertEqual(frame.seq, 9)
        self.assertEqual(frame.flags, 0x1234)
        self.assertEqual(frame.exp, 0x0056)
        self.assertEqual(frame.bins[0].imag, -19)
        self.assertEqual(frame.bins[1].real, -21)

    def test_decoder_uses_cs_boundaries_to_split_multiple_frames(self) -> None:
        frame_a = build_frame_words(
            seq=10,
            bins=(FFTBin(bin_id=0, real=1, imag=-2),),
            flags=0x0011,
            exp=0x0022,
        )
        frame_b = build_frame_words(
            seq=11,
            bins=(
                FFTBin(bin_id=0, real=-3, imag=4),
                FFTBin(bin_id=1, real=5, imag=-6),
            ),
            flags=0x0033,
            exp=0x0044,
        )
        samples = build_spi_bus_samples(
            frames=[frame_a, frame_b],
            sample_rate_hz=self.config.sample_rate_hz,
            spi_clock_hz=1_000_000,
            cs_pin=self.config.cs_pin,
            clk_pin=self.config.clk_pin,
            data_pin=self.config.data_pin,
            cpol=self.config.cpol,
            cpha=self.config.cpha,
            byteorder=self.config.byteorder,
            inter_frame_idle_bits=4,
        )

        transactions = self.capture.decode_samples(samples, timestamp_host_ns=time.time_ns(), source="sim")

        self.assertEqual(len(transactions), 2)
        self.assertEqual(transactions[0].words, frame_a)
        self.assertEqual(transactions[1].words, frame_b)

        parsed = [self.parser.parse_transaction(item) for item in transactions]
        self.assertEqual([frame.seq for frame in parsed], [10, 11])
        self.assertEqual(parsed[1].bins[1].imag, -6)


if __name__ == "__main__":
    unittest.main()
