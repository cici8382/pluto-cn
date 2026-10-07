# 03 - Set up same-PC play (StarCraft 1.16.1 track)
#
# Makes it possible for two StarCraft 1.16.1 instances on ONE machine to see
# each other over "Local Area Network (IPX)".
#
# There are two independent obstacles, both solved here:
#
#   1. DUPLICATE IPX NODE
#      IPXWrapper stores its config in HKCU\Software\IPXWrapper\<nic MAC>, so
#      two instances under the same Windows user present the SAME IPX node and
#      StarCraft discards the peer's packets as its own.
#      -> the second instance runs under a separate Windows account.
#
#   2. IPXWRAPPER'S NAMED SOCKET MUTEX
#      src/winsock.c builds "ipxwrapper_socket_%hu" with CreateMutex and fails
#      the bind when it already exists.  The name carries no user or process
#      component, so it collides ACROSS USERS in the same logon session, and
#      StarCraft always binds IPX socket 6112.  The failure path logs nothing.
#      -> the second instance loads a copy of ipxwrapper.dll whose mutex name
#         was renamed by exactly one byte, giving it its own namespace.  The
#         original DLL is never modified.
#
# Read docs/02 (1.16.1 install & same-PC play) for the full explanation.
#
#   .\scripts\1161\03-setup-same-pc.ps1 -GameDir "G:\starcraft_old" -User scai -Password <pw>
#   .\scripts\1161\03-setup-same-pc.ps1 ... -WhatIf    (report only, change nothing)

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)][string]$GameDir,
    [string]$User = 'scai',
    [string]$Password,
    [string]$ShadowDir,
    # IPX node for the second instance.  02:.. is a locally-administered
    # address, guaranteed not to collide with any real NIC.
    [string]$Node = '02:00:00:00:00:01'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\verify.ps1')

if (-not (Test-Path (Join-Path $GameDir 'StarCraft.exe'))) {
    throw "Not a StarCraft folder (no StarCraft.exe): $GameDir"
}
$GameDir = (Resolve-Path $GameDir).Path
if (-not $ShadowDir) { $ShadowDir = Join-Path (Split-Path $GameDir -Parent) ((Split-Path $GameDir -Leaf) + '_human') }

# ---------------------------------------------------------------------------
# Prerequisite: IPXWrapper must already be configured for the CURRENT user,
# because the second instance has to match its UDP port and network number.
# ---------------------------------------------------------------------------
Write-Section 'Checking IPXWrapper'
$ipxReg = 'HKCU:\Software\IPXWrapper'
if (-not (Test-Path $ipxReg)) {
    Write-Host '  [FAIL] IPXWrapper is not configured for the current user.' -ForegroundColor Red
    Write-Host '         Install IPXWrapper into the game folder and run ipxconfig.exe'
    Write-Host '         once (set a primary interface), then run this again.'
    exit 1
}
$cur = Get-ItemProperty $ipxReg
$curPort = if ($cur.port) { [int]$cur.port } else { 213 }
Write-Host ("  current user : port={0}  primary={1}" -f $curPort, (($cur.primary | ForEach-Object { '{0:X2}' -f $_ }) -join ':'))

# The IPX interface the second instance should use - same NIC as the first,
# so both end up on the same IPX network.
$primaryMac = if ($cur.primary) { ($cur.primary | ForEach-Object { '{0:X2}' -f $_ }) -join ':' } else { $null }
if (-not $primaryMac) {
    Write-Host '  [FAIL] No primary interface set for IPXWrapper.' -ForegroundColor Yellow
    Write-Host '         Run ipxconfig.exe and pick the network interface you play on.'
    exit 1
}
Write-Host ("  second instance will use node {0} on the same NIC" -f $Node)

if ($WhatIfPreference) {
    Write-Section 'WhatIf - nothing was changed'
    Write-Host ("  would create account : {0}" -f $User)
    Write-Host ("  would build shadow   : {0}" -f $ShadowDir)
    Write-Host ("  would patch          : {0}\ipxwrapper.dll  (1 byte)" -f $ShadowDir)
    exit 0
}

# ---------------------------------------------------------------------------
# 1) Windows account
# ---------------------------------------------------------------------------
Write-Section 'Step 1/3 - Windows account'
if (Get-LocalUser -Name $User -ErrorAction SilentlyContinue) {
    Write-Host ("  account '{0}' already exists - leaving it alone" -f $User)
} else {
    if (-not $Password) {
        throw "Creating the account needs -Password. Example: -Password 'SCai-6112-ipx'"
    }
    $sec = ConvertTo-SecureString $Password -AsPlainText -Force
    New-LocalUser -Name $User -Password $sec `
        -FullName 'StarCraft LAN instance' `
        -Description 'Second user for same-PC StarCraft IPX play' `
        -PasswordNeverExpires | Out-Null
    Write-Host ("  created standard user '{0}'" -f $User) -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 2) IPXWrapper config for that user (its own HKCU -> its own IPX node)
# ---------------------------------------------------------------------------
Write-Section 'Step 2/3 - IPXWrapper config for the second user'
$hex = ($Node -split ':') | ForEach-Object { $_.ToLower() }
$primaryHex = (($primaryMac -split ':') | ForEach-Object { $_.ToLower() }) -join ','
$nodeHex    = $hex -join ','

$regBody = @"
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\IPXWrapper]
"port"=dword:$('{0:x8}' -f $curPort)
"w95_bug"=dword:00000001
"fw_except"=dword:00000000
"use_pcap"=dword:00000000
"frame_type"=dword:00000001
"log_level"=dword:00000004
"primary"=hex:$primaryHex

[HKEY_CURRENT_USER\Software\IPXWrapper\$primaryMac]
"net"=hex:00,00,00,01
"node"=hex:$nodeHex
"enabled"=dword:00000001
"@

$regFile = Join-Path (Split-Path $GameDir -Parent) 'pluto-cn-ipx.reg'
$regBody | Set-Content -LiteralPath $regFile -Encoding Unicode
& icacls $regFile /grant "${User}:(R)" 2>&1 | Out-Null
Write-Host ("  wrote {0} (read granted to {1})" -f $regFile, $User)

$cred = New-Object System.Management.Automation.PSCredential(
    $User, (ConvertTo-SecureString $Password -AsPlainText -Force))
$p = Start-Process -FilePath 'reg.exe' -ArgumentList 'import', "`"$regFile`"" `
        -Credential $cred -Wait -PassThru -WindowStyle Hidden
if ($p.ExitCode -ne 0) { throw "reg import failed (exit $($p.ExitCode))" }
Write-Host '  imported into that user''s registry hive' -ForegroundColor Green

# ---------------------------------------------------------------------------
# 3) Shadow folder with the renamed-mutex ipxwrapper.dll
# ---------------------------------------------------------------------------
Write-Section 'Step 3/3 - Shadow folder'
if (Test-Path $ShadowDir) { Write-Host ("  {0} already exists - rebuilding links" -f $ShadowDir) }
else { New-Item -ItemType Directory -Path $ShadowDir | Out-Null }

# subdirectories -> junctions (shared, zero copy)
$dirs = Get-ChildItem $GameDir -Directory
foreach ($d in $dirs) {
    $link = Join-Path $ShadowDir $d.Name
    if (-not (Test-Path $link)) { & cmd.exe /c "mklink /J `"$link`" `"$($d.FullName)`"" | Out-Null }
}
Write-Host ("  junctions  : {0}" -f (Get-ChildItem $ShadowDir -Directory).Count)

# root files -> hard links, except ipxwrapper.dll which gets its own patched copy
$linked = 0
foreach ($f in (Get-ChildItem $GameDir -File)) {
    if ($f.Name -ieq 'ipxwrapper.dll') { continue }
    $link = Join-Path $ShadowDir $f.Name
    if (Test-Path $link) { continue }
    & cmd.exe /c "mklink /H `"$link`" `"$($f.FullName)`"" | Out-Null
    $linked++
}
Write-Host ("  hard links : {0}" -f $linked)

$srcDll = Join-Path $GameDir 'ipxwrapper.dll'
$dstDll = Join-Path $ShadowDir 'ipxwrapper.dll'
$bytes  = [IO.File]::ReadAllBytes($srcDll)
$needle = [Text.Encoding]::ASCII.GetBytes('ipxwrapper_socket_%hu')
$repl   = [Text.Encoding]::ASCII.GetBytes('jpxwrapper_socket_%hu')
$hits = 0
for ($i = 0; $i -le $bytes.Length - $needle.Length; $i++) {
    $match = $true
    for ($j = 0; $j -lt $needle.Length; $j++) {
        if ($bytes[$i + $j] -ne $needle[$j]) { $match = $false; break }
    }
    if ($match) { for ($j = 0; $j -lt $needle.Length; $j++) { $bytes[$i+$j] = $repl[$j] }; $hits++ }
}
if ($hits -eq 0) { throw 'Mutex string not found in ipxwrapper.dll - unsupported version.' }
[IO.File]::WriteAllBytes($dstDll, $bytes)
Write-Host ("  patched    : {0} occurrence(s), nothing else changed" -f $hits) -ForegroundColor Green

# ---------------------------------------------------------------------------
# launcher
# ---------------------------------------------------------------------------
$launcher = Join-Path $ShadowDir 'launch-human.cmd'
@(
    '@echo off',
    'rem Start the human-side instance as the second Windows user.',
    'rem Uses %~dp0 so a shadow path containing spaces still works.',
    'cd /d "%~dp0"',
    ('runas /user:{0} /savecred "cmd.exe /c run-as-user.cmd"' -f $User)
) | Set-Content -LiteralPath $launcher -Encoding ASCII

@(
    '@echo off',
    'cd /d "%~dp0"',
    'StarCraft.exe'
) | Set-Content -LiteralPath (Join-Path $ShadowDir 'run-as-user.cmd') -Encoding ASCII

Write-Section 'Done'
Write-Host ("  shadow folder : {0}" -f $ShadowDir)
Write-Host ("  launcher      : {0}" -f $launcher)
Write-Host ''
Write-Host '  Every match:'
Write-Host '    1. AI instance  : Chaoslauncher - MultiInstance, tick the BWAPI injector, Start'
Write-Host ('    2. human instance: double-click {0}' -f $launcher)
Write-Host '    3. both: Multiplayer -> Local Area Network (IPX), one creates, one joins'
Write-Host '       (use different character names)'
Write-Host ''
Write-Host '  Verify: ipxwrapper.log in the game folder must show TWO different'
Write-Host '  node numbers and a "bind address: .../6112" line for each.'
Write-Host ''
