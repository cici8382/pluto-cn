# 01 - Environment check (StarCraft 1.16.1 track)
#
# Reports what is present and what is still missing before you start.
# Read docs/02 (1.16.1 install & same-PC play) for the walkthrough.

[CmdletBinding()]
param(
    [string]$GameDir
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\verify.ps1')

Write-Section 'StarCraft 1.16.1 - environment check'

# --- locate the 1.16.1 install ----------------------------------------------
function Test-StarCraft1161([string]$dir) {
    $exe = $dir + '\StarCraft.exe'
    if (-not (Test-PathSafe $exe)) { return $false }
    try { return (Get-Item $exe).VersionInfo.FileVersion -like '1.16*' } catch { return $false }
}

if (-not $GameDir) {
    $candidates = @()
    foreach ($r in (Get-FileSystemRoots)) {
        foreach ($name in @('starcraft_old','StarCraft1161','StarCraft','starcraft')) {
            $candidates += ($r.TrimEnd('\') + '\' + $name)
        }
    }
    foreach ($c in $candidates) {
        if (Test-StarCraft1161 $c) { $GameDir = $c; break }
    }
}

if (-not $GameDir -or -not (Test-StarCraft1161 $GameDir)) {
    Write-Host '  [FAIL] No StarCraft 1.16.1 install found.' -ForegroundColor Red
    Write-Host '         Pass it explicitly:  -GameDir "G:\starcraft_old"'
    exit 1
}
$GameDir = (Resolve-Path $GameDir).Path
Write-Host ("  game folder : {0}" -f $GameDir) -ForegroundColor Green
Write-Host ("  version     : {0}" -f (Get-Item (Join-Path $GameDir 'StarCraft.exe')).VersionInfo.FileVersion)

# --- components --------------------------------------------------------------
Write-Host ''
$missing = @()

# BWAPI runtime (the injector loads bwapi-data\BWAPI.dll)
$bwapiDll = Join-Path $GameDir 'bwapi-data\BWAPI.dll'
if (Test-Path $bwapiDll) {
    Write-Host '  [OK]   BWAPI runtime (bwapi-data\BWAPI.dll)' -ForegroundColor Green
} else {
    Write-Host '  [MISS] BWAPI runtime - install BWAPI 4.4.0 into the game folder' -ForegroundColor Yellow
    $missing += 'BWAPI'
}

# Pluto
$plutoDll = Join-Path $GameDir 'bwapi-data\AI\pluto.dll'
$plutoDir = Join-Path $GameDir 'bwapi-data\AI\pluto'
if (Test-Path $plutoDll) {
    Write-Host '  [OK]   Pluto (bwapi-data\AI\pluto.dll)' -ForegroundColor Green
    if (-not (Test-Path (Join-Path $plutoDir 'pluto_infer.exe'))) { $missing += 'pluto_infer.exe' }
    if (-not (Test-Path (Join-Path $plutoDir 'pluto_weights.bin'))) { $missing += 'pluto_weights.bin' }
} else {
    Write-Host '  [MISS] Pluto - see THIRD-PARTY.md' -ForegroundColor Yellow
    $missing += 'Pluto'
}

# bwapi.ini pointing at Pluto
$ini = Join-Path $GameDir 'bwapi-data\bwapi.ini'
if (Test-Path $ini) {
    $ai = (Select-String -LiteralPath $ini -Pattern '^\s*ai\s*=\s*(.+)$' |
           Select-Object -First 1).Matches.Groups[1].Value
    Write-Host ("  bwapi.ini ai= {0}" -f $ai)
    if ($ai -notmatch 'pluto') {
        Write-Host '  [WARN] bwapi.ini does not point at pluto.dll' -ForegroundColor Yellow
    }
} else {
    Write-Host '  [MISS] bwapi-data\bwapi.ini' -ForegroundColor Yellow
    $missing += 'bwapi.ini'
}

# IPXWrapper - only needed for same-PC or LAN play on modern Windows
$ipx = Join-Path $GameDir 'ipxwrapper.dll'
if (Test-Path $ipx) {
    Write-Host '  [OK]   IPXWrapper present (needed for LAN/IPX play)' -ForegroundColor Green
    if (-not (Test-Path 'HKCU:\Software\IPXWrapper')) {
        Write-Host '  [WARN] IPXWrapper has never been configured - run ipxconfig.exe once' -ForegroundColor Yellow
    }
} else {
    Write-Host '  [MISS] IPXWrapper - needed for Local Area Network (IPX)' -ForegroundColor Yellow
    $missing += 'IPXWrapper'
}

# --- CPU ---------------------------------------------------------------------
Write-Host ''
$cpu = Get-CpuInfo
Write-Host ("  CPU : {0}  ({1}C/{2}T)" -f $cpu.Name, $cpu.Cores, $cpu.Threads)
if (-not $cpu.LikelyVnni) {
    Write-Host '        likely no AVX-VNNI -> inference about half speed (see docs/04)'
}

# --- verdict -----------------------------------------------------------------
Write-Section 'Summary'
if ($missing.Count -eq 0) {
    Write-Host '  Everything needed is present.' -ForegroundColor Green
} else {
    Write-Host ('  Still missing: {0}' -f ($missing -join ', ')) -ForegroundColor Yellow
}
Write-Host ''
Write-Host '  For same-PC play (two instances on one machine), run:'
Write-Host ('     .\scripts\1161\03-setup-same-pc.ps1 -GameDir "{0}" -Password <pw>' -f $GameDir)
Write-Host ''
Write-Host '  For two separate machines you do not need that step - just make sure'
Write-Host '  both machines have IPXWrapper and pick Local Area Network (IPX).'
Write-Host ''
