"""Reference implementation for the DE10-Lite audio feature pipeline.

This module is intentionally NumPy-only so it can run on the development
machine and on the Raspberry Pi without depending on librosa.  It is the
numeric oracle for the fixed-point RTL.  The FPGA may use a cheaper
approximation, but each approximation must be compared against this module
with an explicit tolerance.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import numpy as np


@dataclass(frozen=True)
class FeatureConfig:
    sample_rate: int = 48_000
    fft_length: int = 512
    hop_length: int = 256
    mel_bands: int = 32
    mfcc_count: int = 13
    fmin: float = 0.0
    fmax: float | None = None
    window: str = "hann"
    preemphasis: float = 0.0
    use_power: bool = True
    log_floor: float = 1.0e-12
    mel_norm: str = "slaney"
    lifter: float = 0.0

    def resolved_fmax(self) -> float:
        return self.sample_rate / 2 if self.fmax is None else self.fmax


def _hz_to_mel_slaney(hz: np.ndarray) -> np.ndarray:
    """Slaney mel scale used by librosa when htk=False."""
    hz = np.asarray(hz, dtype=np.float64)
    min_log_hz = 1_000.0
    min_log_mel = 15.0
    logstep = np.log(6.4) / 27.0
    result = 3.0 * hz / 200.0
    logarithmic = hz >= min_log_hz
    result[logarithmic] = min_log_mel + np.log(hz[logarithmic] / min_log_hz) / logstep
    return result


def _mel_to_hz_slaney(mel: np.ndarray) -> np.ndarray:
    mel = np.asarray(mel, dtype=np.float64)
    min_log_hz = 1_000.0
    min_log_mel = 15.0
    logstep = np.log(6.4) / 27.0
    result = 200.0 * mel / 3.0
    logarithmic = mel >= min_log_mel
    result[logarithmic] = min_log_hz * np.exp(logstep * (mel[logarithmic] - min_log_mel))
    return result


def mel_filterbank(config: FeatureConfig) -> np.ndarray:
    """Return [mel_band, positive_fft_bin] normalized triangular filters."""
    fmax = config.resolved_fmax()
    mel_edges = np.linspace(
        _hz_to_mel_slaney(np.array([config.fmin]))[0],
        _hz_to_mel_slaney(np.array([fmax]))[0],
        config.mel_bands + 2,
    )
    edge_hz = _mel_to_hz_slaney(mel_edges)
    fft_hz = np.linspace(0.0, config.sample_rate / 2, config.fft_length // 2 + 1)
    filters = np.zeros((config.mel_bands, fft_hz.size), dtype=np.float64)

    for band in range(config.mel_bands):
        left, center, right = edge_hz[band : band + 3]
        if center > left:
            rising = (fft_hz > left) & (fft_hz < center)
            filters[band, rising] = (fft_hz[rising] - left) / (center - left)
        if right > center:
            falling = (fft_hz >= center) & (fft_hz < right)
            filters[band, falling] = (right - fft_hz[falling]) / (right - center)
        if config.mel_norm == "slaney" and right > left:
            filters[band] *= 2.0 / (right - left)
        elif config.mel_norm not in {"none", "slaney"}:
            raise ValueError(f"unsupported Mel normalization: {config.mel_norm}")
    return filters


def dct_matrix(mel_bands: int, mfcc_count: int) -> np.ndarray:
    n = np.arange(mel_bands, dtype=np.float64)[None, :]
    k = np.arange(mfcc_count, dtype=np.float64)[:, None]
    scale = np.sqrt(2.0 / mel_bands) * np.ones((mfcc_count, 1))
    scale[0, 0] = np.sqrt(1.0 / mel_bands)
    return scale * np.cos(np.pi * k * (n + 0.5) / mel_bands)


def window_values(config: FeatureConfig) -> np.ndarray:
    n = config.fft_length
    if config.window == "hann":
        return np.hanning(n)
    if config.window == "hamming":
        return np.hamming(n)
    if config.window == "rectangular":
        return np.ones(n)
    raise ValueError(f"unsupported window: {config.window}")


def frame_signal(samples: Iterable[float], config: FeatureConfig) -> np.ndarray:
    """Frame audio without implicit zero padding; shape is [frames, fft_length]."""
    signal = np.asarray(list(samples), dtype=np.float64)
    if config.preemphasis:
        signal = np.concatenate(([signal[0]], signal[1:] - config.preemphasis * signal[:-1]))
    if signal.size < config.fft_length:
        return np.empty((0, config.fft_length), dtype=np.float64)
    count = 1 + (signal.size - config.fft_length) // config.hop_length
    starts = np.arange(count) * config.hop_length
    frames = np.stack([signal[start : start + config.fft_length] for start in starts])
    return frames * window_values(config)[None, :]


def analyze_spectrum(
    real: Iterable[float],
    imag: Iterable[float],
    config: FeatureConfig,
    bfpexp: int = 0,
) -> dict[str, np.ndarray]:
    """Analyze positive FFT bins and apply the block-floating exponent."""
    re = np.asarray(real, dtype=np.float64)
    im = np.asarray(imag, dtype=np.float64)
    if re.shape != im.shape:
        raise ValueError("real and imag must have equal shape")
    expected = config.fft_length // 2 + 1
    if re.size != expected:
        raise ValueError(f"expected {expected} positive bins, got {re.size}")
    scale = np.ldexp(1.0, int(bfpexp))
    re *= scale
    im *= scale
    power = re * re + im * im
    spectrum = np.sqrt(power) if not config.use_power else power
    mel = mel_filterbank(config) @ spectrum
    log_mel = np.log(np.maximum(mel, config.log_floor))
    mfcc = dct_matrix(config.mel_bands, config.mfcc_count) @ log_mel
    if config.lifter:
        n = np.arange(config.mfcc_count)
        mfcc *= 1.0 + (config.lifter / 2.0) * np.sin(np.pi * (n + 1) / config.lifter)
    return {
        "spectrum": spectrum,
        "mel": mel,
        "log_mel": log_mel,
        "mfcc": mfcc,
    }


def analyze_audio(samples: Iterable[float], config: FeatureConfig) -> dict[str, np.ndarray]:
    frames = frame_signal(samples, config)
    if frames.size == 0:
        return {"spectrum": np.empty((0, config.fft_length // 2 + 1)),
                "mel": np.empty((0, config.mel_bands)),
                "log_mel": np.empty((0, config.mel_bands)),
                "mfcc": np.empty((0, config.mfcc_count))}
    spectra = np.fft.rfft(frames, n=config.fft_length, axis=1)
    rows = [analyze_spectrum(row.real, row.imag, config) for row in spectra]
    return {key: np.stack([row[key] for row in rows]) for key in rows[0]}


def write_reference_vectors(path: str | Path) -> None:
    """Write deterministic signals and expected quality-profile features."""
    config = FeatureConfig()
    n = config.fft_length * 4
    t = np.arange(n) / config.sample_rate
    signals = {
        "sine_1k": np.sin(2 * np.pi * 1_000 * t),
        "two_tone": 0.6 * np.sin(2 * np.pi * 440 * t) + 0.3 * np.sin(2 * np.pi * 3_200 * t),
        "impulse": np.r_[1.0, np.zeros(n - 1)],
        "silence": np.zeros(n),
        "white_noise": np.random.default_rng(1234).normal(0, 0.1, n),
        "clipped": np.clip(2.0 * np.sin(2 * np.pi * 700 * t), -1.0, 1.0),
    }
    payload: dict[str, np.ndarray] = {}
    for name, signal in signals.items():
        result = analyze_audio(signal, config)
        for stage, values in result.items():
            payload[f"{name}_{stage}"] = values
    np.savez_compressed(path, **payload)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Generate FPGA audio feature reference vectors")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    write_reference_vectors(args.output)
