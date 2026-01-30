<#
.SYNOPSIS
  Discover local-llama model files and logs, choose sensible defaults, and
  persist them to a per-user local secrets file `.private/local-llama-session.json`.

.DESCRIPTION
  This helper searches a model root (default: templates/agents/local-llama/models)
  for common GGML/bin model files and searches a logs root (default: logs) for
  relevant log/csv files. It writes a small JSON blob to `.private/local-llama-session.json`
  which is git-ignored by the repository. Intended for per-machine defaults.

.PARAMETER ModelRoot
  Root folder to search for model files.

.PARAMETER LogsRoot
  Root folder to search for logs and monitoring CSVs.

.PARAMETER PersistFile
  Destination file to persist the discovered defaults. Default: .private/local-llama-session.json

.EXAMPLE
  .\set-local-llama-defaults.ps1 -ModelRoot templates/agents/local-llama/models -LogsRoot logs -Confirm
#>
param(
    [string]$ModelRoot = 'templates/agents/local-llama/models',
    [string]$LogsRoot = 'logs',
    [string]$PersistFile = '.private/local-llama-session.json',
    [switch]$Confirm
)

function Write-Log { param($m) $t=(Get-Date).ToString('s'); $line="$t`t$m"; Write-Host $line }

Write-Log "Searching for models under: $ModelRoot"
if (-not (Test-Path $ModelRoot)) { Write-Log "Model root does not exist: $ModelRoot" }

# Common model extensions / patterns
$patterns = @('*.ggml*','*.bin','*.pth','*.safetensors')

$foundModels = @()
foreach ($p in $patterns) {
    $foundModels += Get-ChildItem -Path $ModelRoot -Recurse -ErrorAction SilentlyContinue -Filter $p | Where-Object { -not $_.PSIsContainer }
}

if ($foundModels.Count -gt 0) {
    # prefer models with '13' or '13b' in name, otherwise pick largest
    $prefer = $foundModels | Where-Object { $_.Name -match '13b|13' }
    if ($prefer.Count -gt 0) { $candidate = $prefer | Sort-Object Length -Descending | Select-Object -First 1 }
    else { $candidate = $foundModels | Sort-Object Length -Descending | Select-Object -First 1 }
    $modelPath = $candidate.FullName
    $modelSizeMB = [math]::Round($candidate.Length / 1MB,2)
    Write-Log "Selected model: $modelPath ($modelSizeMB MB)"
} else {
    $modelPath = Join-Path $ModelRoot 'ggml-model.bin'
    $modelSizeMB = 0
    Write-Log "No models found; using default candidate: $modelPath"
}

Write-Log "Scanning logs under: $LogsRoot"
$foundLogs = @()
if (Test-Path $LogsRoot) {
    $foundLogs = Get-ChildItem -Path $LogsRoot -Recurse -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer -and ($_.Extension -in '.log','.csv') }
}

$logsList = $foundLogs | ForEach-Object { @{ path = $_.FullName; sizeMB = [math]::Round($_.Length/1MB,2); modified = $_.LastWriteTime.ToString('s') } }
Write-Log ("Found {0} log files" -f ($logsList.Count))

# Ensure .private exists and is git-ignored
if (-not (Test-Path '.private')) { New-Item -ItemType Directory -Path '.private' -Force | Out-Null; Write-Log 'Created .private directory' }

try { $resolvedModel = Resolve-Path -Path $modelPath -ErrorAction SilentlyContinue } catch { $resolvedModel = $null }
try { $resolvedModelRoot = Resolve-Path -Path $ModelRoot -ErrorAction SilentlyContinue } catch { $resolvedModelRoot = $null }
try { $resolvedLogsRoot = Resolve-Path -Path $LogsRoot -ErrorAction SilentlyContinue } catch { $resolvedLogsRoot = $null }

$modelPathResolved = if ($resolvedModel) { $resolvedModel.Path } else { $modelPath }
$modelRootResolved = if ($resolvedModelRoot) { $resolvedModelRoot.Path } else { $ModelRoot }
$logsRootResolved = if ($resolvedLogsRoot) { $resolvedLogsRoot.Path } else { $LogsRoot }

$data = [ordered]@{
  model = @{ path = $modelPathResolved; sizeMB = $modelSizeMB }
  logs = $logsList
  discoveredAt = (Get-Date).ToString('o')
  modelRoot = $modelRootResolved
  logsRoot = $logsRootResolved
}

$json = $data | ConvertTo-Json -Depth 6

if ($Confirm) {
  Write-Log "Writing discovered defaults to: $PersistFile"
  $persistDir = Split-Path -Path $PersistFile -Parent
  if ($persistDir -and -not (Test-Path $persistDir)) { New-Item -ItemType Directory -Path $persistDir -Force | Out-Null }
  $tmp = "$PersistFile.tmp"
  $json | Set-Content -Path $tmp -Encoding UTF8
  # Atomic move
  Move-Item -Path $tmp -Destination $PersistFile -Force
  Write-Log "Wrote $PersistFile"
} else {
  Write-Log "Dry run; pass -Confirm to persist to $PersistFile"
  Write-Log $json
}

exit 0
