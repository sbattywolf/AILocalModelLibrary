$all = Get-ChildItem -Recurse -File | Where-Object { $_.FullName -notmatch '\\.git\\' -and $_.FullName -notmatch '\\artifacts\\' }
$countAll = $all.Count
$ps = $all | Where-Object { $_.Extension -ieq '.ps1' }
$json = $all | Where-Object { $_.Extension -ieq '.json' }
Write-Host ('Total files: {0}' -f $countAll)
Write-Host ('PS1 files: {0}' -f $ps.Count)
Write-Host ('JSON files: {0}' -f $json.Count)
Write-Host 'Measuring parse time for all PS1 files (PowerShell parser)...'
$psPaths = $ps | Select-Object -ExpandProperty FullName
$t = [diagnostics.stopwatch]::StartNew()
foreach ($f in $psPaths) { $null1 = $null; $null2 = $null; [Management.Automation.Language.Parser]::ParseFile($f,[ref]$null1,[ref]$null2) | Out-Null }
$t.Stop()
Write-Host ('Parse time (ms): {0}' -f $t.ElapsedMilliseconds)
