$tempDir = Join-Path $env:TEMP ([Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tempDir | Out-Null
$mappingPath = Join-Path $tempDir 'mapping.json'
$telemetryPath = Join-Path $tempDir 'telemetry.log'
$ping = Start-Process -FilePath ping -ArgumentList '-t','127.0.0.1' -PassThru
$mapping = ,(@{ name='ops-smoke-sampler'; pid=$ping.Id }) | ConvertTo-Json -Compress
Set-Content -Path $mappingPath -Value $mapping -Encoding UTF8
$scriptPath = (Resolve-Path .\scripts\agent-runtime-monitor.ps1).Path
$job = Start-Job -ScriptBlock { param($s,$m,$t) & $s -MappingFile $m -IntervalSeconds 1 -TelemetryFile $t } -ArgumentList $scriptPath,$mappingPath,$telemetryPath
Start-Sleep -Seconds 5
Write-Output "Job State: $($job.State)"
Write-Output "Ping Id: $($ping.Id)"
Write-Output "Telemetry exists: $(Test-Path $telemetryPath)"
if (Test-Path $telemetryPath) { Get-Content $telemetryPath }
Get-Job | Stop-Job -Force | Out-Null
Remove-Job -State * -Force -ErrorAction SilentlyContinue
Try { Stop-Process -Id $ping.Id -Force -ErrorAction SilentlyContinue } Catch { }
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
