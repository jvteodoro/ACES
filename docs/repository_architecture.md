# ACES repository architecture

## Why the repository was reorganized

The refactor separates three very different concerns that were previously mixed together:

- **active design sources**,
- **reproducible simulation manifests**, and
- **generated simulator/package outputs**.

That separation makes the repository easier to understand for both engineers and AI agents because path intent is now obvious.

## Directory intent

### `rtl/`
Only active design sources live here. If a file is part of the maintained hardware/simulation implementation, it belongs here.

### `tb/`
All executable testbenches and simulation-only mocks live here. Unit and integration tests are intentionally split so filelists can stay narrow.

### `sim/manifest/`
This directory is the versioned control plane for simulation:

- filelists are the compile source of truth,
- scripts provide stable entry points,
- waves are versioned review artifacts.

### `sim/local/`
This is intentionally disposable. Work libraries, transcripts, and other machine-local artifacts belong here and should never be reviewed as source.

### `sim/portable/`
This is generated output for handoff. The packaging script copies the minimum runnable structure so another engineer can unzip and run with fewer assumptions.

## Mock versus real-IP layering

The repository now treats mock and real-IP simulation as first-class but separate flows.

- **Mock flow** is fully self-contained and ideal for bring-up.
- **Real-IP flow** uses checked-in Quartus ROM wrappers and expects the real FFT core to be supplied explicitly through an extra filelist.

That explicit boundary avoids a common failure mode where a simulation accidentally mixes mock and real assets without documentation.
