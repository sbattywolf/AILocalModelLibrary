$map = '.\\.continue\\ollama-processes.json'
if (Test-Path $map) { Remove-Item $map -Force }
& .\\scripts\\start-ollama-role.ps1 -Role ci-kill -Action serve -LogDir .\\logs
Start-Sleep -Seconds 1
Write-Host 'After start:'
if (Test-Path $map) { Get-Content $map -Raw | Write-Host } else { Write-Host '(no mapping file)' }
 $maps = @()
 if (Test-Path $map) { $maps = Get-Content $map -Raw | ConvertFrom-Json }
 if (-not $maps) { $maps = @() }
 if ($maps -and -not ($maps -is [System.Array])) { $maps = @($maps) }
 $pidVal = $null
 if ($maps.Count -gt 0) { $pidVal = $maps[0].PID }
 Write-Host "Started PID: $pidVal"
 & .\\scripts\\kill-ollama-role.ps1 -Role ci-kill -GraceSeconds 1
Start-Sleep -Seconds 1
Write-Host 'After kill mapping:'
if (Test-Path $map) { Get-Content $map -Raw | Write-Host } else { Write-Host '(no mapping file)' }
if ($pidVal -and (Get-Process -Id $pidVal -ErrorAction SilentlyContinue)) { Write-Host 'PID still running' } else { Write-Host 'PID not running' }
