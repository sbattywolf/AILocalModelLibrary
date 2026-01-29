<#
.SYNOPSIS
  Set and optionally persist OLLAMA_HOME for this machine.

.DESCRIPTION
  Creates the target directory if needed, sets the `OLLAMA_HOME` environment
  variable for the current session and optionally persists it for the user
  via `setx`. Designed for PS5.1 compatibility.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$Path,
    [switch]$Persist,
    [switch]$CreateDirs
)

function Write-Log { param($m) $t=(Get-Date).ToString('s'); $line="$t`t$m"; Write-Host $line; try { Add-Content -Path '.\.continue\install-trace.log' -Value $line -ErrorAction SilentlyContinue } catch {} }

# Normalize path
$target = [System.IO.Path]::GetFullPath($Path)
Write-Log "set-ollama-home: requested path $target"

if ($CreateDirs -or -not (Test-Path $target)) {
    try {
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        Write-Log "Created directory $target"
    } catch {
        $err = $_ | Out-String
        Write-Log ("Failed to create directory {0}: {1}" -f $target, $err)
        exit 1
    }
} else {
    Write-Log "Directory already exists: $target"
}

# Ensure models subdir exists
$modelsDir = Join-Path $target 'models'
if (-not (Test-Path $modelsDir)) {
    try {
        New-Item -ItemType Directory -Path $modelsDir -Force | Out-Null
        Write-Log "Created models directory $modelsDir"
    } catch {
        $err = $_ | Out-String
        Write-Log ("Failed to create models dir {0}: {1}" -f $modelsDir, $err)
    }
} else {
    Write-Log "Models directory exists: $modelsDir"
}

# Set for current session
$env:OLLAMA_HOME = $target
Write-Log "Set OLLAMA_HOME for session to: $env:OLLAMA_HOME"

if ($Persist) {
    try {
        & setx OLLAMA_HOME "$target" | Out-Null
        Write-Log "Persisted OLLAMA_HOME via setx. Note: new sessions will see the change."
    } catch {
        $err = $_ | Out-String
        Write-Log ("Failed to persist OLLAMA_HOME: {0}" -f $err)
    }
} else {
    Write-Log "Did not persist OLLAMA_HOME (pass -Persist to persist)."
}

Write-Log "set-ollama-home completed."
exit 0
