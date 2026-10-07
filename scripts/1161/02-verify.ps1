# 02 - Component check (StarCraft 1.16.1 track)
#
# Verifies that the Pluto release is the version this guide was written
# against.  Unlike the Remastered track there is no fixed game hash here -
# 1.16.1 is frozen and any install of it works.
#
#   .\scripts\1161\02-verify.ps1 -Pluto "G:\...\bwapi-data\AI\pluto.dll"

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Pluto
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\verify.ps1')

Write-Section 'Component check'

$failed = @()
if (-not (Test-Hash -Path $Pluto -Expected $KnownHash.PlutoDll -Label 'pluto.dll')) {
    $failed += 'pluto.dll'
}
$modelDir = Join-Path (Split-Path $Pluto -Parent) 'pluto'
if (-not (Test-Hash -Path (Join-Path $modelDir 'pluto_infer.exe')   -Expected $KnownHash.PlutoInfer   -Label 'pluto\pluto_infer.exe')) {
    $failed += 'pluto_infer.exe'
}
if (-not (Test-Hash -Path (Join-Path $modelDir 'pluto_weights.bin') -Expected $KnownHash.PlutoWeights -Label 'pluto\pluto_weights.bin')) {
    $failed += 'pluto_weights.bin'
}

Write-Host ''
if ($failed.Count -gt 0) {
    Write-Host ('  [FAIL] {0} file(s) did not match: {1}' -f $failed.Count, ($failed -join ', ')) -ForegroundColor Red
    Write-Host '         See THIRD-PARTY.md for the expected release.'
    exit 1
}
Write-Host '  All components verified.' -ForegroundColor Green
Write-Host ''
Write-Host '  Next: launch Chaoslauncher - MultiInstance, tick the BWAPI injector,'
Write-Host '  press Start, then in game: Single Player -> Expansion -> Play Custom'
Write-Host '  -> Melee with one Computer opponent.'
Write-Host ''
