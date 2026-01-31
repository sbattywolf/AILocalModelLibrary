Import-Module Pester -MinimumVersion '5.0' -ErrorAction Stop
$r = Invoke-Pester -Path .\tests\ -PassThru

# Build a JSON-serializable summary to avoid non-string dictionary keys in the full Pester object
$tests = $r.Tests | ForEach-Object {
	[PSCustomObject]@{
		Name = $_.Name
		FullName = $_.FullName
		Result = ($_.Result -as [string])
		DurationSeconds = if ($_.Duration) { [math]::Round($_.Duration.TotalSeconds, 3) } else { $null }
		Error = if ($_.Error) { ($_.Error | Out-String).Trim() } else { $null }
		Message = if ($_.Message) { ($_.Message | Out-String).Trim() } else { $null }
	}
}

$summary = [PSCustomObject]@{
	Timestamp = (Get-Date).ToString('o')
	Passed = ($r.PassedCount -as [int])
	Failed = ($r.FailedCount -as [int])
	Skipped = ($r.SkippedCount -as [int])
	Inconclusive = ($r.InconclusiveCount -as [int])
	NotRun = ($r.NotRunCount -as [int])
	Total = ($tests | Measure-Object).Count
	DurationSeconds = if ($r.TotalTime) { [math]::Round($r.TotalTime.TotalSeconds, 3) } else { $null }
	Tests = $tests
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -Path .\.continue\pester_full_result.json -Encoding UTF8

$tests | Where-Object { $_.Result -eq 'Failed' } | ConvertTo-Json -Depth 6 | Set-Content -Path .\.continue\pester_failed_tests.json -Encoding UTF8

Write-Output ("FAILED:$($summary.Failed)")
