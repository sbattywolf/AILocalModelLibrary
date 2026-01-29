$env:OLLAMA_HOME = 'E:\llm-models\.ollama'
Write-Host "OLLAMA_HOME=$env:OLLAMA_HOME"
$exit = 0
try {
  & ollama pull 'qwen2.5-coder:1.5b' 2>&1 | Tee-Object -FilePath .\.continue\install-trace.log -Append
  $exit = $LASTEXITCODE
} catch {
  $_ | Out-File -FilePath .\.continue\install-trace.log -Append -Encoding utf8
  $exit = 1
}
exit $exit
