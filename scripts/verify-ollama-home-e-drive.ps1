# Verify OLLAMA_HOME set to E:\llm-models\.ollama for this process and list models
$env:OLLAMA_HOME = 'E:\llm-models\.ollama'
Write-Host "In-process OLLAMA_HOME= $env:OLLAMA_HOME"

if (Test-Path $env:OLLAMA_HOME) {
    Write-Host "Contents of $env:OLLAMA_HOME:"
    Get-ChildItem -Path $env:OLLAMA_HOME -Force | Select-Object Name,Length | Format-Table -AutoSize
} else {
    Write-Host "Path missing: $env:OLLAMA_HOME"
}

Write-Host 'Running: ollama list (using in-process OLLAMA_HOME)'
& ollama list 2>&1 | Tee-Object -FilePath .\.continue\ollama-list-E-drive.log -Append
