<#
.SYNOPSIS
  Start a local-llama process (local binary) or delegate to Ollama and record PID -> role mapping.

.DESCRIPTION
  Launches a local LLM process (example CLI `llama-cli`) or runs via `ollama` if requested.
  Enforces a maximum of 3 concurrent agents by default to avoid model conflicts.
  Writes mappings to `.continue/local-llama-processes.json` atomically.
#>
param(
  [Parameter(Mandatory=$true)] [string]$Role,
  [ValidateSet('serve','run')] [string]$Action = 'serve',
  [string]$Model,
  [string]$Prompt,
  [int]$MaxAgents = 3,
  [switch]$UseOllama,
  [switch]$PullToOllama,
  [string]$LogDir = '',
  [string]$LocalCmd = 'llama-cli',
  [string]$OllamaHome = 'E:\llm-models\.ollama'
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $LogDir -or $LogDir -eq '') { $LogDir = Join-Path $ScriptDir '..\logs' }
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log { param($m) $t=(Get-Date).ToString('s'); $line="$t`t$m"; Add-Content -Path '.\.continue\local-llama-trace.log' -Value $line -ErrorAction SilentlyContinue }

# mapping file
$mapFile = '.\.continue\local-llama-processes.json'
if (-not (Test-Path (Split-Path -Parent $mapFile))) { New-Item -ItemType Directory -Path (Split-Path -Parent $mapFile) -Force | Out-Null }

# Load existing mappings and count live processes
$maps = @()
if (Test-Path $mapFile) {
  try { $maps = Get-Content -Path $mapFile -Raw | ConvertFrom-Json -ErrorAction Stop } catch { $maps = @() }
}
$aliveCount = 0
foreach ($m in $maps) { if ($m.PID -and (Get-Process -Id $m.PID -ErrorAction SilentlyContinue)) { $aliveCount++ } }
if ($aliveCount -ge $MaxAgents) { Write-Host "Too many agents running ($aliveCount). Max allowed: $MaxAgents"; exit 2 }

# Decide run mode: Ollama or local CLI
if ($UseOllama) {
  if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) { Write-Host 'Ollama CLI not found; install or remove -UseOllama'; exit 3 }
  if ($PullToOllama -and $Model) {
    Write-Log "Attempting to pull $Model into Ollama store"
    try { & ollama pull $Model } catch { Write-Log "ollama pull failed: $_" }
  }

  if ($Action -eq 'serve') {
    $inner = "ollama serve 2>&1 | Out-File -FilePath '{0}' -Encoding utf8 -Append" -f (Join-Path $LogDir ("local-llama-{0}.log" -f $Role))
  } else {
    if (-not $Model) { throw 'Model is required when Action is "run"' }
    $promptArg = ''
    if ($Prompt) { $escaped = $Prompt.Replace("'","''"); $promptArg = " '$escaped'" }
    $inner = "ollama run {0}{1} --format json 2>&1 | Out-File -FilePath '{2}' -Encoding utf8 -Append" -f $Model, $promptArg, (Join-Path $LogDir ("local-llama-{0}.log" -f $Role))
  }
  $psArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-Command',$inner)
  $proc = Start-Process -FilePath powershell -ArgumentList $psArgs -PassThru

} else {
  # local CLI mode
  if ($Action -eq 'serve') {
    $innerCmd = "$LocalCmd serve 2>&1 | Out-File -FilePath '{0}' -Encoding utf8 -Append" -f (Join-Path $LogDir ("local-llama-{0}.log" -f $Role))
  } else {
    if (-not $Model) { throw 'Model is required when Action is "run"' }
    $promptArg = ''
    if ($Prompt) { $escaped = $Prompt.Replace("'","''"); $promptArg = " --prompt '$escaped'" }
    $innerCmd = "$LocalCmd run --model {0}{1} 2>&1 | Out-File -FilePath '{2}' -Encoding utf8 -Append" -f $Model, $promptArg, (Join-Path $LogDir ("local-llama-{0}.log" -f $Role))
  }
  $psArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-Command',$innerCmd)
  $proc = Start-Process -FilePath powershell -ArgumentList $psArgs -PassThru
}

Start-Sleep -Milliseconds 300
if (-not $proc) { Write-Log "Failed to start process for role $Role"; throw 'Start-Process failed' }

$entry = [PSCustomObject]@{
  PID = $proc.Id
  Role = $Role
  Action = $Action
  Model = $Model
  LocalCmd = $LocalCmd
  UseOllama = $UseOllama.IsPresent
  LogFile = (Join-Path $LogDir ("local-llama-{0}.log" -f $Role))
  StartedAt = (Get-Date).ToString('o')
}

$maps = @($maps)  # ensure array
$maps += $entry
try {
  $tmp = [System.IO.Path]::GetTempFileName()
  $maps | ConvertTo-Json -Depth 6 | Out-File -FilePath $tmp -Encoding utf8
  Move-Item -Path $tmp -Destination $mapFile -Force
  Write-Log "Registered process PID $($proc.Id) as role '$Role' -> $mapFile"
} catch { Write-Log "Failed to write mapping file: $($_ | Out-String)" }

Write-Host "Started local-llama (PID=$($proc.Id)) as role '$Role'. Log: $($entry.LogFile)"
Write-Host "Mapping saved to: $mapFile"
exit 0
