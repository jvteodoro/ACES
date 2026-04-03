# SPI FFT TX Adapter

`spi_fft_tx_adapter` is the active physical transport block for exporting FFT windows from the FPGA to the Raspberry Pi.

## File

- `rtl/frontend/spi_fft_tx_adapter.sv`

## Purpose

It converts the FFT bin stream:

- `fft_valid_i`
- `fft_real_i`
- `fft_imag_i`
- `fft_last_i`
- `bfpexp_i`

into SPI-slave transactions while preserving the same 32-bit tagged word format already consumed by the host software.

## Transport Contract

Each 32-bit word is:

```text
[ tag(2) | reserved(12) | signed payload(18) ]
```

Tags:

- `0`: idle
- `1`: BFPEXP
- `2`: FFT

Each SPI transaction returns:

```text
bfpexp_hold_frames copies of the BFPEXP pair
then
one `(real, imag)` FFT pair per bin
```

## External Interface

- `spi_sclk_i`: SPI clock from Raspberry Pi
- `spi_cs_n_i`: chip select from Raspberry Pi
- `spi_miso_o`: serialized FPGA response
- `window_ready_o`: high when a complete FFT window is buffered

The Raspberry Pi is the SPI master. The FPGA is the SPI slave.

## Internal Buffering

The module instantiates `fft_tx_bridge_fifo` so the FFT readout path is not forced to match the SPI transaction timing exactly.

## Verification

Supported benches:

- `tb_spi_fft_tx_adapter`
- `tb_fft_tx_spi_link`
- `tb_top_level_spi_fft_tx_diag`

Related filelists:

- `sim/manifest/filelists/mock_unit_spi_fft_tx_adapter.f`
- `sim/manifest/filelists/mock_integration_fft_tx_spi_link.f`
