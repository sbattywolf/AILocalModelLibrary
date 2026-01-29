# Sets OLLAMA_HOME to the user default, runs the checker, then lists local Ollama models
$env:OLLAMA_HOME = Join-Path $env:USERPROFILE 'AppData\Local\Programs\Ollama'
Write-Host "Using OLLAMA_HOME: $env:OLLAMA_HOME"

# Run checker (non-interactive)
.\scripts\check-ollama-home.ps1 -VerboseOutput

# Run ollama list and capture output
Write-Host 'Running: ollama list'
& ollama list 2>&1 | Tee-Object -FilePath .\.continue\ollama-list.log -Append
