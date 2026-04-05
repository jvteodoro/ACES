from __future__ import annotations

import unittest

from core.models import FFTBin, RawSPITransaction
from core.parser import CountMismatchError, HeaderValidationError, PayloadValidationError, SPIFrameParser
from core.protocol import (
    build_frame_words,
    encode_data_word,
    pack_header_word1,
)


class SPIFrameParserUnitTest(unittest.TestCase):
    def setUp(self) -> None:
        self.parser = SPIFrameParser(include_raw_words=True)

    def test_parses_valid_frame_and_sign_extends_18_bit_values(self) -> None:
        bins = (
            FFTBin(bin_id=0, real=17, imag=-5, flags_real=1, flags_imag=2),
            FFTBin(bin_id=1, real=131071, imag=-131072, flags_real=3, flags_imag=4),
        )
        words = build_frame_words(seq=7, bins=bins, flags=0x12, exp=0x34)
        transaction = RawSPITransaction(words=words, timestamp_host_ns=123456, source="test")

        frame = self.parser.parse_transaction(transaction)

        self.assertEqual(frame.seq, 7)
        self.assertEqual(frame.count_words, 4)
        self.assertEqual(frame.flags, 0x12)
        self.assertEqual(frame.exp, 0x34)
        self.assertEqual(frame.timestamp_host_ns, 123456)
        self.assertEqual(frame.source, "test")
        self.assertEqual(frame.bins[0].real, 17)
        self.assertEqual(frame.bins[0].imag, -5)
        self.assertEqual(frame.bins[1].real, 131071)
        self.assertEqual(frame.bins[1].imag, -131072)
        self.assertEqual(frame.bins[0].flags_real, 1)
        self.assertEqual(frame.bins[0].flags_imag, 2)
        self.assertEqual(frame.raw_words, words)

    def test_rejects_invalid_sof(self) -> None:
        words = list(build_frame_words(seq=1, bins=(FFTBin(bin_id=0, real=1, imag=2),)))
        words[0] = 0x00010001
        transaction = RawSPITransaction(words=tuple(words), timestamp_host_ns=1, source="test")

        with self.assertRaises(HeaderValidationError):
            self.parser.parse_transaction(transaction)

        self.assertEqual(self.parser.telemetry.header_errors, 1)

    def test_rejects_count_mismatch(self) -> None:
        words = list(build_frame_words(seq=1, bins=(FFTBin(bin_id=0, real=1, imag=2),)))
        words[1] = pack_header_word1(seq=1, count=4)
        transaction = RawSPITransaction(words=tuple(words), timestamp_host_ns=1, source="test")

        with self.assertRaises(CountMismatchError):
            self.parser.parse_transaction(transaction)

        self.assertEqual(self.parser.telemetry.count_errors, 1)

    def test_rejects_unexpected_bin_id_and_part_order(self) -> None:
        words = list(build_frame_words(seq=1, bins=(FFTBin(bin_id=0, real=1, imag=2),)))
        words[3] = encode_data_word(bin_id=0, part=1, flags_local=0, value=1)
        words[4] = encode_data_word(bin_id=3, part=0, flags_local=0, value=2)
        transaction = RawSPITransaction(words=tuple(words), timestamp_host_ns=1, source="test")

        with self.assertRaises(PayloadValidationError):
            self.parser.parse_transaction(transaction)

        self.assertEqual(self.parser.telemetry.payload_errors, 1)

    def test_tracks_sequence_gaps_on_successful_frames(self) -> None:
        frame_a = RawSPITransaction(
            words=build_frame_words(seq=2, bins=(FFTBin(bin_id=0, real=1, imag=2),)),
            timestamp_host_ns=100,
            source="test",
        )
        frame_b = RawSPITransaction(
            words=build_frame_words(seq=4, bins=(FFTBin(bin_id=0, real=3, imag=4),)),
            timestamp_host_ns=200,
            source="test",
        )

        self.parser.parse_transaction(frame_a)
        self.parser.parse_transaction(frame_b)

        self.assertEqual(self.parser.telemetry.frames_parsed_ok, 2)
        self.assertEqual(self.parser.telemetry.sequence_gaps, 1)


if __name__ == "__main__":
    unittest.main()
