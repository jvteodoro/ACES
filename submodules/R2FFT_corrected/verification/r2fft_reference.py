"""Numerical reference model for the corrected R2FFT integration.

The model intentionally exposes the conventions that the RTL must preserve:

* input and output samples are signed FFT_DW-bit fixed-point values;
* twiddles use unsigned Q1.15 magnitudes, matching twrom.mif;
* each radix-2 stage averages the sum and difference, so the transform is
  normalized by FFT_LENGTH;
* the block-floating exponent is reported separately by the RTL.

This is a diagnostic model, not an implementation of the RTL scheduler. It
is used to generate deterministic vectors and compare the valid FFT bins after
the RTL protocol and RAM timing have been checked independently.
"""

from __future__ import annotations

from dataclasses import dataclass
import cmath
import math
from typing import Iterable


def signed(value: int, width: int) -> int:
    value &= (1 << width) - 1
    return value - (1 << width) if value & (1 << (width - 1)) else value


def saturate(value: int, width: int) -> int:
    return max(-(1 << (width - 1)), min((1 << (width - 1)) - 1, value))


def q15(value: float) -> int:
    return saturate(int(round(value * (1 << 15))), 16)


def bit_reverse(index: int, bits: int) -> int:
    return int(f"{index:0{bits}b}"[::-1], 2)


def fft_float(samples: Iterable[complex]) -> list[complex]:
    """Return a forward FFT using the same normalized convention as R2FFT."""
    data = list(samples)
    n = len(data)
    if n == 0 or n & (n - 1):
        raise ValueError("FFT length must be a non-zero power of two")
    bits = n.bit_length() - 1
    work = [data[bit_reverse(i, bits)] for i in range(n)]
    span = 2
    while span <= n:
        half = span // 2
        for base in range(0, n, span):
            for offset in range(half):
                tw = cmath.exp(-2j * math.pi * offset / span)
                even = work[base + offset]
                odd = work[base + offset + half] * tw
                work[base + offset] = (even + odd) / 2
                work[base + offset + half] = (even - odd) / 2
        span *= 2
    return work


def fft_fixed_stage_reference(samples: Iterable[complex], width: int = 18) -> list[complex]:
    """Reference fixed-point transform with stage averaging and Q15 twiddles.

    This mirrors the data-path arithmetic at a high level. The final integer
    results are returned as complex values whose real/imaginary components are
    signed integers, not normalized floats.
    """
    raw = list(samples)
    n = len(raw)
    if n == 0 or n & (n - 1):
        raise ValueError("FFT length must be a non-zero power of two")
    bits = n.bit_length() - 1
    data = [(int(round(x.real)), int(round(x.imag))) for x in raw]
    work = [data[bit_reverse(i, bits)] for i in range(n)]
    span = 2
    while span <= n:
        half = span // 2
        for base in range(0, n, span):
            for offset in range(half):
                angle = -2.0 * math.pi * offset / span
                wr = q15(math.cos(angle))
                wi = q15(math.sin(angle))
                er, ei = work[base + offset]
                or_, oi = work[base + offset + half]
                tr = (or_ * wr - oi * wi) >> 15
                ti = (or_ * wi + oi * wr) >> 15
                work[base + offset] = (
                    saturate((er + tr) // 2, width),
                    saturate((ei + ti) // 2, width),
                )
                work[base + offset + half] = (
                    saturate((er - tr) // 2, width),
                    saturate((ei - ti) // 2, width),
                )
        span *= 2
    return [complex(real, imag) for real, imag in work]


def block_width(samples: Iterable[complex], width: int = 18) -> int:
    """Return the highest occupied magnitude bit, matching the BFP detector."""
    maximum = 0
    for sample in samples:
        for component in (int(sample.real), int(sample.imag)):
            magnitude = abs(signed(component, width))
            maximum = max(maximum, magnitude.bit_length())
    return maximum


@dataclass(frozen=True)
class TestVector:
    name: str
    samples: tuple[complex, ...]


def deterministic_vectors(length: int = 1024, width: int = 18) -> list[TestVector]:
    """Create reproducible corner cases used by both CI and Questa stimuli."""
    peak = (1 << (width - 2)) - 1
    impulse = [0j] * length
    impulse[0] = complex(peak, 0)

    tone_bin = length // 16
    tone = [complex(round(peak * math.cos(2 * math.pi * tone_bin * i / length)), 0) for i in range(length)]
    nyquist = [complex(peak if i % 2 == 0 else -peak, 0) for i in range(length)]
    full_scale = [complex(peak if i % 4 < 2 else -peak, peak if i % 8 < 4 else -peak) for i in range(length)]

    # A deterministic multi-tone/noise-like vector exercises all bins without
    # depending on a platform-specific random generator implementation.
    noisy = []
    for i in range(length):
        value = 0.55 * math.sin(2 * math.pi * 7 * i / length)
        value += 0.21 * math.sin(2 * math.pi * 73 * i / length)
        value += 0.08 * math.sin(2 * math.pi * 211 * i / length)
        value += 0.03 * (((i * 1103515245 + 12345) >> 16) & 0x7F) / 127.0
        noisy.append(complex(round(peak * value), 0))

    return [
        TestVector("impulse", tuple(impulse)),
        TestVector("tone_bin_64", tuple(tone)),
        TestVector("nyquist", tuple(nyquist)),
        TestVector("full_scale_complex", tuple(full_scale)),
        TestVector("deterministic_noisy", tuple(noisy)),
    ]


if __name__ == "__main__":
    for vector in deterministic_vectors():
        result = fft_fixed_stage_reference(vector.samples)
        print(f"{vector.name}: bfp_width={block_width(result)} bin0={result[0]} bin1={result[1]}")
