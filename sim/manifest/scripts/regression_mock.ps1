$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$tests = @(
    'i2s_rx_adapter_24',
    'sample_width_adapter_24_to_18',
    'i2s_master_clock_gen',
    'i2s_stimulus_manager_rom',
    'fft_control',
    'fft_dma_reader',
    'aces_audio_to_fft_pipeline',
    'aces',
    'top_level_test_mux_clear_hex_based_on_uploaded'
)

foreach ($testName in $tests) {
    Write-Host "=== Running $testName (mock) ==="
    & (Join-Path $scriptDir 'run_questa.ps1') $testName 'mock'
    if ($LASTEXITCODE -ne 0) {
        throw "Mock regression failed while running '$testName'."
    }
    Write-Host ''
}
