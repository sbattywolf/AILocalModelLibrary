# Reproduce start->inspect->stop->inspect mapping sequence for CI role
$map = '.\.continue\ollama-processes.json'
if (Test-Path $map) { Remove-Item $map -Force }
& .\scripts\start-ollama-role.ps1 -Role ci-mapping -Action serve -LogDir .\logs
Start-Sleep -Seconds 1
Write-Host 'After start:'
if (Test-Path $map) { Get-Content $map -Raw | Write-Host } else { Write-Host '(no mapping file)' }
& .\scripts\stop-ollama-role.ps1 -Role ci-mapping
Start-Sleep -Seconds 1
Write-Host 'After stop:'
if (Test-Path $map) { Get-Content $map -Raw | Write-Host } else { Write-Host '(no mapping file)' }
