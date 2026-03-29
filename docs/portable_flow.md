# Portable Simulation Flow

## Purpose of `sim/portable/`

`sim/portable/` exists so ACES can be packaged and handed to another engineer without asking them to reconstruct the repository’s simulation environment manually.

The portable package is intended to contain:

- active RTL,
- testbenches,
- mock models,
- filelists,
- wave setups,
- scripts,
- quartus project collateral,
- initialized submodule sources required by the real FFT flow,
- supporting tools/assets needed by the documented simulation workflow.

## What the Portable Package Is For

Use the portable flow when you want to:

- send a runnable simulation snapshot to a collaborator,
- archive a known-good simulation handoff,
- separate “what to run” from your local development workspace.

## What Is Included

The packaging script assembles a package containing:

- `rtl/`
- `tb/`
- `filelists/`
- `waves/`
- `scripts/`
- `quartus/`
- `quartus_ip/`
- `submodules/`
- `tools/`
- `docs/`
- package-level readme files

## How to Generate the Portable Package

From the repository root:

```bash
sim/manifest/scripts/package_portable.sh
```

Windows PowerShell:

```powershell
.\sim\manifest\scripts\package_portable.ps1
```

Outputs:

- package directory: `sim/portable/questa_package/`
- zip archive: `sim/portable/aces_questa_portable.zip`

## How Another User Runs It

### Step 1: obtain the ZIP
Receive `aces_questa_portable.zip` or the unpacked `questa_package/` directory.

### Step 2: unpack it
Unzip the package anywhere on a machine with Questa installed.

### Step 3: enter the package root
The package is intended to be run from the package root containing `rtl/`, `tb/`, `filelists/`, `scripts/`, `quartus/`, and `submodules/`.

### Step 4: run a mock-flow test
Example:

```bash
scripts/run_questa.sh i2s_rx_adapter_24
scripts/run_questa.sh top_level_test mock
```

Windows PowerShell:

```powershell
.\scripts\run_questa.ps1 i2s_rx_adapter_24
.\scripts\run_questa.ps1 top_level_test mock
```

From a WSL terminal attached through VS Code Remote WSL, the same package can also be run with:

```bash
scripts/run_questa.sh i2s_rx_adapter_24
scripts/run_questa.sh top_level_test mock
```

If the simulator is installed only on Windows, the package-level `.sh` wrappers auto-forward to the packaged `.ps1` scripts through `powershell.exe`.

### Step 5: run a real-IP-oriented top-level test if needed
Example:

```bash
scripts/run_questa.sh top_level_test real
```

Windows PowerShell:

```powershell
.\scripts\run_questa.ps1 top_level_test real
```

### Step 6: open the Quartus project if FPGA build bring-up is needed
Open `quartus/top_level_test.qpf`. The project loads `quartus/top_level_test.qsf`, which in turn imports `quartus/top_level_test_sources.tcl` so Quartus adds the active RTL, the checked-in R2FFT submodule sources, and the required FFT/ROM `.qip` files and memory images.

## Step-by-Step Handoff Guidance

1. Generate the package from a clean repository state.
2. Verify the package contents exist.
3. Send the ZIP with the initialized `submodules/R2FFT` sources included in the package.
4. Tell the recipient whether they should use mock or real-IP-oriented flow.
5. If GUI inspection is expected, tell them which wave `.do` file matches the scenario.

## Limitations

- The portable package still requires Questa to be installed on the target machine.
- On Windows hosts, users should run the provided `.ps1` script variants from PowerShell.
- The real-IP-oriented flow expects the `submodules/R2FFT` checkout to be present in the package or working tree.
- A portable package is a generated snapshot; contributors should make source changes in the repository, not inside the package.

## Best Practices

- Regenerate the package after changing filelists or scripts.
- Prefer mock flow for first-time recipients unless they specifically need real FFT collateral.
- Include a note about which test target the recipient should run first.

## Related Reading

- [simulation.md](simulation.md)
- [repository_structure.md](repository_structure.md)
- [faq.md](faq.md)
