$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path (Split-Path (Split-Path $scriptDir -Parent) -Parent) -Parent
$portableRoot = Join-Path $repoRoot 'sim/portable/questa_package'
$zipPath = Join-Path $repoRoot 'sim/portable/aces_questa_portable.zip'

if (Test-Path $portableRoot) {
    Remove-Item -Recurse -Force $portableRoot
}

$dirs = @('questa','quartus','quartus_ip','filelists','waves','scripts','rtl','tb','docs','tools')
foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Path (Join-Path $portableRoot $dir) -Force | Out-Null
}

Copy-Item -Recurse -Force (Join-Path $repoRoot 'rtl/*') (Join-Path $portableRoot 'rtl')
Copy-Item -Recurse -Force (Join-Path $repoRoot 'tb/*') (Join-Path $portableRoot 'tb')
Copy-Item -Recurse -Force (Join-Path $repoRoot 'sim/manifest/filelists/*') (Join-Path $portableRoot 'filelists')
Copy-Item -Recurse -Force (Join-Path $repoRoot 'sim/manifest/waves/*') (Join-Path $portableRoot 'waves')
Copy-Item -Recurse -Force (Join-Path $repoRoot 'sim/manifest/scripts/*') (Join-Path $portableRoot 'scripts')
Copy-Item -Recurse -Force (Join-Path $repoRoot 'docs/*') (Join-Path $portableRoot 'docs')
Copy-Item -Recurse -Force (Join-Path $repoRoot 'tools/*') (Join-Path $portableRoot 'tools')
Copy-Item -Recurse -Force (Join-Path $repoRoot 'rtl/ip/*') (Join-Path $portableRoot 'quartus_ip')
Copy-Item -Recurse -Force (Join-Path $repoRoot 'quartus/*') (Join-Path $portableRoot 'quartus')
Copy-Item -Force (Join-Path $repoRoot 'README.md') (Join-Path $portableRoot 'README.md')
Copy-Item -Force (Join-Path $repoRoot 'sim/manifest/README.md') (Join-Path $portableRoot 'questa/README.md')

@'
ACES portable Questa package
============================

1. Unzip anywhere.
2. On Linux/macOS, run scripts/run_questa.sh <test_name> [mock|real] from the package root.
3. On Windows PowerShell, run .\scripts\run_questa.ps1 <test_name> [mock|real] from the package root.
4. Mock flow is self-contained.
5. Real flow expects any external FFT implementation filelist to be supplied through EXTRA_FILELIST.
6. For FPGA build bring-up, open quartus/top_level_test.qpf from the package root.
'@ | Set-Content -Path (Join-Path $portableRoot 'README.txt')

if (Test-Path $zipPath) {
    Remove-Item -Force $zipPath
}
Compress-Archive -Path $portableRoot -DestinationPath $zipPath
Write-Host "Portable package created at $zipPath"
