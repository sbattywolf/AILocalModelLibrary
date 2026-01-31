Param(
    [int]$DurationSeconds = 600,
    [int]$IntervalSeconds = 5
)

Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$tempDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tempDir | Out-Null

$mappingPath = Join-Path $tempDir 'mapping.json'
$telemetryPath = Join-Path $tempDir 'telemetry.log'
$monitorLog = Join-Path $tempDir 'monitor.log'
$runtimeLog = Join-Path $tempDir 'runtime.log'

Write-Output "Long run temp dir: $tempDir"

# start dummy process to sample
$ping = Start-Process -FilePath ping -ArgumentList '-t','127.0.0.1' -PassThru
Start-Sleep -Milliseconds 200

# write mapping
$agents = @(
    @{ name = 'long-run-dummy'; pid = $ping.Id; primaryRole = 'worker' }
)
($agents | ConvertTo-Json -Compress) | Set-Content -Path $mappingPath -Encoding UTF8

# resolve scripts
$monitorScript = (Resolve-Path "$scriptRoot\monitor-agents-epic.ps1").Path
$runtimeScript = (Resolve-Path "$scriptRoot\agent-runtime-monitor.ps1").Path

Write-Output "Starting monitor (DryRun) and runtime sampler. Duration: $DurationSeconds s"

# start monitor (DryRun)
$monitorArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$monitorScript,'-MappingFile',$mappingPath,'-IntervalSeconds', $IntervalSeconds, '-DryRun')
$monitorProc = Start-Process -FilePath powershell -ArgumentList $monitorArgs -WorkingDirectory $tempDir -PassThru

# start runtime sampler
$runtimeArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$runtimeScript,'-MappingFile',$mappingPath,'-IntervalSeconds',$IntervalSeconds,'-TelemetryFile',$telemetryPath)
$runtimeProc = Start-Process -FilePath powershell -ArgumentList $runtimeArgs -WorkingDirectory $tempDir -PassThru

# wait for duration
Start-Sleep -Seconds $DurationSeconds

Write-Output "Run complete; stopping processes and collecting artifacts"

Try { if ($monitorProc -and -not $monitorProc.HasExited) { Stop-Process -Id $monitorProc.Id -Force -ErrorAction SilentlyContinue } } Catch {}
Try { if ($runtimeProc -and -not $runtimeProc.HasExited) { Stop-Process -Id $runtimeProc.Id -Force -ErrorAction SilentlyContinue } } Catch {}
Try { if ($ping -and -not $ping.HasExited) { Stop-Process -Id $ping.Id -Force -ErrorAction SilentlyContinue } } Catch {}

# copy artifacts into workspace .continue/long-run-<ts>
$ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
$dest = Join-Path (Resolve-Path "$scriptRoot\..\.continue").Path "long-run-$ts"
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }
Copy-Item -Path $mappingPath -Destination (Join-Path $dest 'mapping.json') -Force -ErrorAction SilentlyContinue
if (Test-Path $telemetryPath) { Copy-Item -Path $telemetryPath -Destination (Join-Path $dest 'telemetry.log') -Force -ErrorAction SilentlyContinue }

Write-Output "Artifacts copied to: $dest"
Write-Output "Done"
