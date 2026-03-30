#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np

from signal_rom_generator import build_default_signal_rom_generator


I2S_CLOCK_DIV = 4
STARTUP_SCK_CYCLES = 8
RESET_CYCLES = 8
PRESTART_CYCLES = 8
MAX_SIM_CYCLES = 500_000


def to_signed(value: int, bits: int) -> int:
    mask = (1 << bits) - 1
    value &= mask
    if value & (1 << (bits - 1)):
        value -= 1 << bits
    return value


def trunc_24_to_18(values_24: np.ndarray) -> np.ndarray:
    values_24 = np.asarray(values_24, dtype=np.int64)
    return (values_24 >> 6).astype(np.int64)


@dataclass
class LoopbackResult:
    captured_samples_24: np.ndarray
    captured_samples_18: np.ndarray


def stim_sd_bit(current_sample: int, bit_index: int, ws: int, lr_sel: int = 0, chipen: int = 1) -> int:
    target_half_active = ((lr_sel == 0) and (ws == 0)) or ((lr_sel == 1) and (ws == 1))

    if not chipen:
        return 0
    if not target_half_active:
        return 0
    if bit_index == 0:
        return 0
    if 1 <= bit_index <= 24:
        return (current_sample >> (24 - bit_index)) & 0x1
    return 0


def simulate_i2s_loopback_example(example_samples_24: np.ndarray) -> np.ndarray:
    example_samples_24 = np.asarray(example_samples_24, dtype=np.int64)
    n_points = int(example_samples_24.shape[0])

    st_idle = 0
    st_wait_ready = 1
    st_prime_rom = 2
    st_wait_rom_1 = 3
    st_wait_rom_2 = 4
    st_wait_target_half = 5
    st_shift = 6

    rst = 1
    start_i = 0
    chipen_i = 1
    lr_i = 0

    div_cnt = 0
    sck = 0
    ws = 1
    frame_bit_cnt = 0

    rom_address_r = 0
    rom_q = 0

    state = st_idle
    start_d = 0
    sck_prev = 0
    ws_prev = 1
    chipen_prev = 0
    startup_count = 0
    startup_active = 1
    current_point = 0
    rom_addr_reg = 0
    current_sample = 0
    bit_index = 0

    rx_ws_prev = 0
    capturing = 0
    bit_count = 0
    shift_reg = 0

    captured: list[int] = []

    def rom_lookup(address: int) -> int:
        if 0 <= address < n_points:
            return int(example_samples_24[address])
        return 0

    for cycle_idx in range(MAX_SIM_CYCLES):
        if cycle_idx == RESET_CYCLES:
            rst = 0
        elif cycle_idx == RESET_CYCLES + PRESTART_CYCLES:
            start_i = 1
        elif cycle_idx == RESET_CYCLES + PRESTART_CYCLES + 1:
            start_i = 0

        start_pulse = int(start_i and not start_d)
        sck_rise = int(sck and not sck_prev)
        sck_fall = int((not sck) and sck_prev)
        target_half_start = int((ws_prev == 1) and (ws == 0)) if lr_i == 0 else int((ws_prev == 0) and (ws == 1))

        old_sck = sck

        if rst:
            next_div_cnt = 0
            next_sck = 0
            next_ws = 1
            next_frame_bit_cnt = 0
        else:
            next_div_cnt = div_cnt
            next_sck = sck
            next_ws = ws
            next_frame_bit_cnt = frame_bit_cnt

            if div_cnt == I2S_CLOCK_DIV - 1:
                next_div_cnt = 0
                next_sck = 0 if sck else 1

                if not sck:
                    next_frame_bit_cnt = 0 if frame_bit_cnt == 63 else frame_bit_cnt + 1
                    next_ws = 1 if frame_bit_cnt < 32 else 0
            else:
                next_div_cnt = div_cnt + 1

        next_rom_address_r = 0 if rst else int(rom_addr_reg & 0xFFF)

        if rst:
            next_start_d = 0
            next_sck_prev = 0
            next_ws_prev = 1
            next_chipen_prev = 0
        else:
            next_start_d = int(start_i)
            next_sck_prev = int(sck)
            next_ws_prev = int(ws)
            next_chipen_prev = int(chipen_i)

        if rst:
            next_startup_count = 0
            next_startup_active = 1
        else:
            next_startup_count = startup_count
            next_startup_active = startup_active

            if not chipen_i:
                next_startup_count = 0
                next_startup_active = 1
            elif (not chipen_prev) and chipen_i:
                next_startup_count = 0
                next_startup_active = 1
            elif startup_active and sck_rise:
                if startup_count == STARTUP_SCK_CYCLES - 1:
                    next_startup_active = 0
                else:
                    next_startup_count = startup_count + 1

        if rst:
            next_state = st_idle
            next_current_point = 0
            next_rom_addr_reg = 0
            next_current_sample = 0
            next_bit_index = 0
        else:
            next_state = state
            next_current_point = current_point
            next_rom_addr_reg = rom_addr_reg
            next_current_sample = current_sample
            next_bit_index = bit_index

            if state == st_idle:
                next_current_point = 0
                next_bit_index = 0

                if start_pulse and chipen_i:
                    next_current_point = 0
                    if startup_active:
                        next_state = st_wait_ready
                    else:
                        next_state = st_prime_rom

            elif state == st_wait_ready:
                if not chipen_i:
                    next_state = st_idle
                elif not startup_active:
                    next_state = st_prime_rom

            elif state == st_prime_rom:
                next_rom_addr_reg = current_point
                next_state = st_wait_rom_1

            elif state == st_wait_rom_1:
                next_state = st_wait_rom_2

            elif state == st_wait_rom_2:
                next_current_sample = rom_q
                next_bit_index = 0
                next_state = st_wait_target_half

            elif state == st_wait_target_half:
                if not chipen_i:
                    next_state = st_idle
                elif target_half_start:
                    next_bit_index = 0
                    next_state = st_shift

            elif state == st_shift:
                if not chipen_i:
                    next_state = st_idle
                elif sck_fall:
                    if bit_index == 31:
                        next_bit_index = 0
                        if current_point == n_points - 1:
                            next_state = st_idle
                        else:
                            next_current_point = current_point + 1
                            next_state = st_prime_rom
                    else:
                        next_bit_index = bit_index + 1

        div_cnt = next_div_cnt
        sck = next_sck
        ws = next_ws
        frame_bit_cnt = next_frame_bit_cnt
        rom_address_r = next_rom_address_r
        rom_q = rom_lookup(rom_address_r)
        start_d = next_start_d
        sck_prev = next_sck_prev
        ws_prev = next_ws_prev
        chipen_prev = next_chipen_prev
        startup_count = next_startup_count
        startup_active = next_startup_active
        state = next_state
        current_point = next_current_point
        rom_addr_reg = next_rom_addr_reg
        current_sample = next_current_sample
        bit_index = next_bit_index

        sd_i = stim_sd_bit(current_sample=current_sample, bit_index=bit_index, ws=ws, lr_sel=lr_i, chipen=chipen_i)

        if rst:
            rx_ws_prev = 0
            capturing = 0
            bit_count = 0
            shift_reg = 0
        elif (old_sck == 0) and (sck == 1):
            sample_valid = 0
            sample_24 = 0

            if (rx_ws_prev == 1) and (ws == 0):
                capturing = 1
                bit_count = 0
                shift_reg = 0
            elif capturing:
                if bit_count == 23:
                    sample_24 = to_signed(((shift_reg & ((1 << 23) - 1)) << 1) | sd_i, 24)
                    sample_valid = 1
                    capturing = 0
                else:
                    shift_reg = ((shift_reg & ((1 << 23) - 1)) << 1) | sd_i
                    bit_count += 1

            rx_ws_prev = ws

            if sample_valid:
                captured.append(sample_24)
                if len(captured) == n_points:
                    return np.asarray(captured, dtype=np.int64)

    raise RuntimeError(f"Loopback I2S nao convergiu apos {MAX_SIM_CYCLES} ciclos para {n_points} amostras.")


def simulate_i2s_loopback(matrix_24: np.ndarray) -> LoopbackResult:
    matrix_24 = np.asarray(matrix_24, dtype=np.int64)
    captured_24 = np.zeros_like(matrix_24)

    for example_idx in range(matrix_24.shape[0]):
        captured_24[example_idx] = simulate_i2s_loopback_example(matrix_24[example_idx])

    return LoopbackResult(
        captured_samples_24=captured_24,
        captured_samples_18=trunc_24_to_18(captured_24),
    )


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    out_dir = repo_root / "tb" / "data"
    out_dir.mkdir(parents=True, exist_ok=True)

    generator = build_default_signal_rom_generator(
        output_dir=repo_root / "tools",
        verbose=False,
        save_plots=False,
    )

    rom_matrix_24 = generator.build_int_matrix()
    loopback = simulate_i2s_loopback(rom_matrix_24)

    samples_path = out_dir / "top_level_test_expected_samples.csv"
    fft_path = out_dir / "top_level_test_expected_fft.csv"
    meta_path = out_dir / "top_level_test_expected_meta.txt"

    with samples_path.open("w", encoding="utf-8") as f:
        f.write("example_idx,sample_idx,sample24,sample18\n")
        for ex_idx in range(loopback.captured_samples_24.shape[0]):
            for sample_idx in range(loopback.captured_samples_24.shape[1]):
                f.write(
                    f"{ex_idx},{sample_idx},{int(loopback.captured_samples_24[ex_idx, sample_idx])},{int(loopback.captured_samples_18[ex_idx, sample_idx])}\n"
                )

    with fft_path.open("w", encoding="utf-8") as f:
        f.write("example_idx,bin_idx,expected_real,expected_imag\n")
        for ex_idx in range(loopback.captured_samples_18.shape[0]):
            x = loopback.captured_samples_18[ex_idx].astype(np.float64)
            X = np.fft.fft(x)
            for bin_idx, value in enumerate(X):
                f.write(
                    f"{ex_idx},{bin_idx},{float(np.real(value)):.12f},{float(np.imag(value)):.12f}\n"
                )

    cfg = generator.config
    with meta_path.open("w", encoding="utf-8") as f:
        f.write(f"n_examples={len(generator.examples)}\n")
        f.write(f"n_points={cfg.n_points}\n")
        f.write(f"fft_length={cfg.n_points}\n")
        f.write("rom_sample_bits=24\n")
        f.write("captured_sample_bits=24\n")
        f.write("fft_input_bits=18\n")
        f.write(f"sample_rate_hz={cfg.sample_rate_hz}\n")
        f.write("source=python_rom_generator_plus_rtl_i2s_loopback_model\n")
        f.write("loopback_rtl=i2s_master_clock_gen+i2s_stimulus_manager_rom+i2s_rx_adapter_24+sample_width_adapter_24_to_18\n")
        f.write(f"i2s_clock_div={I2S_CLOCK_DIV}\n")
        for idx, ex in enumerate(generator.examples):
            f.write(f"example_{idx}={ex.name}\n")

    print(samples_path)
    print(fft_path)
    print(meta_path)


if __name__ == "__main__":
    main()
