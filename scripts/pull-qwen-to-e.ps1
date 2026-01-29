# Pull qwen2.5-coder:1.5b into the E:\llm-models\.ollama store for this process
$env:OLLAMA_HOME = 'E:\llm-models\.ollama'
Write-Host "Using OLLAMA_HOME: $env:OLLAMA_HOME"
Write-Host 'Starting pull: qwen2.5-coder:1.5b'
& ollama pull qwen2.5-coder:1.5b 2>&1 | Tee-Object -FilePath .\.continue\ollama-pull-qwen2.5.log -Append
