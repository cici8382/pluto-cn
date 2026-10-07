# 01 - Environment check (StarCraft: Remastered track)
#
# Verifies that this machine can run the Pluto <-> Remastered bridge:
#   * the 32-bit Remastered client exists and is build 1.23.10.13515
#   * the CPU has AVX2 (and hints whether it has AVX-VNNI)
#   * the KK platform is installed and configured to launch the 32-bit client
#
# Read docs/03 (Remastered + KK platform) for the full walkthrough.

[CmdletBinding()]
param(
    [string]$ScrRoot
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\verify.ps1')

Write-Section 'StarCraft: Remastered - environment check'

# --- locate the game ---------------------------------------------------------
if (-not $ScrRoot) { $ScrRoot = Find-ScrRoot }
if (-not $ScrRoot) {
    Write-Host '  [FAIL] Could not find a StarCraft: Remastered installation.' -ForegroundColor Red
    Write-Host '         Pass it explicitly:  -ScrRoot "D:\StarCraft"'
    exit 1
}
Write-Host ("  install root : {0}" -f $ScrRoot)

$x86  = Join-Path $ScrRoot 'x86\StarCraft.exe'
$x64  = Join-Path $ScrRoot 'x86_64\starcraft.exe'

# --- the 32-bit client is the one the bridge targets -------------------------
if (-not (Test-Path $x86)) {
    Write-Host '  [FAIL] 32-bit client not found (x86\StarCraft.exe).' -ForegroundColor Red
    Write-Host '         The bridge only works with the 32-bit client.'
    exit 1
}
$v86 = (Get-Item $x86).VersionInfo.FileVersion
Write-Host ("  x86 client   : version {0}" -f $v86) -ForegroundColor Green

if ($v86 -ne '1.23.10.13515') {
    Write-Host ("  [WARN] The bridge is locked to build 1.23.10.13515.") -ForegroundColor Yellow
    Write-Host ("         Yours is {0}.  A Blizzard hot-fix shifts every memory" -f $v86)
    Write-Host ("         offset and the bridge will crash on injection.")
}

$ok = Test-Hash -Path $x86 -Expected $KnownHash.ScrX86 -Label 'x86 client matches the supported build'
if (-not $ok) {
    Write-Host '         The bridge refuses to run against this file.' -ForegroundColor Yellow
}

if (Test-Path $x64) {
    Write-Host ("  x64 client   : present (not used by the bridge)")
}

# --- CPU ---------------------------------------------------------------------
$cpu = Get-CpuInfo
Write-Host ''
Write-Host ("  CPU          : {0}" -f $cpu.Name)
Write-Host ("                 {0} cores / {1} threads" -f $cpu.Cores, $cpu.Threads)
if ($cpu.LikelyVnni) {
    Write-Host '                 likely AVX-VNNI capable -> fast inference' -ForegroundColor Green
} else {
    Write-Host '                 likely no AVX-VNNI -> about half speed' -ForegroundColor Yellow
    Write-Host '                 (confirm with:  pluto_infer.exe --bench)'
}

# --- KK platform -------------------------------------------------------------
Write-Host ''
$kk = Find-KkRoot
if ($kk) {
    Write-Host ("  KK platform  : {0}" -f $kk) -ForegroundColor Green
    $scrRootDir = Get-KkScrRootDir -KkRoot $kk
    if ($scrRootDir) {
        Write-Host ("  SCRRootDir   : {0}" -f $scrRootDir)
        if ($scrRootDir -match 'x86_64') {
            Write-Host '  [FAIL] KK is configured to launch the 64-BIT client.' -ForegroundColor Red
            Write-Host ('         Edit {0}\config\custom\platform.ini' -f $kk)
            Write-Host '         and set:   SCRRootDir=<your path>\x86'
            Write-Host '         (fully exit the KK platform before editing)'
        } elseif ($scrRootDir -match 'x86\s*$') {
            Write-Host '  [OK]   KK is set to launch the 32-bit client.' -ForegroundColor Green
        } else {
            Write-Host '  [WARN] SCRRootDir does not end in x86 - verify it manually.' -ForegroundColor Yellow
        }
    } else {
        Write-Host '  [WARN] Could not read SCRRootDir from the KK config.' -ForegroundColor Yellow
        Write-Host ('         Expected: {0}\config\custom\platform.ini' -f $kk)
    }
} else {
    Write-Host '  KK platform  : not found (optional - only needed for KK rooms)'
}

# --- what next ---------------------------------------------------------------
Write-Section 'Next'
Write-Host '  1. Get Pluto + the bridge (see THIRD-PARTY.md), then:'
Write-Host '       .\scripts\scr\02-verify.ps1 -Pluto <pluto.dll> -Bridge <bridge dir>'
Write-Host '  2. Launch KK with the multiplayer environment variables:'
Write-Host '       .\scripts\scr\launch-kk.cmd'
Write-Host '  3. Enter a room so KK starts the game, then inject:'
Write-Host '       .\scripts\scr\03-inject-kk.ps1 -Watch'
Write-Host ''
