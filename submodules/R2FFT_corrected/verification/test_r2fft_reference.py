import unittest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from r2fft_reference import block_width, deterministic_vectors, fft_fixed_stage_reference, fft_float


class ReferenceTests(unittest.TestCase):
    def test_vectors_are_deterministic_and_complete(self):
        vectors = deterministic_vectors(length=1024)
        self.assertEqual([item.name for item in vectors], [
            "impulse", "tone_bin_64", "nyquist", "full_scale_complex", "deterministic_noisy"
        ])
        self.assertTrue(all(len(item.samples) == 1024 for item in vectors))


    def test_fixed_reference_is_bounded_and_has_expected_normalization(self):
        impulse = deterministic_vectors()[0]
        result = fft_fixed_stage_reference(impulse.samples)
        self.assertTrue(all(abs(int(value.real)) < (1 << 17) for value in result))
        self.assertTrue(all(abs(int(value.imag)) < (1 << 17) for value in result))
        self.assertEqual(result[0], result[1])
        self.assertLessEqual(block_width(result), 18)


    def test_float_reference_is_normalized(self):
        samples = [1 + 0j] + [0j] * 7
        result = fft_float(samples)
        self.assertTrue(all(abs(value - (1 / 8)) < 1e-12 for value in result))


if __name__ == "__main__":
    unittest.main()
