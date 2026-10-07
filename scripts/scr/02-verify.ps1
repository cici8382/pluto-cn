# 02 - Component check (StarCraft: Remastered track)
#
# Verifies that the Pluto release and the Remastered bridge are the exact
# versions this guide was written against.  The bridge itself refuses to run
# on a mismatch, so this is a fast way to find out before you waste time.
#
#   .\scripts\scr\02-verify.ps1 -Pluto "D:\...\pluto.dll" -Bridge "D:\PlutoSCR"
#   .\scripts\scr\02-verify.ps1 -Pluto ... -Bridge ... -VerifyOnly

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Pluto,
    [Parameter(Mandatory)][string]$Bridge,
    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\verify.ps1')

Write-Section 'Component check'

$failed = @()

# --- Pluto -------------------------------------------------------------------
Write-Host ' Pluto:'
if (-not (Test-Hash -Path $Pluto -Expected $KnownHash.PlutoDll -Label 'pluto.dll')) {
    $failed += 'pluto.dll'
}
$modelDir = Join-Path (Split-Path $Pluto -Parent) 'pluto'
if (-not (Test-Hash -Path (Join-Path $modelDir 'pluto_infer.exe')  -Expected $KnownHash.PlutoInfer   -Label 'pluto\pluto_infer.exe')) {
    $failed += 'pluto_infer.exe'
}
if (-not (Test-Hash -Path (Join-Path $modelDir 'pluto_weights.bin') -Expected $KnownHash.PlutoWeights -Label 'pluto\pluto_weights.bin')) {
    $failed += 'pluto_weights.bin'
}

# --- bridge ------------------------------------------------------------------
Write-Host ''
Write-Host ' Bridge:'
$bin = Join-Path $Bridge 'bin'
if (-not (Test-Hash -Path (Join-Path $bin 'pluto-scr.dll') -Expected $KnownHash.BridgeDll    -Label 'bin\pluto-scr.dll')) {
    $failed += 'pluto-scr.dll'
}
if (-not (Test-Hash -Path (Join-Path $bin 'scr-loader.exe') -Expected $KnownHash.BridgeLoader -Label 'bin\scr-loader.exe')) {
    $failed += 'scr-loader.exe'
}

# --- verdict -----------------------------------------------------------------
Write-Host ''
if ($failed.Count -gt 0) {
    Write-Host ('  [FAIL] {0} file(s) did not match: {1}' -f $failed.Count, ($failed -join ', ')) -ForegroundColor Red
    Write-Host '         Your copies are a different version than this guide targets.'
    Write-Host '         See THIRD-PARTY.md for the expected versions and mirrors.'
    exit 1
}

Write-Host '  All components verified.' -ForegroundColor Green

if ($VerifyOnly) { exit 0 }

Write-Section 'Next'
Write-Host '  Launch KK with the multiplayer environment variables:'
Write-Host '     .\scripts\scr\launch-kk.cmd'
Write-Host ''
Write-Host '  Enter a room so KK starts the game, then inject the AI:'
Write-Host ('     .\scripts\scr\03-inject-kk.ps1 -Pluto "{0}" -Bridge "{1}"' -f $Pluto, $Bridge)
Write-Host ''
