import math
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Optional

import numpy as np
import matplotlib.pyplot as plt


# ============================================================
# Configuração
# ============================================================

@dataclass
class RomConfig:
    depth: int                  # número de amostras na ROM
    data_width: int             # largura da palavra da ROM
    signed: bool = True         # usa representação signed two's complement
    sample_rate: float = 48_000.0  # Hz


# ============================================================
# Utilidades numéricas
# ============================================================

def dbfs(x: np.ndarray, eps: float = 1e-15) -> np.ndarray:
    """Converte magnitude linear para dBFS."""
    return 20.0 * np.log10(np.maximum(np.abs(x), eps))


def normalize_peak(x: np.ndarray, peak: float = 0.95) -> np.ndarray:
    """Normaliza o sinal para um pico desejado."""
    max_abs = np.max(np.abs(x))
    if max_abs == 0:
        return x.copy()
    return peak * x / max_abs


def quantize_signed(x: np.ndarray, bits: int) -> np.ndarray:
    """
    Quantiza sinal em [-1, 1) para inteiro signed em complemento de 2.
    Ex.: 16 bits -> faixa [-32768, 32767]
    """
    if bits < 2:
        raise ValueError("bits deve ser >= 2 para signed.")

    x = np.asarray(x, dtype=float)
    x = np.clip(x, -1.0, 1.0 - (1.0 / (2 ** (bits - 1))))

    max_pos = (2 ** (bits - 1)) - 1
    min_neg = -(2 ** (bits - 1))

    q = np.round(x * max_pos).astype(int)
    q = np.clip(q, min_neg, max_pos)
    return q


def signed_to_twos_complement(values: np.ndarray, bits: int) -> np.ndarray:
    """Converte inteiros signed para representação unsigned equivalente."""
    mod = 2 ** bits
    return np.array([(v + mod) % mod for v in values], dtype=int)


def twos_complement_to_signed(values: np.ndarray, bits: int) -> np.ndarray:
    """Converte inteiros unsigned em complemento de 2 para signed."""
    values = np.asarray(values, dtype=int)
    limit = 2 ** (bits - 1)
    mod = 2 ** bits
    return np.where(values >= limit, values - mod, values)


# ============================================================
# Geradores de forma de onda
# ============================================================

def time_vector(n: int, fs: float) -> np.ndarray:
    return np.arange(n) / fs


def sine_wave(n: int, fs: float, f0: float, amplitude: float = 1.0, phase: float = 0.0) -> np.ndarray:
    t = time_vector(n, fs)
    return amplitude * np.sin(2 * np.pi * f0 * t + phase)


def multi_sine(
    n: int,
    fs: float,
    freqs: Iterable[float],
    amplitudes: Optional[Iterable[float]] = None,
    phases: Optional[Iterable[float]] = None,
) -> np.ndarray:
    freqs = list(freqs)
    if amplitudes is None:
        amplitudes = [1.0] * len(freqs)
    if phases is None:
        phases = [0.0] * len(freqs)

    amplitudes = list(amplitudes)
    phases = list(phases)

    if not (len(freqs) == len(amplitudes) == len(phases)):
        raise ValueError("freqs, amplitudes e phases devem ter o mesmo tamanho.")

    t = time_vector(n, fs)
    x = np.zeros(n, dtype=float)
    for f, a, p in zip(freqs, amplitudes, phases):
        x += a * np.sin(2 * np.pi * f * t + p)
    return x


def square_wave(n: int, fs: float, f0: float, amplitude: float = 1.0, duty: float = 0.5) -> np.ndarray:
    t = time_vector(n, fs)
    phase = (f0 * t) % 1.0
    return amplitude * np.where(phase < duty, 1.0, -1.0)


def impulse(n: int, amplitude: float = 1.0, index: int = 0) -> np.ndarray:
    if not (0 <= index < n):
        raise ValueError("index do impulso fora da faixa.")
    x = np.zeros(n, dtype=float)
    x[index] = amplitude
    return x


def step_signal(n: int, amplitude: float = 1.0, index: int = 0) -> np.ndarray:
    if not (0 <= index < n):
        raise ValueError("index do degrau fora da faixa.")
    x = np.zeros(n, dtype=float)
    x[index:] = amplitude
    return x


def chirp_linear(n: int, fs: float, f_start: float, f_end: float, amplitude: float = 1.0) -> np.ndarray:
    t = time_vector(n, fs)
    T = n / fs
    k = (f_end - f_start) / T
    phase = 2 * np.pi * (f_start * t + 0.5 * k * t**2)
    return amplitude * np.sin(phase)


def white_noise(n: int, amplitude: float = 1.0, seed: Optional[int] = None) -> np.ndarray:
    rng = np.random.default_rng(seed)
    return amplitude * rng.standard_normal(n)


# ============================================================
# FFT esperada
# ============================================================

def compute_fft_reference(x: np.ndarray, fs: float, window: Optional[str] = None):
    """
    Calcula a FFT de referência.
    Retorna:
      freqs: eixo de frequência
      X: FFT complexa
      mag: magnitude linear normalizada por N
      mag_db: magnitude em dBFS
    """
    x = np.asarray(x, dtype=float)
    n = len(x)

    if window is None:
        w = np.ones(n)
        coherent_gain = 1.0
    elif window.lower() == "hann":
        w = np.hanning(n)
        coherent_gain = np.mean(w)
    else:
        raise ValueError("Janela suportada: None ou 'hann'.")

    xw = x * w
    X = np.fft.fft(xw)
    freqs = np.fft.fftfreq(n, d=1.0 / fs)

    mag = np.abs(X) / (n * coherent_gain)
    mag_db = dbfs(mag)

    return freqs, X, mag, mag_db


def positive_spectrum(freqs: np.ndarray, X: np.ndarray, mag: np.ndarray, mag_db: np.ndarray):
    """Retorna apenas metade positiva do espectro."""
    n = len(freqs)
    half = n // 2
    return freqs[:half], X[:half], mag[:half], mag_db[:half]


# ============================================================
# Geração do arquivo MIF
# ============================================================

def write_mif(path: str | Path, values: np.ndarray, width: int, depth: int, radix_address: str = "UNS", radix_data: str = "HEX"):
    """
    Escreve arquivo .mif para Quartus.
    values deve conter inteiros já no formato unsigned final.
    """
    values = np.asarray(values, dtype=int)

    if len(values) > depth:
        raise ValueError(f"Quantidade de valores ({len(values)}) excede a profundidade ({depth}).")

    path = Path(path)
    hex_digits = math.ceil(width / 4)

    with path.open("w", encoding="utf-8") as f:
        f.write(f"WIDTH={width};\n")
        f.write(f"DEPTH={depth};\n\n")
        f.write(f"ADDRESS_RADIX={radix_address};\n")
        f.write(f"DATA_RADIX={radix_data};\n\n")
        f.write("CONTENT BEGIN\n")

        for addr in range(depth):
            val = int(values[addr]) if addr < len(values) else 0
            if radix_data.upper() == "HEX":
                data_str = f"{val:0{hex_digits}X}"
            else:
                data_str = str(val)
            f.write(f"    {addr} : {data_str};\n")

        f.write("END;\n")


def generate_rom_mif_from_signal(
    x: np.ndarray,
    config: RomConfig,
    output_path: str | Path,
    normalize: bool = True,
    peak: float = 0.95,
):
    """
    Normaliza, quantiza e gera .mif a partir do sinal.
    Retorna:
      x_norm
      q_signed
      q_twos
    """
    if len(x) != config.depth:
        raise ValueError(f"O sinal deve ter exatamente {config.depth} amostras.")

    x_proc = normalize_peak(x, peak=peak) if normalize else x.copy()
    q_signed = quantize_signed(x_proc, config.data_width)

    if config.signed:
        q_twos = signed_to_twos_complement(q_signed, config.data_width)
    else:
        raise NotImplementedError("Versão atual implementa apenas ROM signed.")

    write_mif(output_path, q_twos, width=config.data_width, depth=config.depth)
    return x_proc, q_signed, q_twos


# ============================================================
# Plots
# ============================================================

def plot_time_domain(x: np.ndarray, fs: float, title: str = "Sinal no tempo", samples: Optional[int] = None):
    n = len(x)
    t = np.arange(n) / fs

    if samples is not None:
        x = x[:samples]
        t = t[:samples]

    plt.figure(figsize=(12, 4))
    plt.plot(t, x)
    plt.title(title)
    plt.xlabel("Tempo [s]")
    plt.ylabel("Amplitude")
    plt.grid(True)
    plt.tight_layout()
    plt.show()


def plot_spectrum(freqs: np.ndarray, mag: np.ndarray, mag_db: np.ndarray, title_prefix: str = "FFT esperada"):
    plt.figure(figsize=(12, 4))
    plt.plot(freqs, mag)
    plt.title(f"{title_prefix} - magnitude linear")
    plt.xlabel("Frequência [Hz]")
    plt.ylabel("|X[k]|")
    plt.grid(True)
    plt.tight_layout()
    plt.show()

    plt.figure(figsize=(12, 4))
    plt.plot(freqs, mag_db)
    plt.title(f"{title_prefix} - magnitude em dBFS")
    plt.xlabel("Frequência [Hz]")
    plt.ylabel("Magnitude [dBFS]")
    plt.grid(True)
    plt.tight_layout()
    plt.show()


# ============================================================
# Leitura de dados capturados
# ============================================================

def load_capture_csv(
    path: str | Path,
    delimiter: str = ",",
    skip_header: int = 0,
    time_col: Optional[int] = None,
    value_col: int = 1,
):
    """
    Carrega CSV exportado do Analog Discovery.
    Retorna:
      t: vetor de tempo ou None
      y: vetor de dados
    """
    data = np.loadtxt(path, delimiter=delimiter, skiprows=skip_header)

    if data.ndim == 1:
        y = data.astype(float)
        t = None
    else:
        y = data[:, value_col].astype(float)
        t = data[:, time_col].astype(float) if time_col is not None else None

    return t, y


# ============================================================
# Validação da FFT capturada
# ============================================================

def align_length(x_ref: np.ndarray, x_meas: np.ndarray):
    n = min(len(x_ref), len(x_meas))
    return x_ref[:n], x_meas[:n]


def validate_fft_from_time_capture(
    x_expected: np.ndarray,
    x_measured: np.ndarray,
    fs: float,
    window: Optional[str] = None,
    ignore_dc: bool = True,
):
    """
    Compara a FFT esperada com a FFT obtida a partir do sinal medido no tempo.

    Retorna dicionário com métricas:
      rmse_time
      corr_time
      rmse_mag
      corr_mag
      peak_bin_expected
      peak_bin_measured
      peak_freq_expected
      peak_freq_measured
    """
    x_expected, x_measured = align_length(x_expected, x_measured)

    rmse_time = float(np.sqrt(np.mean((x_expected - x_measured) ** 2)))

    if np.std(x_expected) > 0 and np.std(x_measured) > 0:
        corr_time = float(np.corrcoef(x_expected, x_measured)[0, 1])
    else:
        corr_time = float("nan")

    freqs_e, X_e, mag_e, mag_db_e = compute_fft_reference(x_expected, fs, window=window)
    freqs_m, X_m, mag_m, mag_db_m = compute_fft_reference(x_measured, fs, window=window)

    freqs_e, X_e, mag_e, mag_db_e = positive_spectrum(freqs_e, X_e, mag_e, mag_db_e)
    freqs_m, X_m, mag_m, mag_db_m = positive_spectrum(freqs_m, X_m, mag_m, mag_db_m)

    rmse_mag = float(np.sqrt(np.mean((mag_e - mag_m) ** 2)))

    if np.std(mag_e) > 0 and np.std(mag_m) > 0:
        corr_mag = float(np.corrcoef(mag_e, mag_m)[0, 1])
    else:
        corr_mag = float("nan")

    start_bin = 1 if ignore_dc else 0

    peak_bin_expected = int(np.argmax(mag_e[start_bin:]) + start_bin)
    peak_bin_measured = int(np.argmax(mag_m[start_bin:]) + start_bin)

    return {
        "rmse_time": rmse_time,
        "corr_time": corr_time,
        "rmse_mag": rmse_mag,
        "corr_mag": corr_mag,
        "peak_bin_expected": peak_bin_expected,
        "peak_bin_measured": peak_bin_measured,
        "peak_freq_expected": float(freqs_e[peak_bin_expected]),
        "peak_freq_measured": float(freqs_m[peak_bin_measured]),
        "freq_axis": freqs_e,
        "mag_expected": mag_e,
        "mag_measured": mag_m,
        "mag_db_expected": mag_db_e,
        "mag_db_measured": mag_db_m,
    }


def validate_fft_bins_direct(
    fft_expected: np.ndarray,
    fft_measured: np.ndarray,
):
    """
    Compara diretamente bins complexos da FFT.
    Útil se você conseguir exportar da FPGA os bins reais/imaginários.
    """
    fft_expected, fft_measured = align_length(
        np.asarray(fft_expected, dtype=complex),
        np.asarray(fft_measured, dtype=complex),
    )

    err = fft_expected - fft_measured
    rmse_complex = float(np.sqrt(np.mean(np.abs(err) ** 2)))
    rmse_mag = float(np.sqrt(np.mean((np.abs(fft_expected) - np.abs(fft_measured)) ** 2)))

    mag_exp = np.abs(fft_expected)
    mag_mea = np.abs(fft_measured)

    if np.std(mag_exp) > 0 and np.std(mag_mea) > 0:
        corr_mag = float(np.corrcoef(mag_exp, mag_mea)[0, 1])
    else:
        corr_mag = float("nan")

    return {
        "rmse_complex": rmse_complex,
        "rmse_mag": rmse_mag,
        "corr_mag": corr_mag,
    }


def plot_validation_results(results: dict, title: str = "Comparação de FFT"):
    freqs = results["freq_axis"]

    plt.figure(figsize=(12, 4))
    plt.plot(freqs, results["mag_expected"], label="Esperado")
    plt.plot(freqs, results["mag_measured"], label="Medido", alpha=0.8)
    plt.title(f"{title} - magnitude linear")
    plt.xlabel("Frequência [Hz]")
    plt.ylabel("|X[k]|")
    plt.grid(True)
    plt.legend()
    plt.tight_layout()
    plt.show()

    plt.figure(figsize=(12, 4))
    plt.plot(freqs, results["mag_db_expected"], label="Esperado")
    plt.plot(freqs, results["mag_db_measured"], label="Medido", alpha=0.8)
    plt.title(f"{title} - magnitude em dBFS")
    plt.xlabel("Frequência [Hz]")
    plt.ylabel("Magnitude [dBFS]")
    plt.grid(True)
    plt.legend()
    plt.tight_layout()
    plt.show()


# ============================================================
# Exemplos de uso
# ============================================================

def example_single_tone():
    config = RomConfig(
        depth=1024,
        data_width=16,
        signed=True,
        sample_rate=48_000.0,
    )

    # Escolha frequência alinhada com bin para evitar leakage:
    # f_bin = k * fs / N
    k = 32
    f0 = k * config.sample_rate / config.depth

    x = sine_wave(
        n=config.depth,
        fs=config.sample_rate,
        f0=f0,
        amplitude=0.9,
        phase=0.0,
    )

    x_norm, q_signed, q_twos = generate_rom_mif_from_signal(
        x=x,
        config=config,
        output_path="rom_single_tone.mif",
        normalize=False,
    )

    plot_time_domain(x_norm, config.sample_rate, title="Tom único no tempo", samples=256)

    freqs, X, mag, mag_db = compute_fft_reference(x_norm, config.sample_rate, window=None)
    freqs, X, mag, mag_db = positive_spectrum(freqs, X, mag, mag_db)
    plot_spectrum(freqs, mag, mag_db, title_prefix="FFT esperada - tom único")


def example_multi_tone():
    config = RomConfig(
        depth=1024,
        data_width=16,
        signed=True,
        sample_rate=48_000.0,
    )

    # Frequências alinhadas com bins
    bins = [8, 40, 100]
    freqs_hz = [b * config.sample_rate / config.depth for b in bins]

    x = multi_sine(
        n=config.depth,
        fs=config.sample_rate,
        freqs=freqs_hz,
        amplitudes=[1.0, 0.6, 0.25],
        phases=[0.0, 0.2, 1.0],
    )

    x_norm, q_signed, q_twos = generate_rom_mif_from_signal(
        x=x,
        config=config,
        output_path="rom_multi_tone.mif",
        normalize=True,
        peak=0.95,
    )

    plot_time_domain(x_norm, config.sample_rate, title="Multi-tom no tempo", samples=256)

    freqs, X, mag, mag_db = compute_fft_reference(x_norm, config.sample_rate, window=None)
    freqs, X, mag, mag_db = positive_spectrum(freqs, X, mag, mag_db)
    plot_spectrum(freqs, mag, mag_db, title_prefix="FFT esperada - multi-tom")


def example_square():
    config = RomConfig(
        depth=1024,
        data_width=16,
        signed=True,
        sample_rate=48_000.0,
    )

    k = 10
    f0 = k * config.sample_rate / config.depth

    x = square_wave(
        n=config.depth,
        fs=config.sample_rate,
        f0=f0,
        amplitude=0.8,
        duty=0.5,
    )

    x_norm, q_signed, q_twos = generate_rom_mif_from_signal(
        x=x,
        config=config,
        output_path="rom_square.mif",
        normalize=False,
    )

    plot_time_domain(x_norm, config.sample_rate, title="Onda quadrada", samples=256)

    freqs, X, mag, mag_db = compute_fft_reference(x_norm, config.sample_rate, window=None)
    freqs, X, mag, mag_db = positive_spectrum(freqs, X, mag, mag_db)
    plot_spectrum(freqs, mag, mag_db, title_prefix="FFT esperada - onda quadrada")


def example_impulse():
    config = RomConfig(
        depth=1024,
        data_width=16,
        signed=True,
        sample_rate=48_000.0,
    )

    x = impulse(
        n=config.depth,
        amplitude=1.0,
        index=0,
    )

    x_norm, q_signed, q_twos = generate_rom_mif_from_signal(
        x=x,
        config=config,
        output_path="rom_impulse.mif",
        normalize=False,
    )

    plot_time_domain(x_norm, config.sample_rate, title="Impulso", samples=64)

    freqs, X, mag, mag_db = compute_fft_reference(x_norm, config.sample_rate, window=None)
    freqs, X, mag, mag_db = positive_spectrum(freqs, X, mag, mag_db)
    plot_spectrum(freqs, mag, mag_db, title_prefix="FFT esperada - impulso")


def example_chirp():
    config = RomConfig(
        depth=1024,
        data_width=16,
        signed=True,
        sample_rate=48_000.0,
    )

    x = chirp_linear(
        n=config.depth,
        fs=config.sample_rate,
        f_start=500.0,
        f_end=10_000.0,
        amplitude=0.9,
    )

    x_norm, q_signed, q_twos = generate_rom_mif_from_signal(
        x=x,
        config=config,
        output_path="rom_chirp.mif",
        normalize=False,
    )

    plot_time_domain(x_norm, config.sample_rate, title="Chirp linear", samples=256)

    freqs, X, mag, mag_db = compute_fft_reference(x_norm, config.sample_rate, window="hann")
    freqs, X, mag, mag_db = positive_spectrum(freqs, X, mag, mag_db)
    plot_spectrum(freqs, mag, mag_db, title_prefix="FFT esperada - chirp")


def example_validation_from_capture():
    """
    Exemplo de validação a partir de um CSV capturado no Analog Discovery.
    Ajuste:
      - delimiter
      - skip_header
      - colunas
    conforme o arquivo exportado por você.
    """
    config = RomConfig(
        depth=1024,
        data_width=16,
        signed=True,
        sample_rate=48_000.0,
    )

    k = 32
    f0 = k * config.sample_rate / config.depth
    x_expected = sine_wave(config.depth, config.sample_rate, f0=f0, amplitude=0.9)

    # Exemplo: CSV com duas colunas: tempo, valor
    # t_meas, x_measured = load_capture_csv(
    #     "captura_analog_discovery.csv",
    #     delimiter=",",
    #     skip_header=1,
    #     time_col=0,
    #     value_col=1,
    # )

    # Para demonstração sem arquivo real:
    rng = np.random.default_rng(123)
    x_measured = x_expected + 0.01 * rng.standard_normal(len(x_expected))

    results = validate_fft_from_time_capture(
        x_expected=x_expected,
        x_measured=x_measured,
        fs=config.sample_rate,
        window=None,
        ignore_dc=True,
    )

    print("=== Métricas de validação ===")
    for key, value in results.items():
        if isinstance(value, (float, int, np.floating, np.integer)):
            print(f"{key}: {value}")

    plot_validation_results(results, title="FFT esperada vs medida")


if __name__ == "__main__":
    example_single_tone()
    example_multi_tone()
    example_square()
    example_impulse()
    example_chirp()
    example_validation_from_capture()