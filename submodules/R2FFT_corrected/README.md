# R2FFT corrected

This directory is a parent-repository-tracked validation fork of the original
`submodules/R2FFT` project. The original submodule is retained unchanged as a
baseline. The corrected project targets the DE10-Lite MAX 10 device and the
current application configuration (`FFT_LENGTH=1024`, `FFT_DW=18`,
`PL_DEPTH=3`).

## Corrections in this baseline

1. The six triple-buffer RAM instances are exposed through
   `r2fft_dpram`, with a 36-bit complex data port (`2*FFT_DW`) and 512 words.
   This removes the original 32-bit/36-bit truncation and undriven upper-bit
   mismatch.
2. The twiddle ROM is exposed through `r2fft_twrom`. Its coefficients remain
   16-bit Q1.15, but the integration boundary explicitly zero-extends them to
   the 18-bit R2FFT input. This preserves the source ROM numeric convention
   while removing implicit port-width conversion.
3. Counter and address-generator constants use explicit widths. These changes
   preserve the original sequences and are covered by cycle-level tests before
   being used in the board top-level.

## Validation policy

The `verification` directory contains deterministic Python vectors and a
fixed-point reference model. RTL verification is separated into:

* protocol/address tests;
* RAM and ROM timing tests;
* end-to-end FFT output comparison against the Python model;
* Quartus synthesis/fitter/timing warning review for the MAX 10 target.

Run the Python checks with:

```text
python -m unittest -v verification/test_r2fft_reference.py
```

Run the address-generator Questa test from PowerShell with:

```powershell
.\verification\run_address_test.ps1
```

No warning is suppressed. A warning is removed only after its width,
signedness, timing and numeric effect are demonstrated to be unchanged or
corrected by the reference comparison.
