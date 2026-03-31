# ACES Overview

## What ACES Is

ACES is an FPGA-oriented audio capture and spectral-analysis platform implemented in SystemVerilog with Python support utilities. The repository is organized so engineers can exercise the same signal path in multiple modes:

- from a real or emulated I2S microphone source,
- through deterministic sample conditioning and FFT ingestion,
- into either mock or real-IP-oriented FFT simulation flows,
- and out through a DMA-style FFT readout path intended for validation and future transport layers.

ACES is not just an RTL dump. It is structured as a reproducible hardware verification workspace with versioned simulation manifests, testbenches, wave setups, and a portable packaging flow for Questa users.

## Problems the Project Solves

ACES addresses a common FPGA DSP validation problem: proving that an audio processing pipeline works correctly before depending on live hardware input or vendor-IP-specific lab setups.

In practical terms, the repository helps engineers:

- validate I2S sample reconstruction from an INMP441-style interface,
- prove that 24-bit microphone data is adapted correctly to the FFT input width,
- verify clock-domain-crossing and ingest behavior under deterministic stimulus,
- exercise FFT control and FFT-output extraction logic without requiring board bring-up,
- compare hardware-oriented FFT results against software-generated references, and
- hand simulation packages to collaborators without asking them to reverse-engineer the repo layout.

## Key Features

- Structured RTL under `rtl/common`, `rtl/frontend`, `rtl/stimulus`, `rtl/core`, and `rtl/ip/`.
- Modular pipeline stages with consistent handshake (valid/ready/overflow) for clean producer-consumer decoupling.
- Integrated I2S TX with BFPEXP-tagged FFT output framing (enables real-time spectral analysis transport).
- Explicit bridge FIFO (`fft_tx_bridge_fifo`) decoupling FFT burst output from I2S serial rate.
- Unit, integration, and mock simulation assets separated under `tb/`.
- A versioned Questa-oriented simulation manifest under `sim/manifest/`.
- Portable packaging flow that produces a redistributable Questa package under `sim/portable/`.
- A maintained Raspberry Pi-side FFT receiver and analysis package under `submodules/ACES-RPi-interface/`.
- Offline Python regression for the host-side protocol/parser path without requiring live hardware.
- Explicit separation between:
  - **manifest**: versioned source of truth,
  - **local**: machine-specific generated outputs,
  - **portable**: generated redistribution artifact.
- Python support scripts and generated ROM/FFT collateral for stimulus generation and validation.

## High-Level Pipeline

```text
I2S mic pins / ROM-backed stimulus
              |
              v
      i2s_rx_adapter_24
              |
              v
 sample_width_adapter_24_to_18
              |
              v
   sample bridge / ingest logic
              |
              v
        FFT integration path
              |
              v
       fft_dma_reader output
              |
              v
    fft_tx_bridge_fifo (explicit decoupling)
              |
              v
  i2s_fft_tx_adapter (tagged TX framing)
              |
              v
    I2S GPIO pins (SCK, WS, SD) / DMA validation path
              |
              v
  ACES-RPi-interface host receiver and offline regression
```

## Intended Use Cases

### FPGA validation
Use ACES when you want to validate the end-to-end microphone-to-FFT data path before or alongside board-level debug.

### DSP experimentation
Use ROM-backed deterministic inputs to inject known signals and observe how FFT-side logic responds.

### Verification bring-up
Use the mock flow to bring up control logic, testbench structure, and waveform review without depending on vendor libraries or external FFT collateral.

### Real-IP-oriented simulation
Use the real-IP-oriented flow when you want to keep the repository’s RTL/testbench structure while binding the real Quartus ROM wrapper and the checked-in `submodules/R2FFT` implementation.

### Spectral output validation
Use the integrated I2S TX path (bridge FIFO → TX adapter → GPIO outputs) to export tagged FFT bins in real time, validate serialization logic, and verify that BFPEXP metadata is correctly framed alongside spectral data.

### Host-side integration and validation
Use `submodules/ACES-RPi-interface/rpi3b_i2s_fft/` when you want a maintained consumer for the FPGA FFT stream, including offline parser regression before board bring-up.

### Onboarding and AI-assisted maintenance
Use the repository layout and docs suite to understand where active RTL lives, which tests are meant to run, and where generated simulator artifacts should be kept. The modular pipeline architecture and explicit design invariants support automated codebase exploration and refactoring.

## Where to Go Next

- See [current_state.md](current_state.md) for the consolidated rationale behind the current repository organization and workflow.
- See [architecture.md](architecture.md) for the detailed pipeline structure and design invariants.
- See [repository_structure.md](repository_structure.md) for how the repo is organized.
- See [simulation.md](simulation.md) for the day-to-day Questa workflow.
- See [portable_flow.md](portable_flow.md) for handoff/package guidance.
