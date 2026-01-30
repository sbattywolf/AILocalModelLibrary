$tempDir = Join-Path $env:TEMP ([Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tempDir | Out-Null
$mappingPath = Join-Path $tempDir 'mapping.json'
$telemetryPath = Join-Path $tempDir 'telemetry.log'
$ping = Start-Process -FilePath ping -ArgumentList '-t','127.0.0.1' -PassThru
$mapping = ,(@{ name='ops-smoke-sampler'; pid=$ping.Id }) | ConvertTo-Json -Compress
Set-Content -Path $mappingPath -Value $mapping -Encoding UTF8
$scriptPath = (Resolve-Path .\scripts\agent-runtime-monitor.ps1).Path
$psArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$scriptPath,'-MappingFile',$mappingPath,'-IntervalSeconds','1','-TelemetryFile',$telemetryPath)
$proc = Start-Process -FilePath powershell -ArgumentList $psArgs -WorkingDirectory $tempDir -PassThru
Start-Sleep -Seconds 5
Write-Output "Proc Id: $($proc.Id)"
Write-Output "Ping Id: $($ping.Id)"
Write-Output "Telemetry exists: $(Test-Path $telemetryPath)"
if (Test-Path $telemetryPath) { Get-Content $telemetryPath }
Try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } Catch { }
Try { Stop-Process -Id $ping.Id -Force -ErrorAction SilentlyContinue } Catch { }
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
