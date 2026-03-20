param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$TestName,

    [Parameter(Position = 1)]
    [ValidateSet('mock', 'real')]
    [string]$Flow = 'mock'
)

$ErrorActionPreference = 'Stop'

function Find-RepoRoot {
    param([string]$StartDir)

    $dir = (Resolve-Path $StartDir).Path
    while ($true) {
        if ((Test-Path (Join-Path $dir 'rtl')) -and (Test-Path (Join-Path $dir 'tb'))) {
            return $dir
        }

        $parent = Split-Path $dir -Parent
        if ($parent -eq $dir -or [string]::IsNullOrWhiteSpace($parent)) {
            throw "Could not find repository root above '$StartDir'."
        }
        $dir = $parent
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Find-RepoRoot -StartDir $scriptDir
$localDir = Join-Path $repoRoot (Join-Path 'sim/local/questa' ("{0}_{1}" -f $TestName, $Flow))
$tclScriptPath = (Join-Path $repoRoot 'sim/manifest/scripts/run_questa.tcl') -replace '\\', '/'
New-Item -ItemType Directory -Path $localDir -Force | Out-Null

$env:ACES_TEST_NAME = $TestName
$env:ACES_FLOW = $Flow
$env:ACES_REPO_ROOT = $repoRoot
$env:ACES_LOCAL_DIR = $localDir

Push-Location $repoRoot
try {
    & vsim -c -do "do {$tclScriptPath}"
    if ($LASTEXITCODE -ne 0) {
        throw "vsim exited with code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}
