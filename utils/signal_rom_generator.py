#!/usr/bin/env python3
"""
signal_rom_generator_extended.py

Gerador de ROM de sinais para estímulo I2S/FFT com:
- API fluente de configuração
- sinais sintéticos
- importação de WAV
- exportação MIF/HEX
- plot do sinal no tempo
- plot da FFT esperada
- leitura e comparação com FFT da FPGA via CSV

Dependências:
- Python 3.10+
- numpy
- matplotlib

Formato esperado do CSV da FPGA:
- cabeçalho com colunas:
    real, imag
  e opcionalmente:
    fftBfpExp
- ou sem cabeçalho, desde que sejam 2 ou 3 colunas
- se fftBfpExp vier apenas na última linha, o script tenta detectar

Observação:
O valor correto da FFT da FPGA é:
    (real + j*imag) * 2^fftBfpExp
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
import csv
import math
import wave
from typing import Iterable

import numpy as np
import matplotlib.pyplot as plt


class OutputFormat(str, Enum):
    MIF = "mif"
    HEX = "hex"


class WindowPolicy(str, Enum):
    STRICT = "strict"
    TRUNCATE = "truncate"
    PAD_ZERO = "pad_zero"


class QuantizationMode(str, Enum):
    FULL_SCALE = "full_scale"
    PRESERVE_PEAK = "preserve_peak"


class AudioChannelMode(str, Enum):
    MONO_MIX = "mono_mix"
    LEFT_ONLY = "left_only"
    RIGHT_ONLY = "right_only"


@dataclass
class SignalRomConfig:
    n_points: int = 512
    sample_bits: int = 24
    sample_rate_hz: int = 48_828

    output_format: OutputFormat = OutputFormat.MIF
    output_dir: Path = Path("build_rom")
    output_basename: str = "signals_rom"

    window_policy: WindowPolicy = WindowPolicy.PAD_ZERO
    quantization_mode: QuantizationMode = QuantizationMode.FULL_SCALE
    audio_channel_mode: AudioChannelMode = AudioChannelMode.MONO_MIX

    uppercase_hex: bool = False
    signed_decimal_mif: bool = False
    clamp_on_overflow: bool = True
    overwrite: bool = True
    verbose: bool = True

    # Plot / análise
    save_plots: bool = True
    plot_dpi: int = 150

    # ---------- Fluent API ----------
    def with_n_points(self, value: int) -> "SignalRomConfig":
        self.n_points = int(value)
        return self

    def with_sample_bits(self, value: int) -> "SignalRomConfig":
        self.sample_bits = int(value)
        return self

    def with_sample_rate_hz(self, value: int) -> "SignalRomConfig":
        self.sample_rate_hz = int(value)
        return self

    def with_output_format(self, value: OutputFormat | str) -> "SignalRomConfig":
        self.output_format = OutputFormat(value)
        return self

    def with_output_dir(self, value: str | Path) -> "SignalRomConfig":
        self.output_dir = Path(value)
        return self

    def with_output_basename(self, value: str) -> "SignalRomConfig":
        self.output_basename = str(value)
        return self

    def with_window_policy(self, value: WindowPolicy | str) -> "SignalRomConfig":
        self.window_policy = WindowPolicy(value)
        return self

    def with_quantization_mode(self, value: QuantizationMode | str) -> "SignalRomConfig":
        self.quantization_mode = QuantizationMode(value)
        return self

    def with_audio_channel_mode(self, value: AudioChannelMode | str) -> "SignalRomConfig":
        self.audio_channel_mode = AudioChannelMode(value)
        return self

    def with_uppercase_hex(self, value: bool) -> "SignalRomConfig":
        self.uppercase_hex = bool(value)
        return self

    def with_signed_decimal_mif(self, value: bool) -> "SignalRomConfig":
        self.signed_decimal_mif = bool(value)
        return self

    def with_clamp_on_overflow(self, value: bool) -> "SignalRomConfig":
        self.clamp_on_overflow = bool(value)
        return self

    def with_overwrite(self, value: bool) -> "SignalRomConfig":
        self.overwrite = bool(value)
        return self

    def with_verbose(self, value: bool) -> "SignalRomConfig":
        self.verbose = bool(value)
        return self

    def with_save_plots(self, value: bool) -> "SignalRomConfig":
        self.save_plots = bool(value)
        return self

    def with_plot_dpi(self, value: int) -> "SignalRomConfig":
        self.plot_dpi = int(value)
        return self

    # ---------- úteis ----------
    @property
    def signed_min(self) -> int:
        return -(1 << (self.sample_bits - 1))

    @property
    def signed_max(self) -> int:
        return (1 << (self.sample_bits - 1)) - 1

    @property
    def hex_width(self) -> int:
        return math.ceil(self.sample_bits / 4)

    def validate(self) -> None:
        if self.n_points <= 0:
            raise ValueError("n_points deve ser > 0")
        if self.sample_bits <= 1:
            raise ValueError("sample_bits deve ser > 1")
        if self.sample_rate_hz <= 0:
            raise ValueError("sample_rate_hz deve ser > 0")
        if not self.output_basename:
            raise ValueError("output_basename não pode ser vazio")


@dataclass
class SignalExample:
    name: str
    samples_float: np.ndarray
    metadata: dict = field(default_factory=dict)


class SignalFactory:
    def __init__(self, config: SignalRomConfig):
        self.config = config

    def _time_axis(self) -> np.ndarray:
        return np.arange(self.config.n_points, dtype=np.float64) / self.config.sample_rate_hz

    def sine(self, freq_hz: float, amplitude: float = 1.0, phase_rad: float = 0.0, name: str | None = None) -> SignalExample:
        t = self._time_axis()
        x = amplitude * np.sin(2.0 * np.pi * freq_hz * t + phase_rad)
        return SignalExample(
            name=name or f"sine_{freq_hz:.3f}Hz",
            samples_float=x,
            metadata={"kind": "sine", "freq_hz": freq_hz, "amplitude": amplitude, "phase_rad": phase_rad},
        )

    def cosine(self, freq_hz: float, amplitude: float = 1.0, phase_rad: float = 0.0, name: str | None = None) -> SignalExample:
        t = self._time_axis()
        x = amplitude * np.cos(2.0 * np.pi * freq_hz * t + phase_rad)
        return SignalExample(
            name=name or f"cosine_{freq_hz:.3f}Hz",
            samples_float=x,
            metadata={"kind": "cosine", "freq_hz": freq_hz, "amplitude": amplitude, "phase_rad": phase_rad},
        )

    def square(self, freq_hz: float, amplitude: float = 1.0, duty: float = 0.5, name: str | None = None) -> SignalExample:
        t = self._time_axis()
        phase = (freq_hz * t) % 1.0
        x = np.where(phase < duty, amplitude, -amplitude)
        return SignalExample(
            name=name or f"square_{freq_hz:.3f}Hz",
            samples_float=x.astype(np.float64),
            metadata={"kind": "square", "freq_hz": freq_hz, "amplitude": amplitude, "duty": duty},
        )

    def sawtooth(self, freq_hz: float, amplitude: float = 1.0, name: str | None = None) -> SignalExample:
        t = self._time_axis()
        phase = (freq_hz * t) % 1.0
        x = amplitude * (2.0 * phase - 1.0)
        return SignalExample(
            name=name or f"saw_{freq_hz:.3f}Hz",
            samples_float=x,
            metadata={"kind": "sawtooth", "freq_hz": freq_hz, "amplitude": amplitude},
        )

    def triangle(self, freq_hz: float, amplitude: float = 1.0, name: str | None = None) -> SignalExample:
        t = self._time_axis()
        phase = (freq_hz * t) % 1.0
        x = amplitude * (4.0 * np.abs(phase - 0.5) - 1.0)
        return SignalExample(
            name=name or f"triangle_{freq_hz:.3f}Hz",
            samples_float=x,
            metadata={"kind": "triangle", "freq_hz": freq_hz, "amplitude": amplitude},
        )

    def impulse(self, amplitude: float = 1.0, index: int = 0, name: str | None = None) -> SignalExample:
        x = np.zeros(self.config.n_points, dtype=np.float64)
        if 0 <= index < self.config.n_points:
            x[index] = amplitude
        return SignalExample(
            name=name or f"impulse_{index}",
            samples_float=x,
            metadata={"kind": "impulse", "amplitude": amplitude, "index": index},
        )

    def dc(self, level: float, name: str | None = None) -> SignalExample:
        x = np.full(self.config.n_points, level, dtype=np.float64)
        return SignalExample(
            name=name or f"dc_{level}",
            samples_float=x,
            metadata={"kind": "dc", "level": level},
        )

    def chirp_linear(self, f0_hz: float, f1_hz: float, amplitude: float = 1.0, name: str | None = None) -> SignalExample:
        t = self._time_axis()
        T = self.config.n_points / self.config.sample_rate_hz
        k = (f1_hz - f0_hz) / T
        phase = 2.0 * np.pi * (f0_hz * t + 0.5 * k * t**2)
        x = amplitude * np.sin(phase)
        return SignalExample(
            name=name or f"chirp_{f0_hz:.1f}_{f1_hz:.1f}",
            samples_float=x,
            metadata={"kind": "chirp_linear", "f0_hz": f0_hz, "f1_hz": f1_hz, "amplitude": amplitude},
        )

    def sum_of_sines(self, components: Iterable[tuple[float, float, float]], name: str = "sum_of_sines") -> SignalExample:
        t = self._time_axis()
        x = np.zeros_like(t)
        comp_meta = []
        for freq_hz, amplitude, phase_rad in components:
            x += amplitude * np.sin(2.0 * np.pi * freq_hz * t + phase_rad)
            comp_meta.append({"freq_hz": freq_hz, "amplitude": amplitude, "phase_rad": phase_rad})
        return SignalExample(
            name=name,
            samples_float=x,
            metadata={"kind": "sum_of_sines", "components": comp_meta},
        )

    def from_wav(self, wav_path: str | Path, name: str | None = None) -> SignalExample:
        wav_path = Path(wav_path)

        with wave.open(str(wav_path), "rb") as wf:
            n_channels = wf.getnchannels()
            sampwidth = wf.getsampwidth()
            n_frames = wf.getnframes()
            framerate = wf.getframerate()
            raw = wf.readframes(n_frames)

        if sampwidth == 1:
            data = np.frombuffer(raw, dtype=np.uint8).astype(np.float64)
            data = (data - 128.0) / 128.0
        elif sampwidth == 2:
            data = np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0
        elif sampwidth == 3:
            b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3)
            vals = (
                b[:, 0].astype(np.int32)
                | (b[:, 1].astype(np.int32) << 8)
                | (b[:, 2].astype(np.int32) << 16)
            )
            sign_mask = 1 << 23
            vals = (vals ^ sign_mask) - sign_mask
            data = vals.astype(np.float64) / float(1 << 23)
        elif sampwidth == 4:
            data = np.frombuffer(raw, dtype=np.int32).astype(np.float64) / float(1 << 31)
        else:
            raise ValueError(f"Largura WAV não suportada: {sampwidth} bytes")

        if n_channels > 1:
            data = data.reshape(-1, n_channels)
            mode = self.config.audio_channel_mode
            if mode == AudioChannelMode.MONO_MIX:
                mono = np.mean(data, axis=1)
            elif mode == AudioChannelMode.LEFT_ONLY:
                mono = data[:, 0]
            elif mode == AudioChannelMode.RIGHT_ONLY:
                if n_channels < 2:
                    raise ValueError("Arquivo WAV não possui canal direito")
                mono = data[:, 1]
            else:
                raise ValueError(f"Modo de canal inválido: {mode}")
        else:
            mono = data

        mono = self._resample_linear(mono, framerate, self.config.sample_rate_hz)
        mono = self._fit_window(mono)

        return SignalExample(
            name=name or wav_path.stem,
            samples_float=mono,
            metadata={
                "kind": "wav",
                "source": str(wav_path),
                "original_sample_rate_hz": framerate,
                "audio_channel_mode": self.config.audio_channel_mode.value,
            },
        )

    def _resample_linear(self, x: np.ndarray, sr_in: int, sr_out: int) -> np.ndarray:
        if sr_in == sr_out:
            return x.astype(np.float64)

        duration = len(x) / sr_in
        n_out = max(1, int(round(duration * sr_out)))
        t_in = np.arange(len(x), dtype=np.float64) / sr_in
        t_out = np.arange(n_out, dtype=np.float64) / sr_out
        return np.interp(t_out, t_in, x).astype(np.float64)

    def _fit_window(self, x: np.ndarray) -> np.ndarray:
        n = self.config.n_points
        if len(x) == n:
            return x.astype(np.float64)

        if self.config.window_policy == WindowPolicy.STRICT:
            raise ValueError(f"O sinal possui {len(x)} amostras, mas n_points={n}")

        if self.config.window_policy == WindowPolicy.TRUNCATE:
            return x[:n].astype(np.float64)

        if self.config.window_policy == WindowPolicy.PAD_ZERO:
            if len(x) > n:
                return x[:n].astype(np.float64)
            out = np.zeros(n, dtype=np.float64)
            out[:len(x)] = x
            return out

        raise ValueError(f"window_policy inválido: {self.config.window_policy}")


class FftCsvAnalyzer:
    """
    Leitura e correção da FFT da FPGA.
    Valor correto:
        Xcorr = (real + j*imag) * 2^fftBfpExp
    """

    def __init__(self, csv_path: str | Path):
        self.csv_path = Path(csv_path)

    def load_corrected_fft(self) -> tuple[np.ndarray, int]:
        rows = []
        with self.csv_path.open("r", encoding="utf-8") as f:
            sample = f.read(4096)
            f.seek(0)

            has_header = any(h in sample.lower() for h in ["real", "imag", "fftbfpexp"])
            if has_header:
                reader = csv.DictReader(f)
                for row in reader:
                    rows.append(row)
            else:
                reader = csv.reader(f)
                for row in reader:
                    if row:
                        rows.append(row)

        reals = []
        imags = []
        bfp_list = []

        if rows and isinstance(rows[0], dict):
            for row in rows:
                if row.get("real", "").strip() == "":
                    continue
                reals.append(float(row["real"]))
                imags.append(float(row["imag"]))
                if "fftBfpExp" in row and row["fftBfpExp"].strip() != "":
                    bfp_list.append(int(float(row["fftBfpExp"])))
        else:
            for row in rows:
                if len(row) < 2:
                    continue
                reals.append(float(row[0]))
                imags.append(float(row[1]))
                if len(row) >= 3 and str(row[2]).strip() != "":
                    bfp_list.append(int(float(row[2])))

        if not reals:
            raise ValueError("CSV não possui dados válidos de real/imag")

        if len(bfp_list) == 0:
            raise ValueError("CSV não possui fftBfpExp")

        # usa o último valor disponível
        fft_bfp_exp = int(bfp_list[-1])

        raw = np.asarray(reals, dtype=np.float64) + 1j * np.asarray(imags, dtype=np.float64)
        corrected = raw * (2 ** fft_bfp_exp)
        return corrected, fft_bfp_exp


class SignalRomGenerator:
    def __init__(self, config: SignalRomConfig):
        self.config = config
        self.config.validate()
        self.examples: list[SignalExample] = []

    def add_example(self, example: SignalExample) -> "SignalRomGenerator":
        x = np.asarray(example.samples_float, dtype=np.float64)
        if len(x) != self.config.n_points:
            raise ValueError(
                f"Exemplo '{example.name}' possui {len(x)} amostras, "
                f"mas n_points={self.config.n_points}"
            )
        self.examples.append(example)
        return self

    def add_examples(self, examples: Iterable[SignalExample]) -> "SignalRomGenerator":
        for ex in examples:
            self.add_example(ex)
        return self

    def build_int_matrix(self) -> np.ndarray:
        if not self.examples:
            raise ValueError("Nenhum exemplo foi adicionado")
        rows = [self._quantize(ex.samples_float) for ex in self.examples]
        return np.vstack(rows)

    def build_linear_rom(self) -> np.ndarray:
        return self.build_int_matrix().reshape(-1)

    def export(self) -> dict[str, Path]:
        self.config.output_dir.mkdir(parents=True, exist_ok=True)
        rom = self.build_linear_rom()

        basename = self.config.output_basename
        outputs: dict[str, Path] = {}

        if self.config.output_format == OutputFormat.MIF:
            rom_path = self.config.output_dir / f"{basename}.mif"
            self._safe_write(rom_path, self._render_mif(rom))
        elif self.config.output_format == OutputFormat.HEX:
            rom_path = self.config.output_dir / f"{basename}.hex"
            self._safe_write(rom_path, self._render_hex(rom))
        else:
            raise ValueError(f"Formato inválido: {self.config.output_format}")

        outputs["rom"] = rom_path

        mirror_path = self.config.output_dir / f"{basename}_mirror.hex"
        self._safe_write(mirror_path, self._render_hex(rom))
        outputs["mirror_hex"] = mirror_path

        map_path = self.config.output_dir / f"{basename}_map.txt"
        self._safe_write(map_path, self._render_map())
        outputs["map"] = map_path

        metadata_path = self.config.output_dir / f"{basename}_metadata.txt"
        self._safe_write(metadata_path, self._render_metadata())
        outputs["metadata"] = metadata_path

        return outputs

    def plot_example_time(self, example_index: int, save: bool = True, show: bool = False) -> Path | None:
        ex = self.examples[example_index]
        t = np.arange(self.config.n_points) / self.config.sample_rate_hz

        fig = plt.figure(figsize=(10, 4))
        plt.plot(t, ex.samples_float)
        plt.xlabel("Tempo (s)")
        plt.ylabel("Amplitude")
        plt.title(f"Sinal no tempo: {ex.name}")
        plt.grid(True)

        out_path = None
        if save and self.config.save_plots:
            out_path = self.config.output_dir / f"{self.config.output_basename}_{example_index:02d}_{ex.name}_time.png"
            fig.savefig(out_path, dpi=self.config.plot_dpi, bbox_inches="tight")
            if self.config.verbose:
                print(f"[ok] {out_path}")

        if show:
            plt.show()
        plt.close(fig)
        return out_path

    def compute_expected_fft(self, example_index: int) -> tuple[np.ndarray, np.ndarray]:
        ex = self.examples[example_index]
        x = np.asarray(ex.samples_float, dtype=np.float64)
        X = np.fft.fft(x)
        freqs = np.fft.fftfreq(len(x), d=1.0 / self.config.sample_rate_hz)
        return freqs, X

    def plot_expected_fft(self, example_index: int, save: bool = True, show: bool = False) -> Path | None:
        ex = self.examples[example_index]
        freqs, X = self.compute_expected_fft(example_index)

        half = len(X) // 2
        fig = plt.figure(figsize=(10, 4))
        plt.plot(freqs[:half], np.abs(X[:half]))
        plt.xlabel("Frequência (Hz)")
        plt.ylabel("|X[k]|")
        plt.title(f"FFT esperada: {ex.name}")
        plt.grid(True)

        out_path = None
        if save and self.config.save_plots:
            out_path = self.config.output_dir / f"{self.config.output_basename}_{example_index:02d}_{ex.name}_fft_expected.png"
            fig.savefig(out_path, dpi=self.config.plot_dpi, bbox_inches="tight")
            if self.config.verbose:
                print(f"[ok] {out_path}")

        if show:
            plt.show()
        plt.close(fig)
        return out_path

    def compare_with_fpga_csv(
        self,
        example_index: int,
        csv_path: str | Path,
        save: bool = True,
        show: bool = False
    ) -> dict[str, Path | int | float]:
        ex = self.examples[example_index]
        freqs, X_expected = self.compute_expected_fft(example_index)

        analyzer = FftCsvAnalyzer(csv_path)
        X_fpga, fft_bfp_exp = analyzer.load_corrected_fft()

        n = min(len(X_expected), len(X_fpga))
        X_expected = X_expected[:n]
        X_fpga = X_fpga[:n]
        freqs = freqs[:n]

        err_abs = np.abs(X_fpga - X_expected)
        rmse = float(np.sqrt(np.mean(err_abs**2)))
        max_err = float(np.max(err_abs))

        out = {
            "fftBfpExp": fft_bfp_exp,
            "rmse": rmse,
            "max_abs_error": max_err,
        }

        half = n // 2

        fig = plt.figure(figsize=(10, 5))
        plt.plot(freqs[:half], np.abs(X_expected[:half]), label="Esperada (Python)")
        plt.plot(freqs[:half], np.abs(X_fpga[:half]), label="FPGA corrigida", linestyle="--")
        plt.xlabel("Frequência (Hz)")
        plt.ylabel("Magnitude")
        plt.title(f"Comparação FFT: {ex.name} | fftBfpExp={fft_bfp_exp}")
        plt.grid(True)
        plt.legend()

        if save and self.config.save_plots:
            cmp_path = self.config.output_dir / f"{self.config.output_basename}_{example_index:02d}_{ex.name}_fft_compare.png"
            fig.savefig(cmp_path, dpi=self.config.plot_dpi, bbox_inches="tight")
            out["compare_plot"] = cmp_path
            if self.config.verbose:
                print(f"[ok] {cmp_path}")

        if show:
            plt.show()
        plt.close(fig)

        fig_err = plt.figure(figsize=(10, 4))
        plt.plot(freqs[:half], err_abs[:half])
        plt.xlabel("Frequência (Hz)")
        plt.ylabel("|Erro|")
        plt.title(f"Erro FFT: {ex.name}")
        plt.grid(True)

        if save and self.config.save_plots:
            err_path = self.config.output_dir / f"{self.config.output_basename}_{example_index:02d}_{ex.name}_fft_error.png"
            fig_err.savefig(err_path, dpi=self.config.plot_dpi, bbox_inches="tight")
            out["error_plot"] = err_path
            if self.config.verbose:
                print(f"[ok] {err_path}")

        if show:
            plt.show()
        plt.close(fig_err)

        report_path = self.config.output_dir / f"{self.config.output_basename}_{example_index:02d}_{ex.name}_fft_report.txt"
        report_lines = [
            f"example_index={example_index}",
            f"example_name={ex.name}",
            f"csv_path={csv_path}",
            f"fftBfpExp={fft_bfp_exp}",
            f"rmse={rmse}",
            f"max_abs_error={max_err}",
        ]
        self._safe_write(report_path, "\n".join(report_lines) + "\n")
        out["report"] = report_path

        return out

    def _safe_write(self, path: Path, content: str) -> None:
        if path.exists() and not self.config.overwrite:
            raise FileExistsError(f"Arquivo já existe: {path}")
        path.write_text(content, encoding="utf-8")
        if self.config.verbose:
            print(f"[ok] {path}")

    def _quantize(self, x: np.ndarray) -> np.ndarray:
        x = np.asarray(x, dtype=np.float64)

        if self.config.quantization_mode == QuantizationMode.PRESERVE_PEAK:
            peak = float(np.max(np.abs(x))) if x.size else 1.0
            if peak > 0:
                x = x / peak

        x = np.clip(x, -1.0, 1.0)

        scale = float(1 << (self.config.sample_bits - 1))
        y = np.round(x * scale).astype(np.int64)

        y = np.where(y > self.config.signed_max, self.config.signed_max, y)

        if self.config.clamp_on_overflow:
            y = np.clip(y, self.config.signed_min, self.config.signed_max)

        return y.astype(np.int64)

    def _to_twos_hex(self, value: int) -> str:
        mask = (1 << self.config.sample_bits) - 1
        raw = value & mask
        fmt = f"0{self.config.hex_width}{'X' if self.config.uppercase_hex else 'x'}"
        return format(raw, fmt)

    def _render_hex(self, rom: np.ndarray) -> str:
        return "\n".join(self._to_twos_hex(int(v)) for v in rom) + "\n"

    def _render_mif(self, rom: np.ndarray) -> str:
        lines = [
            f"DEPTH = {len(rom)};",
            f"WIDTH = {self.config.sample_bits};",
            "ADDRESS_RADIX = UNS;",
        ]

        if self.config.signed_decimal_mif:
            lines.append("DATA_RADIX = DEC;")
            lines.append("CONTENT BEGIN")
            for addr, v in enumerate(rom):
                lines.append(f"    {addr} : {int(v)};")
        else:
            lines.append("DATA_RADIX = HEX;")
            lines.append("CONTENT BEGIN")
            for addr, v in enumerate(rom):
                lines.append(f"    {addr} : {self._to_twos_hex(int(v))};")

        lines.append("END;")
        return "\n".join(lines) + "\n"

    def _render_map(self) -> str:
        lines = []
        n = self.config.n_points
        for idx, ex in enumerate(self.examples):
            start = idx * n
            stop = start + n - 1
            lines.append(f"example {idx}: [{start} .. {stop}] -> {ex.name}")
        return "\n".join(lines) + "\n"

    def _render_metadata(self) -> str:
        lines = [
            f"n_points={self.config.n_points}",
            f"sample_bits={self.config.sample_bits}",
            f"sample_rate_hz={self.config.sample_rate_hz}",
            f"output_format={self.config.output_format.value}",
            f"window_policy={self.config.window_policy.value}",
            f"quantization_mode={self.config.quantization_mode.value}",
            f"audio_channel_mode={self.config.audio_channel_mode.value}",
            f"n_examples={len(self.examples)}",
            "",
        ]
        for idx, ex in enumerate(self.examples):
            lines.append(f"[example {idx}]")
            lines.append(f"name={ex.name}")
            for k, v in ex.metadata.items():
                lines.append(f"{k}={v}")
            lines.append("")
        return "\n".join(lines).rstrip() + "\n"


def main() -> None:
    # ============================================================
    # Configuração fluente
    # ============================================================
    cfg = (
        SignalRomConfig()
        .with_n_points(512)
        .with_sample_bits(24)
        .with_sample_rate_hz(48_828)
        .with_output_format(OutputFormat.MIF)   # troque para HEX se quiser
        .with_output_dir("../build_rom")
        .with_output_basename("signals_rom")
        .with_window_policy(WindowPolicy.PAD_ZERO)
        .with_quantization_mode(QuantizationMode.FULL_SCALE)
        .with_audio_channel_mode(AudioChannelMode.MONO_MIX)
        .with_uppercase_hex(False)
        .with_signed_decimal_mif(False)
        .with_clamp_on_overflow(True)
        .with_overwrite(True)
        .with_verbose(True)
        .with_save_plots(True)
        .with_plot_dpi(150)
    )

    factory = SignalFactory(cfg)
    generator = SignalRomGenerator(cfg)

    # ============================================================
    # Exemplos
    # ============================================================
    generator.add_examples([
        factory.sine(freq_hz=1000.0, amplitude=0.9, name="sine_1k"),
        factory.sine(freq_hz=3000.0, amplitude=0.9, name="sine_3k"),
        factory.sum_of_sines(
            components=[
                (1000.0, 0.55, 0.0),
                (2500.0, 0.25, 0.0),
                (7000.0, 0.15, 0.0),
            ],
            name="sum_1k_2p5k_7k",
        ),
        factory.chirp_linear(f0_hz=500.0, f1_hz=8000.0, amplitude=0.8, name="chirp_500_8k"),
        factory.square(freq_hz=1000.0, amplitude=0.7, duty=0.5, name="square_1k"),
        factory.triangle(freq_hz=1500.0, amplitude=0.7, name="triangle_1p5k"),
        factory.impulse(amplitude=1.0, index=0, name="impulse_0"),
        factory.dc(level=0.25, name="dc_0p25"),
    ])

    # ============================================================
    # Exemplo WAV
    # ============================================================
    # generator.add_example(
    #     factory.from_wav("meu_audio.wav", name="wav_meu_audio")
    # )

    outputs = generator.export()

    print("\nArquivos gerados:")
    for key, path in outputs.items():
        print(f"  - {key}: {path}")

    # ============================================================
    # Geração de plots para o exemplo 0
    # ============================================================
    generator.plot_example_time(example_index=0, save=True, show=False)
    generator.plot_expected_fft(example_index=0, save=True, show=False)

    # ============================================================
    # Comparação com FFT da FPGA
    #
    # Espera um CSV com colunas:
    # real, imag, fftBfpExp
    #
    # O script aplica:
    # (real + j*imag) * 2^fftBfpExp
    #
    # Descomente quando tiver o CSV:
    # ============================================================
    #
    # result = generator.compare_with_fpga_csv(
    #     example_index=0,
    #     csv_path="fft_saida_fpga.csv",
    #     save=True,
    #     show=False
    # )
    #
    # print("\nComparação FPGA:")
    # for k, v in result.items():
    #     print(f"  - {k}: {v}")


if __name__ == "__main__":
    main()