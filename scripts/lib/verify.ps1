# Shared helpers for all scripts in this repository.
#
# NOTE: every .ps1 and .cmd in this repo is deliberately ASCII-only.
# Windows PowerShell 5.1 reads a .ps1 without a BOM using the system ANSI
# code page, so non-ASCII text inside a script can corrupt its syntax on
# machines with a different locale. All Chinese documentation lives in
# /docs instead.
#
# Dot-source it like this:
#   . (Join-Path $PSScriptRoot '..\lib\verify.ps1')

Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------
# Known-good SHA256 values.  See ../THIRD-PARTY.md for what each one is.
# ---------------------------------------------------------------------------
$script:KnownHash = @{
    # StarCraft: Remastered x86 client, version 1.23.10.13515
    ScrX86 = '32dbbdd001dd381cb1b3a719b7ad1fc918a9d4bc99661c675e00254efecca827'
    # Pluto release md07x02_cog2026_2578600_int8mv
    PlutoDll     = '7e360b643c8c0156c03fe0cad9972a3058138ccfe22f921c5b4e0cd0aaf0abef'
    PlutoInfer   = 'ad880d8be52a6ef03893fa20644b6627e04fcd55e030178c6d52486b82340f2b'
    PlutoWeights = '00b400eace6e4782202ebdcb3c30db76054aaa6a08c6a7dcb59575abc2d0a26e'
    # Remastered bridge (mirror: github.com/lpflhh/Pluto-AI-Starcraft-Remaster)
    BridgeDll    = 'beba6230b098c77579a281f592b83beea5d335b2105b7c4b2bf4fad069e74773'
    BridgeLoader = '5461b07d1d656fbedb86245da64ce3fb3d71a3ef4a81221d6a094a5c54f68e7e'
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    $stream = $null
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        return [System.BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-', '').ToLowerInvariant()
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
        $algorithm.Dispose()
    }
}

function Test-Hash {
    <#
      Returns $true when the file matches, $false when it does not,
      and throws when the file is missing.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Expected,
        [string]$Label = ''
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing file: $Path"
    }
    $actual = Get-Sha256 -Path $Path
    if ($actual -ne $Expected.ToLowerInvariant()) {
        if ($Label) { Write-Host ("  [FAIL] {0}" -f $Label) -ForegroundColor Red }
        Write-Host ("         file     : {0}" -f $Path)
        Write-Host ("         expected : {0}" -f $Expected.ToLowerInvariant())
        Write-Host ("         actual   : {0}" -f $actual)
        return $false
    }
    if ($Label) { Write-Host ("  [OK]   {0}" -f $Label) -ForegroundColor Green }
    return $true
}

# ---------------------------------------------------------------------------
# Environment discovery
# ---------------------------------------------------------------------------

function Get-CpuInfo {
    <# Reports whether the CPU has AVX2 and, very roughly, whether it is a
       generation that carries AVX-VNNI.  AVX-VNNI roughly doubles Pluto's
       inference speed; see docs/04. #>
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $result = [ordered]@{
        Name    = $cpu.Name.Trim()
        Cores   = $cpu.NumberOfCores
        Threads = $cpu.NumberOfLogicalProcessors
        # AVX-VNNI shipped with Intel 12th gen (2021) and AMD Zen 5 (2024).
        # We cannot query CPUID feature bits from PowerShell, so this is a
        # name-based hint only - the authoritative answer comes from the
        # inference engine's own log line ("AVX2 madd fallback" means no VNNI).
        LikelyVnni = $false
    }
    if ($cpu.Name -match 'Ryzen\s+9\s+9[0-9]{3}|Ryzen\s+AI|Ultra\s+[23579]|i[3579]-1[2-9][0-9]{3}') {
        $result.LikelyVnni = $true
    }
    return [pscustomobject]$result
}

# Join-Path throws on a drive letter that does not exist (disconnected mapped
# drives show up in Get-PSDrive), so probe defensively with plain strings.
function Test-PathSafe {
    param([string]$Path)
    try { return (Test-Path -LiteralPath $Path) } catch { return $false }
}

function Get-FileSystemRoots {
    $roots = @()
    try {
        $roots = @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue |
                   Where-Object { Test-PathSafe ($_.Root) } |
                   Select-Object -ExpandProperty Root)
    } catch { }
    return $roots
}

function Find-ScrRoot {
    <# Looks for a StarCraft: Remastered install in the usual places. #>
    $candidates = @(
        'C:\Program Files (x86)\StarCraft',
        'C:\Program Files\StarCraft'
    )
    foreach ($r in (Get-FileSystemRoots)) {
        $candidates += ($r.TrimEnd('\') + '\StarCraft')
    }
    # the Blizzard launcher registry entry wins if present
    $reg = 'HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\StarCraft'
    if (Test-Path $reg) {
        $p = (Get-ItemProperty $reg -ErrorAction SilentlyContinue).InstallPath
        if ($p) { $candidates = @($p) + $candidates }
    }
    foreach ($c in $candidates) {
        if (-not $c) { continue }
        if ((Test-PathSafe ($c + '\x86\StarCraft.exe')) -or (Test-PathSafe ($c + '\x86_64\starcraft.exe'))) {
            return $c
        }
    }
    return $null
}

function Find-KkRoot {
    <# Looks for the KK battle platform (kkduizhan). #>
    foreach ($r in (Get-FileSystemRoots)) {
        $c = $r.TrimEnd('\') + '\kkduizhan'
        if (Test-PathSafe ($c + '\Platform.exe')) { return $c }
    }
    return $null
}

function Get-KkScrRootDir {
    <# Reads SCRRootDir out of the KK platform config.  This is the setting
       that decides whether KK launches the 32-bit or the 64-bit client, and
       the bridge only supports the 32-bit one. #>
    param([Parameter(Mandatory)][string]$KkRoot)
    $ini = Join-Path $KkRoot 'config\custom\platform.ini'
    if (-not (Test-Path $ini)) { return $null }
    foreach ($line in (Get-Content -LiteralPath $ini -ErrorAction SilentlyContinue)) {
        if ($line -match '^\s*SCRRootDir\s*=\s*(.+?)\s*$') { return $Matches[1] }
    }
    return $null
}

function Write-Section {
    param([Parameter(Mandatory)][string]$Title)
    Write-Host ''
    Write-Host ('=== ' + $Title + ' ' + ('=' * [Math]::Max(0, 58 - $Title.Length))) -ForegroundColor Cyan
}
