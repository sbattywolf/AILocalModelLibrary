<#
.SYNOPSIS
  Template installer step: configure Ollama model storage (OLLAMA_HOME).

.DESCRIPTION
  Creates and/or verifies a model store folder, sets `OLLAMA_HOME` for the
  session, and optionally persists it for the current user. Intended to be
  copied or invoked by higher-level installer flows.

.PARAMETER Path
  Path to the Ollama store (example: E:\llm-models\.ollama)

.PARAMETER Persist
  Persist the setting for the current user using `setx` (requires new shell).

.PARAMETER CreateDirs
  Create folders if missing.
#>
param(
    [Parameter(Mandatory=$true)] [string]$Path,
    [switch]$Persist,
    [switch]$CreateDirs
)

function Write-Log { param($m) $t=(Get-Date).ToString('s'); $line="$t`t$m"; Write-Host $line; try { Add-Content -Path '.\.continue\install-trace.log' -Value $line -ErrorAction SilentlyContinue } catch {} }

$target = [System.IO.Path]::GetFullPath($Path)
Write-Log "model-store: target path $target"

if ($CreateDirs -or -not (Test-Path $target)) {
    try { New-Item -ItemType Directory -Path $target -Force | Out-Null; Write-Log "Created $target" } catch { $err = $_ | Out-String; Write-Log ("Failed to create {0}: {1}" -f $target, $err); exit 1 }
} else { Write-Log "Path exists: $target" }

$modelsDir = Join-Path $target 'models'
if (-not (Test-Path $modelsDir)) {
    try { New-Item -ItemType Directory -Path $modelsDir -Force | Out-Null; Write-Log "Created models dir: $modelsDir" } catch { $err = $_ | Out-String; Write-Log ("Failed to create models dir {0}: {1}" -f $modelsDir, $err); exit 1 }
} else { Write-Log "Models dir exists: $modelsDir" }

# Set for session
$env:OLLAMA_HOME = $target
Write-Log "Set OLLAMA_HOME=$env:OLLAMA_HOME for session"

if ($Persist) {
    try { & setx OLLAMA_HOME "$target" | Out-Null; Write-Log 'Persisted OLLAMA_HOME via setx (new shells will see it)' } catch { $err = $_ | Out-String; Write-Log ("Persist failed: {0}" -f $err) }
} else { Write-Log 'Did not persist OLLAMA_HOME (pass -Persist to persist)' }

Write-Log 'model-store template completed.'
exit 0
