$files=@()
$candidates = @('.\.continue\install-trace.log','.\.continue\TestRunner-output.txt','.\.continue\path-backup.txt','.\.continue\system-path-backup.txt')
foreach ($f in $candidates) { if (Test-Path $f) { $files += (Resolve-Path $f).Path } }
if (Test-Path '.\.continue\tempTest\models') { $files += (Get-ChildItem '.\.continue\tempTest\models' -File | ForEach-Object { $_.FullName }) }
if ($files.Count -eq 0) { Write-Host 'NO_TRACE_FILES_FOUND' ; exit 1 }
Compress-Archive -Path $files -DestinationPath '.\.continue\traces.zip' -Force
Write-Host 'ZIPPED:' (Get-Item '.\.continue\traces.zip').FullName
