# Numeric specification for the quality audio analyzer

The file `utils/feature_reference.py` is the reference oracle for the FPGA
implementation. It uses only NumPy and produces deterministic vectors for
clean and adverse input signals.

Initial quality profile:

| Stage | Specification |
|---|---|
| Sample rate | 48,000 Hz (must be measured on hardware) |
| Frame | 512 samples |
| Hop | 256 samples (50% overlap) |
| Window | Hann |
| Pre-emphasis | Disabled initially, configurable |
| FFT bins | 257 positive-frequency bins, including Nyquist |
| Spectrum | Power, `real² + imag²` |
| Block exponent | `real/imag × 2^bfpexp` before power |
| Mel bands | 32, Slaney scale, Slaney area normalization |
| Log | Natural log of `max(mel, 1e-12)` |
| DCT | Type-II, orthonormal, 13 outputs |
| Output reference | IEEE float; FPGA comparison uses stage-specific tolerances |

The old Raspberry Pi behavior (512 transmitted bins, 256 retained bins,
unnormalized magnitude and transport synchronization) should remain as a
separate compatibility fixture. It must not define the quality profile.

Generate vectors with:

```bash
python3 utils/feature_reference.py /tmp/feature_reference.npz
python3 -m unittest tb/python/test_feature_reference.py
```

The first FPGA implementation milestone is to match the power, Mel, log and
DCT stages against these vectors before adding noise suppression. This avoids
mistaking an improved noise metric for a numerical scaling error.
