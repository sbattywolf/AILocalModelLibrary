<#
.SYNOPSIS
  Dot-sourceable helper to load per-machine local-llama session defaults.

.DESCRIPTION
  Dot-source this script in your current PowerShell session to export
  `MODEL_PATH` and `LOCAL_LLAMA_LOGS` environment variables from
  `.private/local-llama-session.json`.

.USAGE
  . .\load-local-llama-session.ps1

.NOTES
  - The script is intentionally designed to be dot-sourced so variables
    persist in the calling shell.
#>

param()

function _Write-Note { param($m) $t=(Get-Date).ToString('s'); Write-Host "$t`t$m" }

if ($MyInvocation.ExpectingInput -or -not $MyInvocation.Line) {
    # allow dot-sourcing; no-op if not
}

$sessionFile = Join-Path (Get-Location) '.private/local-llama-session.json'
if (-not (Test-Path $sessionFile)) {
    _Write-Note "Session file not found: $sessionFile. Run the discovery helper to create it."
    return
}

try {
    $session = Get-Content -Raw -Path $sessionFile | ConvertFrom-Json -ErrorAction Stop
} catch {
    _Write-Note "Failed to read session file: $_"
    return
}

if ($session.model -and $session.model.path) {
    $modelPath = $session.model.path -as [string]
    if ($modelPath) {
        $env:MODEL_PATH = $modelPath
        _Write-Note "Set MODEL_PATH=$env:MODEL_PATH"
    }
}

if ($session.logsRoot) {
    $env:LOCAL_LLAMA_LOGS = $session.logsRoot
    _Write-Note "Set LOCAL_LLAMA_LOGS=$env:LOCAL_LLAMA_LOGS"
} elseif ($session.logs -and $session.logs.Count -gt 0) {
    # join top 5 logs into semicolon-separated list
    $list = $session.logs | Select-Object -First 5 | ForEach-Object { $_.path }
    $env:LOCAL_LLAMA_LOGS = ($list -join ';')
    _Write-Note "Set LOCAL_LLAMA_LOGS to first 5 log paths"
}

# export short helper variables for convenience
if ($env:MODEL_PATH) { Set-Variable -Name MODEL_PATH -Value $env:MODEL_PATH -Scope Global -Force }
if ($env:LOCAL_LLAMA_LOGS) { Set-Variable -Name LOCAL_LLAMA_LOGS -Value $env:LOCAL_LLAMA_LOGS -Scope Global -Force }

_Write-Note "Session load complete. Use `$env:MODEL_PATH` and `$env:LOCAL_LLAMA_LOGS`."

return
