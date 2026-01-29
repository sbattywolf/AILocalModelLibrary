<#
.SYNOPSIS
  Start an Ollama process with a user-supplied `Role` and record PID -> role mapping.

.DESCRIPTION
  Launches `ollama serve` or `ollama run` in a detached hidden PowerShell process,
  sets `OLLAMA_HOME` and `OLLAMA_ROLE` environment variables for that process,
  captures the started PID and records metadata in `.continue/ollama-processes.json`.

.PARAMETER Role
  A short role name to identify the process (e.g. "ingest", "api", "worker").

.PARAMETER Action
  "serve" or "run". If "run", a `-Model` should be provided.

.PARAMETER Model
  Model id to run (used when `-Action run`).

.PARAMETER Prompt
  Prompt text to supply for a single-shot `run` invocation.

.PARAMETER KeepAlive
  Keep model loaded duration (e.g. '1h'). Passed to `ollama run --keepalive`.

.PARAMETER LogDir
  Directory to place logs. Defaults to `logs` at repo root.

.PARAMETER OllamaHome
  Path to Ollama store. Defaults to `E:\llm-models\.ollama`.
#>
param(
  [Parameter(Mandatory=$true)] [string]$Role,
  [ValidateSet('serve','run')] [string]$Action = 'serve',
  [string]$Model,
  [string]$Prompt,
  [string]$KeepAlive = '1h',
  [string]$LogDir = '',
  [string]$OllamaHome = 'E:\llm-models\.ollama'
)

# Resolve script dir safely for defaults
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $ScriptDir) { $ScriptDir = Get-Location }
if (-not $LogDir -or $LogDir -eq '') { $LogDir = Join-Path $ScriptDir '..\logs' }

function Write-Log { param($m) $t=(Get-Date).ToString('s'); $line="$t`t$m"; Add-Content -Path '.\.continue\install-trace.log' -Value $line -ErrorAction SilentlyContinue }

# Ensure log dir
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$logFile = Join-Path $LogDir ("ollama-{0}-{1}.log" -f $Role,$timestamp)

# Build the command that will run inside the detached PowerShell process
# This sets OLLAMA_HOME and OLLAMA_ROLE for that process and then runs ollama
if ($Action -eq 'serve') {
  $innerCmd = ('$env:OLLAMA_HOME = ''{0}''; $env:OLLAMA_ROLE = ''{1}''; ollama serve 2>&1 | Out-File -FilePath ''{2}'' -Encoding utf8 -Append' -f $OllamaHome, $Role, $logFile)
} else {
    if (-not $Model) { throw 'Model is required when Action is "run"' }
    $promptArg = ''
    if ($Prompt) { $escaped = $Prompt.Replace("'","''"); $promptArg = " '$escaped'" }
    $keepArg = ''
    if ($KeepAlive) { $keepArg = " --keepalive $KeepAlive" }
    $innerCmd = ('$env:OLLAMA_HOME = ''{0}''; $env:OLLAMA_ROLE = ''{1}''; ollama run {2}{3}{4} --format json 2>&1 | Out-File -FilePath ''{5}'' -Encoding utf8 -Append' -f $OllamaHome, $Role, $Model, $promptArg, $keepArg, $logFile)
}

# Start the detached process
$psArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-Command',$innerCmd)
$proc = Start-Process -FilePath powershell -ArgumentList $psArgs -PassThru
Start-Sleep -Milliseconds 300
if (-not $proc) { Write-Log "Failed to start process for role $Role"; throw 'Start-Process failed' }
$entry = [PSCustomObject]@{
    PID = $proc.Id
    Role = $Role
    Action = $Action
    Model = $Model
    Prompt = if ($Prompt) { ($Prompt -replace "\r\n","\n") } else { $null }
    LogFile = $logFile
    StartedAt = (Get-Date).ToString('o')
}

# Persist mapping to .continue/ollama-processes.json (atomic write)
$mapFile = '.\.continue\ollama-processes.json'
$continueDir = Split-Path -Parent $mapFile
if (-not (Test-Path $continueDir)) { New-Item -ItemType Directory -Path $continueDir -Force | Out-Null }
$maps = @()
if (Test-Path $mapFile) {
  try {
    $raw = Get-Content -Path $mapFile -Raw -ErrorAction Stop
    if ($raw -and $raw.Trim() -ne '') {
      $maps = $raw | ConvertFrom-Json -ErrorAction Stop
      if ($maps -and -not ($maps -is [System.Array])) { $maps = @($maps) }
    } else {
      $maps = @()
    }
  } catch { $maps = @() }
}
$maps += $entry
try {
  $tmp = [System.IO.Path]::GetTempFileName()
  $maps | ConvertTo-Json -Depth 4 | Out-File -FilePath $tmp -Encoding utf8
  Move-Item -Path $tmp -Destination $mapFile -Force
  Write-Log "Registered process PID $($proc.Id) as role '$Role' (action=$Action) -> $mapFile"
} catch { Write-Log "Failed to write mapping file: $($_ | Out-String)" }

Write-Host "Started Ollama (PID=$($proc.Id)) as role '$Role'. Log: $logFile"
Write-Host "Mapping saved to: $mapFile"
exit 0
