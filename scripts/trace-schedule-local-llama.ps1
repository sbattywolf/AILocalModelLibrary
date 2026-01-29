<#
Simple loop to take periodic traces using `monitor-local-llama.ps1` and append timestamps.
Run as background job or schedule with Task Scheduler. Example: every 60 seconds take 30s sample.
#>
param(
  [int]$IntervalSeconds = 60,
  [int]$SampleSeconds = 30
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$monitor = Join-Path $scriptDir 'monitor-local-llama.ps1'
if (-not (Test-Path $monitor)) { Write-Error "Missing $monitor"; exit 2 }

Write-Host "Starting periodic trace: interval=${IntervalSeconds}s sample=${SampleSeconds}s"
while ($true) {
    & $monitor -SampleIntervalSeconds 1 -SampleCount $SampleSeconds
    Start-Sleep -Seconds $IntervalSeconds
}
