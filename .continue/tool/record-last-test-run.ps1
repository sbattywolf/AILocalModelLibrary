param(
    [string[]]$Tests = @('unit'),
    [ValidateSet('passed','failed','partial','unknown')][string]$Status = 'unknown',
    [int]$DurationSeconds = 0,
    [string]$ResultsPath = '.continue/test-results.json'
)

$out = [PSCustomObject]@{
    timestamp = (Get-Date).ToString('o')
    tests = $Tests
    status = $Status
    durationSeconds = $DurationSeconds
    resultsPath = $ResultsPath
}

if (-not (Test-Path '.continue')) { New-Item -ItemType Directory -Path '.continue' -Force | Out-Null }
$out | ConvertTo-Json -Depth 5 | Set-Content -Path '.continue/last_test_run.json' -Encoding UTF8
Write-Host "Wrote .continue/last_test_run.json (status=$Status, tests=$($Tests -join ','))"
exit 0
