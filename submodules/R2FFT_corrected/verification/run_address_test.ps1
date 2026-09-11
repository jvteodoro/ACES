$ErrorActionPreference = 'Stop'

$questa = if ($env:QUESTA_BIN) { $env:QUESTA_BIN } else { 'C:\altera_lite\25.1std\questa_fse\win64' }
$verification = Split-Path -Parent $MyInvocation.MyCommand.Path
$work = Join-Path $verification 'work'

if (Test-Path $work) {
    Remove-Item -Recurse -Force $work
}

Push-Location $verification
try {
    & (Join-Path $questa 'vlib.exe') work
    & (Join-Path $questa 'vlog.exe') '..\hdl\fftAddressGenerator.sv' 'tb_fft_address_generator.sv'
    & (Join-Path $questa 'vsim.exe') -c -do 'run -all; quit -f' 'work.tb_fft_address_generator'
    if ($LASTEXITCODE -ne 0) {
        throw "Questa address-generator test failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}
