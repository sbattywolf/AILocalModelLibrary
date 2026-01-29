# Detached Ollama serve helper
# Sets OLLAMA_HOME for the process, ensures a logs folder exists, and runs `ollama serve` writing output to a log file.
$env:OLLAMA_HOME = 'E:\llm-models\.ollama'
$logDir = Join-Path $PSScriptRoot '..\logs'    # logs directory next to repo root
$logDirFull = (Resolve-Path -Path $logDir -ErrorAction SilentlyContinue)
if (-not $logDirFull) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir 'ollama-serve.log'
Write-Host "Starting ollama serve; logging to $logFile"
# Run serve and capture both stdout and stderr
& ollama serve 2>&1 | Out-File -FilePath $logFile -Encoding utf8 -Append
