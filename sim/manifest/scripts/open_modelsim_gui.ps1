param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Filelist,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$TopModule
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path (Split-Path (Split-Path $scriptDir -Parent) -Parent) -Parent
$runDir = Join-Path $repoRoot (Join-Path 'sim/local/modelsim' ("gui_{0}" -f $TopModule))
New-Item -ItemType Directory -Path $runDir -Force | Out-Null

Push-Location $runDir
try {
    & vlib work
    if ($LASTEXITCODE -ne 0) { throw "vlib failed with code $LASTEXITCODE." }

    & vmap work work
    if ($LASTEXITCODE -ne 0) { throw "vmap failed with code $LASTEXITCODE." }

    & vlog -sv -f (Join-Path $repoRoot $Filelist)
    if ($LASTEXITCODE -ne 0) { throw "vlog failed with code $LASTEXITCODE." }

    & vsim ("work.{0}" -f $TopModule)
    if ($LASTEXITCODE -ne 0) { throw "vsim failed with code $LASTEXITCODE." }
}
finally {
    Pop-Location
}