$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$tests = @(
    'i2s_rx_adapter_24',
    'sample_width_adapter_24_to_18',
    'i2s_stimulus_manager',
    'i2s_stimulus_manager_rom',
    'sample_bridge_and_ingest',
    'aces',
    'aces_stimulus_manager',
    'top_level_test'
)

foreach ($testName in $tests) {
    Write-Host "=== Running $testName (mock) ==="
    & (Join-Path $scriptDir 'run_questa.ps1') $testName 'mock'
    if ($LASTEXITCODE -ne 0) {
        throw "Mock regression failed while running '$testName'."
    }
    Write-Host ''
}
