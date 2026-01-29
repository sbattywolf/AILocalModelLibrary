Write-Output 'Stopping PID 8864 (graceful)'
try { Stop-Process -Id 8864 -ErrorAction SilentlyContinue } catch { }
Start-Sleep -Seconds 1
if (Get-Process -Id 8864 -ErrorAction SilentlyContinue) { Write-Output 'PID 8864 still running, forcing stop'; Stop-Process -Id 8864 -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 1
Write-Output 'Netstat after stop:'
$lines = netstat -ano 2>$null | Select-String ':11434'
if (-not $lines) { Write-Output 'No listener on 11434' } else { $lines | ForEach-Object { $_.Line.Trim() } }

Write-Output 'Starting new role-labeled serve for SimRacingAgent'
& powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-ollama-role.ps1 -Role SimRacingAgent -Action serve -LogDir .\logs
Start-Sleep -Seconds 2
Write-Output 'Recent mapping entries:'
Get-Content -Path .\.continue\ollama-processes.json -Raw | ConvertFrom-Json | Select-Object -Last 2 | ConvertTo-Json -Depth 4
Write-Output 'Tail of serve log:'
Get-ChildItem -Path .\logs -Filter 'ollama-SimRacingAgent-*' | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | ForEach-Object { Get-Content -Path $_.FullName -Tail 40 -ErrorAction SilentlyContinue }
