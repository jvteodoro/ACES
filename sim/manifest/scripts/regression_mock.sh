#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TESTS=(
  hexa7seg
  i2s_rx_adapter_24
  sample_width_adapter_24_to_18
  i2s_master_clock_gen
  i2s_stimulus_manager_rom
  aces_audio_to_fft_pipeline
)
for test_name in "${TESTS[@]}"; do
  echo "=== Running ${test_name} (mock) ==="
  "${SCRIPT_DIR}/run_questa.sh" "${test_name}" mock
  echo
done
