# Launch the KK battle platform with the Pluto multiplayer environment.
#
# WHY THIS SCRIPT EXISTS
#   In multiplayer the game speed is controlled by the game itself, so the AI
#   must not hold a frame waiting for its own inference - otherwise it drags
#   the whole match down (and can desync a lockstep game).
#
#   BWRL_STRADDLE=1 and BWRL_FRAME_BUDGET_MS=10 are read by the inference
#   engine, which inherits its environment from the GAME process, which in turn
#   inherits it from the KK platform.  So they have to be set on the platform,
#   not with setx + a hope that KK was restarted.
#
#   Launching KK through this script guarantees they are present.
#
# Read docs/04 (performance tuning) for the trade-offs.

[CmdletBinding()]
param(
    [string]$KkRoot
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\verify.ps1')

Write-Section 'Launching KK with the multiplayer environment'

# --- refuse to run while KK is already up ------------------------------------
$running = Get-Process -Name Platform -ErrorAction SilentlyContinue
if ($running) {
    Write-Host '  [FAIL] The KK platform is already running (PID ' -NoNewline -ForegroundColor Red
    Write-Host ($running.Id -join ',') -NoNewline -ForegroundColor Red
    Write-Host ').' -ForegroundColor Red
    Write-Host ''
    Write-Host '  A process cannot gain environment variables after it starts, so'
    Write-Host '  launching a second copy would do nothing useful.  Fully exit the'
    Write-Host '  KK platform (check the system tray), then run this again.'
    exit 1
}

# --- locate it ---------------------------------------------------------------
if (-not $KkRoot) { $KkRoot = Find-KkRoot }
if (-not $KkRoot) {
    Write-Host '  [FAIL] Could not find the KK platform.' -ForegroundColor Red
    Write-Host '         Pass it explicitly:  -KkRoot "G:\kkduizhan"'
    exit 1
}
$exe = Join-Path $KkRoot 'Platform.exe'
Write-Host ("  platform : {0}" -f $exe)

# --- sanity check the client KK will launch ----------------------------------
$scrRootDir = Get-KkScrRootDir -KkRoot $KkRoot
if ($scrRootDir) {
    Write-Host ("  SCRRootDir : {0}" -f $scrRootDir)
    if ($scrRootDir -match 'x86_64') {
        Write-Host '  [WARN] KK is set to launch the 64-BIT client.' -ForegroundColor Yellow
        Write-Host ('         Edit {0}\config\custom\platform.ini and set' -f $KkRoot)
        Write-Host '         SCRRootDir to the \x86 folder before playing.'
    }
}

# --- launch ------------------------------------------------------------------
$env:BWRL_STRADDLE = '1'
$env:BWRL_FRAME_BUDGET_MS = '10'
Write-Host ''
Write-Host '  environment for the game process:' -ForegroundColor Green
Write-Host '     BWRL_STRADDLE=1            (AI never stalls a frame)'
Write-Host '     BWRL_FRAME_BUDGET_MS=10    (10 ms budget per decision)'
Write-Host ''
Start-Process -FilePath $exe -WorkingDirectory $KkRoot | Out-Null
Write-Host '  KK launched.' -ForegroundColor Green
Write-Host ''
Write-Host '  Next: enter a room (KK starts the game), then run'
Write-Host '        .\scripts\scr\03-inject-kk.ps1 -Watch'
Write-Host ''
Write-Host '  To confirm the variables took effect: the in-game message'
Write-Host '  "this machine cant keep up ... stalling the game" must NOT appear.'
Write-Host ''
