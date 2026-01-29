$log = ".\.continue\ollama-quick-setup.log"
if (-not (Test-Path ".\.continue")) { New-Item -ItemType Directory -Path ".\.continue" | Out-Null }
"=== START $(Get-Date) ===" | Tee-Object -FilePath $log -Append
$env:OLLAMA_HOME = 'E:\llm-models\.ollama'
"OLLAMA_HOME=$env:OLLAMA_HOME" | Tee-Object -FilePath $log -Append
try { & ollama version 2>&1 | Tee-Object -FilePath $log -Append } catch { "ollama version failed: $_" | Tee-Object -FilePath $log -Append }
try { & ollama list 2>&1 | Tee-Object -FilePath $log -Append } catch { "ollama list failed: $_" | Tee-Object -FilePath $log -Append }
try { & ollama run qwen2.5-coder:1.5b --format json --hidethinking "Hello, this is a quick test." 2>&1 | Tee-Object -FilePath $log -Append } catch { "ollama run failed: $_" | Tee-Object -FilePath $log -Append }
"=== END $(Get-Date) ===" | Tee-Object -FilePath $log -Append
Get-Content -Path $log -Tail 200
