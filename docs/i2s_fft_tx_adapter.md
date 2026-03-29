# I2S FFT TX Adapter

## Purpose

`i2s_fft_tx_adapter` is the transmit-side bridge between the FFT output stream and an external consumer that reads data through an I2S-style serial link, such as a Raspberry Pi connected to FPGA GPIO pins.

The block is intended to be synthesizable and to let the FFT run at its own rate while the serial link drains data at a slower rate.

## Module location

- `rtl/frontend/i2s_fft_tx_adapter.sv`
- `rtl/common/fft_tx_bridge_fifo.sv`
- `rtl/core/aces.sv`
- `tb/unit/tb_i2s_fft_tx_adapter.sv`

## What the module receives

For each FFT bin, the module accepts:

- `fft_valid_i`: marks a valid FFT bin
- `fft_real_i`: real part of the bin
- `fft_imag_i`: imaginary part of the bin
- `fft_last_i`: marks the last bin of the current FFT window
- `bfpexp_i`: block-floating exponent associated with the current FFT window

In the active ACES integration, these fields come from `fft_tx_bridge_fifo`, not directly from `fft_dma_reader`.

The intended contract is:

1. `bfpexp_i` is sampled together with the first valid bin of each window.
2. `fft_last_i` is asserted on the last valid bin of that same window.
3. Bins arrive in window order and are not reordered inside the module.

## What the module transmits

The serializer emits an I2S frame with two channels:

- left channel: real part
- right channel: imaginary part

At the start of every new FFT window, the module inserts a special frame carrying `bfpexp_i` in both channels before the FFT bins of that window.

That exponent frame is not sent just once. It is repeated for `BFPEXP_HOLD_FRAMES` complete I2S frames so the external reader has enough time to detect and sample it.

Type information is carried in-band for every transmitted word using a 2-bit tag:

- `0 = idle`
- `1 = bfpexp`
- `2 = fft`

This removes the need for an external type flag pin; software can decode type directly from each I2S word.

## I2S word format

Each channel slot has `I2S_SLOT_W` bits.

Inside that slot, the transmitted word is:

```text
[2-bit tag][reserved zero bits][I2S_SAMPLE_W signed payload bits]
```

So, with the default parameters:

- `I2S_SLOT_W = 32`
- `I2S_SAMPLE_W = 18`

the slot becomes:

```text
bits 31:30: type tag
bits 29:18: reserved zeros
bits 17:0: signed payload
```

The payload is transmitted MSB-first.

## FIFO behavior

The implementation currently has two FIFO stages:

- bridge FIFO (`fft_tx_bridge_fifo`) in `aces.sv` between FFT DMA readout and TX adapter,
- adapter FIFO inside `i2s_fft_tx_adapter` used by the serializer/tagger.

This two-stage buffering decouples the producer side and serial-consumer side:

- FFT DMA readout can burst data quickly,
- the I2S output drains data at its own slower clock rate.

The bridge FIFO default depth is `2048`, which stores four full 512-bin windows when each entry carries `(real, imag, last, bfpexp)` together.

### FIFO entry types

There are two logical entry types:

1. `bfpexp` entry
2. FFT data entry

A `bfpexp` entry contains:

- `left = bfpexp`
- `right = bfpexp`
- internal `tag = 1`

A data entry contains:

- `left = fft_real`
- `right = fft_imag`
- internal `tag = 2`

## Window handling

The module tracks whether it is currently inside an FFT window.

When the first bin of a new window arrives:

1. it pushes one `bfpexp` entry into the FIFO
2. it pushes the first FFT bin into the FIFO

For subsequent bins of the same window:

1. it pushes only FFT data entries

When `fft_last_i` arrives:

1. the current input window is closed
2. the next valid bin will start a new window and therefore insert a new `bfpexp`

## Overflow policy

If the FIFO runs out of space in the middle of a window, the module does not try to keep a partial window.

Instead:

1. `overflow_o` is asserted
2. the rest of the current window is discarded until `fft_last_i`
3. normal acceptance resumes only at the start of the next window

This policy avoids corrupt output sequences such as:

- exponent from one window mixed with bins from another
- incomplete window payloads that look valid to software

## Handshake behavior

The input-side flow control signal is:

- `fft_ready_o`

`fft_ready_o` goes low when:

- the module is intentionally dropping the rest of an overflowed window
- there is not enough FIFO space for the next required insertion

The required FIFO space is:

- 2 entries at the first bin of a new window
- 1 entry for every other bin in the same window

## Synthesizability

The RTL in `rtl/frontend/i2s_fft_tx_adapter.sv` is intended to be synthesizable:

- fixed-size memories for the FIFO
- fixed-width registers and counters
- no dynamic arrays
- no queues
- no classes
- no delays
- no testbench-only constructs in the RTL datapath

The testbench is separate and is not part of the synthesizable design.

## Default parameter meaning

- `FFT_DW`: width of `fft_real_i` and `fft_imag_i`
- `BFPEXP_W`: width of `bfpexp_i`
- `I2S_SAMPLE_W`: width of the payload placed inside each I2S slot
- `I2S_SLOT_W`: total bits per channel slot
- `CLOCK_DIV`: divider used to generate `i2s_sck_o` from `clk`
- `FIFO_DEPTH`: number of buffered logical entries
- `BFPEXP_HOLD_FRAMES`: number of full I2S frames used to repeat `bfpexp`

## Software-side decode rule

On the Raspberry Pi side, the simplest rule is:

1. sample each full I2S frame
2. extract the 2-bit tag from bits `31:30` of each channel word
3. if tag is `1`, interpret payload as `bfpexp`
4. if tag is `2`, interpret payload as one FFT bin:
   `left -> real`, `right -> imag`

## Verification

The unit testbench validates:

- insertion of `bfpexp` at each new window
- repetition of `bfpexp` for the programmed hold length
- correct per-frame tag values
- preservation of FFT bin ordering
- FIFO buffering while the serializer drains data
