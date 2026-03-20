# ACES

ACES is an FPGA-oriented audio capture and spectral analysis pipeline built around an I2S microphone frontend, deterministic stimulus generation, and a radix-2 FFT backend. The repository combines SystemVerilog RTL, self-checking testbenches, and Python tooling so the same signal can be generated, injected at the pin level, observed through the hardware data path, and validated against a software FFT reference.

---

## 1. Project Overview

### Purpose

ACES exists to solve a specific validation problem: verify an end-to-end audio DSP chain from microphone-style I/O pins through FFT output bins, without depending exclusively on live acoustic input. The design supports both real microphone acquisition and synthetic stimulus playback, making it suitable for:

- hardware validation on FPGA boards,
- deterministic regression tests,
- DSP experimentation with controlled inputs,
- FFT integration/debug with known reference spectra, and
- future serial streaming of FFT results.

### Core Capabilities

- I2S reception for an INMP441-style microphone interface.
- Reconstruction of signed 24-bit mono samples from serial data.
- Sign-preserving truncation from 24-bit audio to the FFT input width of 18 bits.
- Sample delivery into the FFT ingest stream using exact one-cycle valid pulses.
- FFT execution control driven by the core input buffer status.
- DMA-style readout of FFT bins for downstream transport or logging.
- Pin-level I2S stimulus generation from ROM-stored examples.
- Python-based signal generation, ROM export, plotting, and FPGA-vs-NumPy comparison.

### Repository Layout

| Path | Role |
| --- | --- |
| `src/hdl/integration/` | Main RTL modules for acquisition, FFT integration, stimulus, and top-level assembly. |
| `tb/` | Self-checking SystemVerilog testbenches for unit, integration, and full-system validation. |
| `utils/` | Python utilities for ROM generation, waveform creation, plotting, and FFT comparison. |
| `aces.sv` | Alternate top-level assembly present at repository root. |

### End-to-End Dataflow

```text
         +---------------------+      +---------------------------+
         | INMP441 Mic or ROM  |      | Python Signal Toolchain   |
         | I2S Stimulus Source |<-----| MIF/HEX + Reference FFT   |
         +----------+----------+      +---------------------------+
                    |
                    | SCK / WS / SD
                    v
          +-----------------------+
          | i2s_rx_adapter_24     |
          | 24-bit sample rebuild |
          +-----------+-----------+
                      |
                      v
          +-----------------------+
          | sample_width_adapter  |
          | 24-bit -> 18-bit      |
          +-----------+-----------+
                      |
                      v
          +-----------------------+
          | CDC / ingest pulse    |
          | sample -> sact stream |
          +-----------+-----------+
                      |
                      v
          +-----------------------+
          | r2fft_tribuf_impl     |
          | FFT core + buffering  |
          +-----------+-----------+
                      |
                      v
          +-----------------------+
          | fft_dma_reader        |
          | bin-by-bin readout    |
          +-----------+-----------+
                      |
                      v
          +-----------------------+
          | CSV / future serial   |
          | validation interface  |
          +-----------------------+
```

---

## 2. Architecture

### 2.1 Pipeline Partitioning

ACES is intentionally split into small modules with narrow responsibilities:

1. **I2S frontend**: sample serial microphone data.
2. **Signal conditioning**: adapt width for the FFT datapath.
3. **Clock-domain crossing / pulse generation**: present samples to the system clock domain.
4. **FFT ingest**: assert a one-cycle strobe when a new sample is available.
5. **FFT control**: start transform processing when the input buffer is full.
6. **DMA readout**: extract FFT bins sequentially after completion.
7. **Stimulus subsystem**: replace the microphone with deterministic I2S traffic.
8. **Python tooling**: create stimuli and validate measured results.

This separation is not cosmetic. It makes timing, debugging, and verification easier because each boundary has explicit contracts.

### 2.2 Top-Level Assembly

The main integrated hardware module is `src/hdl/integration/aces.sv`. It:

- generates I2S clocks internally,
- drives microphone control pins,
- instantiates the audio-to-FFT pipeline,
- starts the FFT via `fft_control`, and
- streams FFT bins through `fft_dma_reader`.

For board-level and hardware-aligned validation, `src/hdl/integration/top_level_test.sv` wraps `aces` together with the ROM-backed I2S stimulus manager.

### 2.3 Clocking Relationships

The design uses two timing domains conceptually:

- **I2S serial timing**: `mic_sck_o` / `mic_ws_o` govern bit-level capture and stimulus generation.
- **System timing**: `clk` drives FFT-side registers, control, DMA readout, and most verification logic.

The integrated `aces_audio_to_fft_pipeline` currently samples `sample_valid_18` into the system clock domain and derives a pulse there. A dedicated module, `sample_bridge_to_fft_clk`, also exists in the repository to implement a toggle-based event transfer for explicit CDC-oriented validation. Use the dedicated bridge when the source and destination clocks are truly asynchronous and you need a clearer CDC contract.

### 2.4 Critical Design Decisions

#### Mono-left capture
Only the left I2S slot is used for sample capture. This matches the repository’s receive logic and keeps the FFT input path deterministic.

#### 24-bit to 18-bit adaptation
The FFT datapath width is smaller than the raw microphone width. ACES uses:

```text
sample_18 = sample_24[23:6]
```

This is a sign-preserving truncation: the sign bit is retained, the six least significant bits are discarded, and no rounding stage is inserted.

#### One-cycle streaming protocol
The FFT interprets every clock where `sact_istream` is high as a new sample. Therefore:

- pulses must be exactly one clock cycle wide,
- no duplicate pulse may be emitted for one source sample,
- data must already be stable when the pulse is asserted.

#### Continuous ingestion philosophy
The FFT-side control logic is written around the core’s input buffer status rather than a stop-and-go framing protocol at the microphone interface. Samples continue to be gathered while the system tracks when the FFT input side reaches the full-buffer state.

#### Block floating-point correction
The FFT produces a block floating-point exponent `bfpexp`. External validation must reconstruct the true scaled FFT sample as:

```text
X_corrected = (real + j * imag) * 2^fftBfpExp
```

Any comparison against NumPy that ignores `bfpexp` will be numerically misleading.

---

## 3. Module Documentation

### 3.1 `i2s_master_clock_gen`

**Purpose**

Generates the serial bit clock (`SCK`) and word select (`WS`) used by the microphone interface and the stimulus manager when the top-level runs autonomously.

**Behavior**

- Divides the main clock by `CLOCK_DIV` to create the serial bit clock.
- Advances a 64-bit frame structure consistent with two 32-bit channel slots.
- Toggles `WS` so that one half-frame represents one channel slot.

**Key invariants**

- 32 SCK cycles per channel slot.
- 64 SCK cycles per stereo frame.
- The receive and stimulus logic assume this framing.

### 3.2 `i2s_rx_adapter_24`

**Purpose**

Reconstructs a signed 24-bit sample from I2S serial data. It is the first digital stage after the microphone pins.

**Inputs / outputs**

| Signal | Dir | Description |
| --- | --- | --- |
| `sck_i` | in | I2S bit clock. Sampling occurs on the rising edge. |
| `ws_i` | in | Word select; left channel starts on `1 -> 0`. |
| `sd_i` | in | Serial data bitstream. |
| `sample_24_o` | out | Reconstructed signed 24-bit sample. |
| `sample_valid_o` | out | One `sck_i`-cycle pulse when a full sample is assembled. |

**Internal behavior**

- Detects left-channel start at `WS: 1 -> 0`.
- Discards the first bit clock after the transition to account for the I2S one-bit delay.
- Shifts in 24 bits MSB-first.
- Asserts `sample_valid_o` when the last bit is received.

**Timing summary**

```text
WS:   1 1 1 1 | 0 0 0 0 ...
SCK: _/\_/\_/\_/\_/\_/\_/\_
SD:    x delay  b23 b22 ... b0
                 ^ sample on rising edge
```

**Key invariants**

- Capture starts only on the left slot.
- Exactly one I2S delay bit is skipped.
- `sample_valid_o` is cleared by default every `sck_i` cycle and only pulses when the 24th bit lands.

### 3.3 `sample_width_adapter_24_to_18`

**Purpose**

Maps the 24-bit frontend sample into the FFT input width.

**Operation**

```text
sample_18_o = sample_24_i[23:6]
valid_18_o  = valid_24_i
```

**Design rationale**

- Keeps the sign bit.
- Matches the configured FFT datapath width.
- Avoids extra arithmetic, latency, and rounding ambiguity.

**Invariant**

If `sample_24_i` is in two’s complement, `sample_18_o` remains a valid two’s complement representation of the truncated value.

### 3.4 `sample_bridge_to_fft_clk`

**Purpose**

Provides an explicit CDC bridge from the I2S sample event domain to the system clock domain.

**Internal behavior**

- Stores the most recent sample in the source clock domain.
- Toggles an event flag whenever `sample_valid_i` arrives.
- Synchronizes the toggle through three destination-domain flip-flops.
- Emits a one-cycle `fft_sample_valid_o` pulse when an edge is detected.

**When to use it**

Use this module when the I2S clock and FFT/system clock are asynchronous and the CDC boundary should be explicit in the RTL and testbench.

**Invariant**

Each source event produces at most one destination-domain pulse.

### 3.5 `aces_fft_ingest`

**Purpose**

Converts a valid sample in the system clock domain into the exact streaming handshake expected by the FFT core.

**Outputs**

| Signal | Meaning |
| --- | --- |
| `sact_istream_o` | One-cycle “new sample” pulse. |
| `sdw_istream_real_o` | Real FFT input sample. |
| `sdw_istream_imag_o` | Imaginary FFT input sample, fixed to zero. |

**Invariant**

`sdw_istream_imag_o` is always zero because the frontend injects purely real samples.

### 3.6 `aces_audio_to_fft_pipeline`

**Purpose**

Packages the frontend path from microphone pins to FFT ingest-ready signals.

**Composition**

- `i2s_rx_adapter_24`
- `sample_width_adapter_24_to_18`
- System-clock register stage
- One-cycle pulse generator for `sact_istream_o`

**Behavioral notes**

- Stores the latest 18-bit sample in `sample_reg` when valid.
- Delays the valid bit by one system clock in `valid_d`.
- Generates `valid_pulse = valid_reg & ~valid_d`.
- Exposes debug taps for both 24-bit and 18-bit sample views.

**Contract with the FFT**

- `sact_istream_o` must only pulse once per sample.
- `sdw_istream_real_o` must contain the corresponding `sample_reg` value.
- `sdw_istream_imag_o` must remain zero.

### 3.7 `fft_control`

**Purpose**

Starts FFT execution when the FFT core indicates its input buffer is full.

**Behavior**

The controller uses a small FSM:

- `FFT_IDLE`: wait for sample activity.
- `FFT_ISTREAM`: input samples are being accepted.
- `FFT_FULL`: assert `run` once the status code indicates a full buffer.

**Important note**

The module assumes the FFT core status code `2'h2` means “full input buffer”. Any replacement FFT core must preserve or adapt this meaning.

### 3.8 `fft_dma_reader`

**Purpose**

Reads completed FFT bins through the core’s DMA-style output interface and repackages them as a sequential transmit stream.

**Operation**

1. Wait for `done_i`.
2. Issue address `0` with `dmaact_o` asserted.
3. Wait `READ_LATENCY` cycles.
4. Capture `dmadr_real_i` / `dmadr_imag_i`.
5. Increment address and repeat until the last bin.

**Outputs**

| Signal | Meaning |
| --- | --- |
| `fft_bin_valid_o` | Current output bin is valid. |
| `fft_bin_index_o` | Bin number. |
| `fft_bin_real_o` | Real component. |
| `fft_bin_imag_o` | Imaginary component. |
| `fft_bin_last_o` | Marks the final bin of the FFT frame. |

**Invariant**

`fft_bin_last_o` is asserted only when `addr == FFT_LENGTH-1`.

### 3.9 `aces`

**Purpose**

Main integration module for the deployable DSP chain.

**Responsibilities**

- Own the microphone-facing pins.
- Generate I2S clocks.
- Convert microphone data into FFT input traffic.
- Start the FFT core at the correct time.
- Read out FFT bins for external transport.
- Provide extensive debug visibility.

**Notable outputs**

The module intentionally exports many internal signals (`sample_24_dbg_o`, `fft_sample_o`, `sact_istream_o`, `bfpexp_o`, FFT DMA outputs) so the full chain can be observed in simulation and on hardware.

### 3.10 `i2s_stimulus_manager`

**Purpose**

Emulates an INMP441-like source at the pin level using ROM data supplied externally.

**Key features**

- Can use external `SCK`/`WS` or generate them internally.
- Waits for a startup interval after `chipen_i` rises.
- Reads one sample from ROM and serializes it into the active channel slot.
- Supports looping and target-channel selection.

**Serialization format**

Within the active half-frame:

- bit 0: I2S delay bit = `0`
- bits 1..24: sample `[23:0]`, MSB-first
- bits 25..31: zero padding

Inactive slot behavior is zero or high-impedance in simulation depending on configuration.

### 3.11 `i2s_stimulus_manager_rom`

**Purpose**

Combines ROM addressing and example-selection logic with the I2S stimulus concept so multiple waveforms can be stored in one memory image.

**Example addressing**

For `N_POINTS` samples per example:

```text
example 0 -> addresses [0, N_POINTS-1]
example 1 -> addresses [N_POINTS, 2*N_POINTS-1]
...
```

**Loop modes**

- `00`: play once
- `01`: loop selected example
- `10`: loop across all examples starting from selected example
- `11`: reserved, treated like example loop

### 3.12 `top_level_test`

**Purpose**

Board-oriented integration wrapper that instantiates `aces` and the ROM-based I2S stimulus manager together.

**Use case**

This is the practical “lab validation” top level:

- switches select stimulus start/example/loop mode,
- seven-segment displays expose debug values,
- LEDs expose I2S state,
- GPIO can carry the microphone-equivalent and future serial signals.

---

## 4. I2S Protocol Explanation

### 4.1 Timing Model Used in ACES

ACES follows the standard I2S framing used by the INMP441-style source model in this repository:

- `SCK` is the serial bit clock.
- `WS` selects channel slot.
- Data is sampled on the **rising edge** of `SCK`.
- The first bit clock after a `WS` transition is the I2S alignment delay and is not part of the payload.
- Each channel occupies **32 bit clocks**.

### 4.2 Channel Semantics

The receiver captures the **left** channel only:

- left-slot start is identified by `WS: 1 -> 0`,
- the next bit time is discarded,
- the following 24 bits are payload.

This mono-left policy must match the stimulus manager configuration and microphone wiring.

### 4.3 Frame-Level View

```text
Right slot (32 clocks)                Left slot (32 clocks)
WS = 1                                WS = 0
+------------------------------+      +------------------------------+
|  unused by RX                |      | delay | 24 payload | padding |
+------------------------------+      +------------------------------+
```

### 4.4 Why 32 Clocks per Channel?

The microphone payload is only 24 bits, but the I2S frame reserves 32 clock periods per channel. ACES uses the remaining 8 bit times for the mandatory one-bit alignment delay plus zero padding.

---

## 5. FFT Integration

### 5.1 How Samples Enter the FFT

The FFT sees three relevant input signals:

- `sact_istream`: sample strobe,
- `sdw_istream_real`: real sample data,
- `sdw_istream_imag`: imaginary sample data.

ACES drives the imaginary lane with zero and pulses `sact_istream` for one system clock whenever a fresh real-valued sample is available.

### 5.2 Why Pulse Width Matters

The FFT core treats **every asserted `sact_istream` cycle as a new input sample**. If `sact_istream` remains high for two clocks, the same sample may be counted twice. If a pulse is missed, a sample is dropped. This is one of the central correctness constraints of the entire design.

### 5.3 Run Control

`fft_control` watches `input_buffer_status_o` from the FFT core. When the status indicates a full input buffer, the controller asserts `run`, allowing the FFT to process the captured frame.

### 5.4 DMA Result Readout

After `done_o`, the readout block sequentially walks all FFT addresses and emits one valid output record per bin. This repackages the FFT core’s internal memory/DMA port into a transport-friendly stream.

### 5.5 Block Floating Point Exponent (`bfpexp`)

The FFT core exports a scaling exponent. Any downstream software that compares raw FPGA bins to a floating-point reference must apply this exponent.

Recommended correction formula:

```python
X_corrected = (real + 1j * imag) * (2 ** fftBfpExp)
```

Without this correction, apparent gain errors are expected even when the FFT itself is functioning properly.

---

## 6. Stimulus System

### 6.1 Why the Stimulus Path Exists

The stimulus subsystem makes the project deterministic. Instead of speaking into a microphone and hoping the same spectrum reappears, the design injects exact sample sequences onto `SCK`, `WS`, and `SD` as if a microphone were transmitting them.

### 6.2 ROM Organization

The ROM-backed manager stores multiple examples in one linear address space.

If `N_POINTS = 512` and `N_EXAMPLES = 8`, then total storage is:

```text
TOTAL_SAMPLES = N_POINTS * N_EXAMPLES = 4096
```

Address mapping:

```text
example e, sample k -> address = e * N_POINTS + k
```

### 6.3 Stimulus Manager State Flow

The ROM-backed stimulus manager broadly follows this sequence:

1. Wait for `start_i`.
2. Wait until the simulated microphone startup window has elapsed.
3. Prime the ROM address.
4. Wait for ROM data latency.
5. Wait for the target I2S half-frame.
6. Shift the sample onto `sd_o` bit-by-bit.
7. Advance the point/example index according to loop mode.

### 6.4 Active vs Inactive Slot Behavior

During the selected channel slot, the stimulus manager drives serial data. During the inactive slot, simulation can intentionally show high impedance (`Z`) to make incorrect channel usage visible in the waveform viewer.

### 6.5 Hardware Validation Topology

`top_level_test` wires the stimulus output directly into the ACES microphone input path. This gives a realistic validation setup because the receiver still sees physical I2S pins rather than an abstract sample bus.

---

## 7. Python Tooling

The repository includes two Python utilities with different levels of abstraction.

### 7.1 `utils/signal_rom_generator.py`

This is the richer workflow-oriented utility. It provides:

- configuration via `SignalRomConfig`,
- waveform generation via `SignalFactory`,
- WAV import,
- MIF/HEX export,
- time-domain and FFT plotting,
- FPGA CSV ingestion and comparison.

#### Supported waveform families

- sine / cosine
- square
- sawtooth / triangle
- impulse
- DC
- multi-tone compositions
- WAV-derived examples

#### Typical workflow

1. Define the ROM/export configuration.
2. Create one or more examples.
3. Quantize and export to MIF or HEX.
4. Simulate `top_level_test` or the relevant testbench.
5. Capture FFT output CSV from the testbench.
6. Reconstruct the FFT scale using `fftBfpExp`.
7. Compare against NumPy FFT.

#### Example usage

```python
from pathlib import Path
from utils.signal_rom_generator import SignalRomConfig, SignalFactory, OutputFormat

cfg = (SignalRomConfig()
       .with_n_points(512)
       .with_sample_bits(24)
       .with_sample_rate_hz(48_828)
       .with_output_format(OutputFormat.MIF)
       .with_output_dir(Path("build_rom"))
       .with_output_basename("signals_rom"))

factory = SignalFactory(cfg)
example = factory.sine(freq_hz=1000.0, amplitude=0.8, name="tone_1k")
```

### 7.2 `utils/function_generator_rom.py`

This is a lower-level utility focused on numerical helpers and direct waveform-to-ROM conversion.

Capabilities include:

- signal normalization,
- signed quantization,
- two’s complement conversion,
- FFT reference generation,
- MIF writing,
- plotting helpers.

### 7.3 CSV Validation Concept

The hardware-aligned testbench writes FFT output CSV with fields such as:

```text
index,real,imag,last,fftBfpExp
```

Software validation should:

1. parse the bins,
2. build `real + j*imag`,
3. apply `2^fftBfpExp`,
4. compare against `numpy.fft.fft()` of the original stimulus window.

### 7.4 Practical Validation Advice

When comparing software and hardware spectra, make sure the following match exactly:

- sample count (`N_POINTS` / `FFT_LENGTH`),
- sample rate,
- channel selection,
- truncation from 24-bit to 18-bit,
- windowing policy in Python, and
- block floating-point correction.

---

## 8. Simulation Guide

### 8.1 Verification Layers in the Repository

#### Unit tests

- `tb/tb_i2s_rx_adapter_24.sv`
- `tb/tb_sample_width_adapter_24_to_18.sv`
- `tb/tb_sample_bridge_and_ingest.sv`

These validate protocol decoding, arithmetic truncation, CDC/injest pulse behavior, and key invariants.

#### Integration tests

- `tb/tb_aces.sv`
- `tb/tb_i2s_stimulus_manager.sv`
- `tb/tb_i2s_stimulus_manager_rom.sv`

These validate the assembled audio frontend and stimulus machinery.

#### Full-system / hardware-aligned test

- `tb/tb_top_level_test_real.sv`

This testbench records frontend samples and FFT output bins to CSV files for offline Python validation.

### 8.2 Recommended Questa Flow

A typical Questa flow is:

```text
1. Compile Quartus-generated IP simulation models and libraries.
2. Compile ACES RTL.
3. Compile the target testbench.
4. Launch simulation.
5. Inspect waveforms and generated CSV artifacts.
```

An example command sequence will vary with your Quartus installation, but the structure is typically:

```bash
vlib work
vmap work work
vlog <quartus_ip_models_and_libs>
vlog src/hdl/integration/*.sv tb/tb_top_level_test_real.sv
vsim -c tb_top_level_test_real -do "run -all; quit"
```

### 8.3 Quartus IP Considerations

The full system may depend on real Quartus-generated models for:

- ROM IP,
- FFT core,
- vendor-specific memory behavior.

Make sure your simulation project includes:

- the correct generated `.vo` / `.sv` / library files,
- any Altera/Intel primitive libraries required by the generated IP,
- timing-consistent ROM latency assumptions.

### 8.4 Common Pitfalls

| Pitfall | Consequence | Mitigation |
| --- | --- | --- |
| Missing Quartus libraries | Compilation or elaboration failure | Add the vendor simulation libraries before compiling testbenches. |
| Wrong ROM latency assumption | Shifted or invalid stimulus samples | Match the ROM pipeline stages used by the testbench/stimulus manager. |
| Ignoring `bfpexp` | FFT amplitude mismatch | Apply block-floating correction in Python. |
| Multi-cycle `sact_istream` | Duplicate FFT inputs | Check pulse-width assertions in ingest-related tests. |
| Wrong `WS` polarity assumption | Captured wrong channel | Confirm left-slot selection and waveform alignment. |
| Using full 24-bit reference against 18-bit FFT input | False mismatch | Truncate or quantize the software reference consistently. |

### 8.5 Output Files from Full-System Simulation

`tb_top_level_test_real.sv` writes:

- `frontend_samples.csv`
- `fft_tx_output.csv`

These files are the bridge between RTL simulation and Python post-processing.

---

## 9. Validation Methodology

### 9.1 What Is Being Verified?

ACES verification is not limited to “does the FFT produce some output.” The methodology covers:

- pin-level I2S correctness,
- sample reconstruction correctness,
- numeric truncation correctness,
- pulse timing correctness,
- FFT control sequencing,
- DMA readout sequencing,
- numerical agreement with software reference FFTs.

### 9.2 Assertion Themes Used by the Testbenches

The existing testbenches focus on four categories of checks:

1. **Functional correctness**
   - Sample values match expected ROM/test vectors.
2. **Temporal correctness**
   - Valid strobes occur in the correct cycles.
3. **Pulse width correctness**
   - `sact_istream` must never remain high for consecutive cycles.
4. **Sequencing correctness**
   - FFT bins must appear in order and `last` must only assert on the final bin.

### 9.3 Reference Comparison Strategy

For a deterministic example:

1. Generate a known signal in Python.
2. Export it to the ROM format used by the stimulus manager.
3. Run the full-system simulation.
4. Load `frontend_samples.csv` to confirm the frontend reconstructed the intended samples.
5. Load `fft_tx_output.csv` and apply `bfpexp` correction.
6. Compute the NumPy FFT of the same truncated input vector.
7. Compare magnitude, phase, and bin ordering.

### 9.4 Frontend-vs-FFT Debug Split

If the final FFT comparison fails, debug in this order:

1. **Frontend reconstruction**: verify `sample_24_dbg_o` and `sample_mic_o`.
2. **Ingest pulse protocol**: verify `fft_sample_valid_o`, `sact_istream_o`, and sample stability.
3. **FFT run sequencing**: verify `fft_input_buffer_status_o`, `fft_run_o`, `fft_done_o`.
4. **DMA output**: verify address walk and final-bin marking.
5. **Python reconstruction**: verify `bfpexp` handling and quantization assumptions.

This staged approach prevents wasting time debugging the FFT when the issue is really in the serial frontend or validation script.

---

## 10. Engineering Notes for Extension

### 10.1 Adding New Signals to the ROM Library

To add a new example:

1. Generate the signal in Python.
2. Quantize to signed 24-bit.
3. Export into the ROM image at a known example index.
4. Update the simulation or board switch selection to target that example.
5. Re-run the full validation path.

### 10.2 Replacing the FFT Core

If `r2fft_tribuf_impl` is replaced, review at minimum:

- input handshake semantics,
- `run` timing,
- buffer status encoding,
- DMA latency and address protocol,
- output scaling / `bfpexp` behavior.

### 10.3 Real Hardware Bring-Up

For live microphone use instead of synthetic ROM playback:

- disconnect or bypass the I2S stimulus manager,
- keep the same receive and width-adaptation path,
- verify actual microphone `WS` polarity and startup behavior,
- capture FFT bins through the future serial/debug interface.

---

## 11. Future Work

### Serial transmission module

The current output interface is already shaped for a downstream serial transport block. A natural next step is a UART, SPI, or higher-speed streaming module that consumes `fft_tx_*` and emits bins off-chip.

### Real hardware integration

The repository already contains the hooks for board-level validation. Extending this to a production-like top level would involve stable pin assignments, clock/reset conditioning, and a host-side capture utility.

### Spectrogram generation

Once continuous frame acquisition and export are stable, the same FFT pipeline can be used to build a spectrogram system by collecting consecutive frames and plotting magnitude over time.

### Stronger CDC formalization

The repository already includes a dedicated sample bridge module. Future revisions could make that bridge the default integration path, followed by formal CDC analysis or dedicated asynchronous test scenarios.

---

## 12. Recommended New-Engineer Workflow

1. Read the `aces` and `aces_audio_to_fft_pipeline` modules first.
2. Study `i2s_rx_adapter_24` to understand the exact serial timing assumptions.
3. Run the unit tests before touching the integrated design.
4. Run `tb_top_level_test_real.sv` and inspect the generated CSVs.
5. Use the Python tooling to reproduce the FFT numerically.
6. Only after the deterministic path is understood, move to live microphone capture.

This order minimizes ambiguity and builds confidence in each layer of the stack.
