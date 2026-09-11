import unittest

import numpy as np

from utils.feature_reference import (
    FeatureConfig,
    analyze_audio,
    analyze_spectrum,
    dct_matrix,
    mel_filterbank,
    window_values,
)


class FeatureReferenceTest(unittest.TestCase):
    def test_quality_profile_shapes(self):
        cfg = FeatureConfig()
        result = analyze_audio(np.zeros(cfg.fft_length * 3), cfg)
        self.assertEqual(result["spectrum"].shape, (5, 513))
        self.assertEqual(result["mel"].shape, (5, 32))
        self.assertEqual(result["mfcc"].shape, (5, 13))

    def test_hann_window_has_zero_edges_and_unity_center(self):
        values = window_values(FeatureConfig())
        self.assertAlmostEqual(values[0], 0.0)
        self.assertAlmostEqual(values[-1], 0.0)
        self.assertGreater(values[len(values) // 2], 0.9999)

    def test_orthonormal_dct_constant_has_only_mfcc0(self):
        matrix = dct_matrix(32, 13)
        output = matrix @ np.ones(32)
        self.assertAlmostEqual(output[0], np.sqrt(32.0), places=12)
        self.assertTrue(np.all(np.abs(output[1:]) < 1.0e-12))

    def test_bfpexp_applies_power_scale(self):
        cfg = FeatureConfig(mel_bands=8, mfcc_count=4)
        real = np.ones(cfg.fft_length // 2 + 1)
        imag = np.zeros_like(real)
        base = analyze_spectrum(real, imag, cfg, bfpexp=0)
        shifted = analyze_spectrum(real, imag, cfg, bfpexp=3)
        np.testing.assert_allclose(shifted["spectrum"], base["spectrum"] * 64.0)

    def test_silence_and_clipping_are_finite(self):
        cfg = FeatureConfig()
        for samples in (np.zeros(2048), np.full(2048, 1.0)):
            result = analyze_audio(samples, cfg)
            for values in result.values():
                self.assertTrue(np.isfinite(values).all())

    def test_mel_filters_are_nonnegative_and_bounded(self):
        filters = mel_filterbank(FeatureConfig())
        self.assertEqual(filters.shape, (32, 513))
        self.assertGreater(np.count_nonzero(filters), 0)
        self.assertGreaterEqual(filters.min(), 0.0)
        self.assertLessEqual(filters.max(), 1.0)


if __name__ == "__main__":
    unittest.main()
