# 03 - Inject the AI into the game KK started (StarCraft: Remastered track)
#
# The bridge does not launch the game - it injects into an already running
# process by PID.  That is why this script exists separately from the bridge's
# own start-pluto.ps1: here KK launches the game (and handles the room), and we
# only attach the AI to it.
#
#   .\scripts\scr\03-inject-kk.ps1 -Pluto <pluto.dll> -Bridge <bridge dir>
#   .\scripts\scr\03-inject-kk.ps1 -Pluto ... -Bridge ... -Watch     (auto re-inject)
#   .\scripts\scr\03-inject-kk.ps1 -Pluto ... -Bridge ... -Challenge (1-v-many)
#
# Read docs/03 (Remastered + KK platform) for the full walkthrough.

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Pluto,
    [Parameter(Mandatory)][string]$Bridge,
    [string]$StarCraft,
    [ValidateRange(-1,1000)][int]$SpeedMs = 42,
    [switch]$Challenge,
    [switch]$Watch,
    [int]$PollSeconds = 2
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\verify.ps1')

$bin     = Join-Path $Bridge 'bin'
$runtime = Join-Path $Bridge $(if ($Challenge) { 'runtime-challenge' } else { 'runtime-multiplayer' })

# --- resolve the 32-bit client ----------------------------------------------
if (-not $StarCraft) {
    $scr = Find-ScrRoot
    if ($scr) { $StarCraft = Join-Path $scr 'x86\StarCraft.exe' }
}
if (-not $StarCraft -or -not (Test-Path $StarCraft)) {
    throw 'Cannot locate x86\StarCraft.exe. Pass -StarCraft "<path>\x86\StarCraft.exe".'
}
$StarCraft = (Resolve-Path $StarCraft).Path

# --- verify everything before touching the game ------------------------------
Write-Section 'Verifying components'
$bad = 0
if (-not (Test-Hash -Path $StarCraft -Expected $KnownHash.ScrX86      -Label 'x86 client')) { $bad++ }
if (-not (Test-Hash -Path $Pluto     -Expected $KnownHash.PlutoDll   -Label 'pluto.dll'))  { $bad++ }
$modelDir = Join-Path (Split-Path $Pluto -Parent) 'pluto'
if (-not (Test-Hash -Path (Join-Path $modelDir 'pluto_infer.exe')   -Expected $KnownHash.PlutoInfer   -Label 'pluto_infer.exe'))   { $bad++ }
if (-not (Test-Hash -Path (Join-Path $modelDir 'pluto_weights.bin') -Expected $KnownHash.PlutoWeights -Label 'pluto_weights.bin')) { $bad++ }
if (-not (Test-Hash -Path (Join-Path $bin 'pluto-scr.dll')          -Expected $KnownHash.BridgeDll    -Label 'pluto-scr.dll'))    { $bad++ }
if (-not (Test-Hash -Path (Join-Path $bin 'scr-loader.exe')         -Expected $KnownHash.BridgeLoader -Label 'scr-loader.exe'))   { $bad++ }
if ($bad -gt 0) { throw 'Component mismatch. See THIRD-PARTY.md for the expected versions.' }

function Get-GameProcess {
    @(Get-Process -Name StarCraft -ErrorAction SilentlyContinue | Where-Object {
        try { $_.Path -ieq $StarCraft } catch { $false }
    }) | Select-Object -First 1
}

function Invoke-Inject {
    param([System.Diagnostics.Process]$Game)

    Write-Host ('[{0:HH:mm:ss}] target PID {1}' -f (Get-Date), $Game.Id)

    # Archive the previous match's logs, then stage a fresh runtime directory.
    New-Item -ItemType Directory -Path $runtime -Force | Out-Null
    $previous = @('bridge.log','pluto.log','pluto_infer.log') |
        ForEach-Object { Join-Path $runtime $_ } | Where-Object { Test-Path -LiteralPath $_ }
    if ($previous) {
        $archive = Join-Path $runtime ('logs/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
        New-Item -ItemType Directory -Path $archive -Force | Out-Null
        foreach ($path in $previous) { Move-Item -LiteralPath $path -Destination $archive }
    }
    Copy-Item -LiteralPath (Join-Path $bin 'pluto-scr.dll') -Destination $runtime -Force

    # bridge.ini tells the bridge where Pluto is and that multiplayer is allowed.
    @('[pluto]',
      "module=$Pluto",
      "speed_ms=$SpeedMs",
      'multiplayer=1',
      "challenge=$([int]$Challenge.IsPresent)") |
        Set-Content -LiteralPath (Join-Path $runtime 'bridge.ini') -Encoding Unicode

    & (Join-Path $bin 'scr-loader.exe') $Game.Id (Join-Path $runtime 'pluto-scr.dll')
    if ($LASTEXITCODE -ne 0) { throw 'Bridge loading failed.' }

    $log = Join-Path $runtime 'bridge.log'
    for ($i = 0; $i -lt 30; $i++) {
        if ((Test-Path -LiteralPath $log) -and (Select-String -LiteralPath $log -SimpleMatch '"result":"MH_OK"' -Quiet)) {
            Write-Host ('[{0:HH:mm:ss}] bridge ready' -f (Get-Date)) -ForegroundColor Green
            return
        }
        Start-Sleep -Milliseconds 200
    }
    throw "Bridge did not initialise. Read $log"
}

# --- single shot -------------------------------------------------------------
if (-not $Watch) {
    $game = Get-GameProcess
    if (-not $game) {
        throw "No running $StarCraft. Enter a room in KK first so it launches the game."
    }
    Invoke-Inject -Game $game
    Write-Section 'Create the room'
    Write-Host '  Multiplayer -> Expansion -> custom room'
    Write-Host '  Game type MUST be Melee, with 2 real players.' -ForegroundColor Yellow
    Write-Host '  Name the room something like "Pluto AI 1v1" so opponents know.'
    if ($Challenge) {
        Write-Host '  Challenge mode: Top vs Bottom / FFA, Pluto alone on one team.'
    }
    Write-Host ''
    Write-Host ("  log: {0}" -f $runtime)
    exit 0
}

# --- watch mode --------------------------------------------------------------
Write-Section 'Watching for StarCraft'
Write-Host '  Re-injects automatically whenever a new game process appears.'
Write-Host '  KK relaunches the game every match, so leave this running.'
Write-Host ("  log: {0}" -f $runtime)
Write-Host '  Ctrl+C to stop.'
Write-Host ''

$lastPid = -1
while ($true) {
    $game = Get-GameProcess
    if ($game -and $game.Id -ne $lastPid) {
        try {
            Invoke-Inject -Game $game
            Write-Host '       -> ready to play'
        } catch {
            Write-Host ('[' + (Get-Date -Format 'HH:mm:ss') + '] injection failed: ' + $_.Exception.Message) -ForegroundColor Red
        }
        # Do not retry the same process: if the bridge crashed inside it,
        # injecting again will not help - the game has to be restarted.
        $lastPid = $game.Id
    }
    Start-Sleep -Seconds $PollSeconds
}
