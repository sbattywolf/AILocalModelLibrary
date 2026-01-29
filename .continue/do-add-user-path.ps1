$add = 'C:\Users\sbatt\AppData\Local\Programs\Ollama'
$current = [Environment]::GetEnvironmentVariable('Path','User')
if ($current -like "*$add*") { Write-Host 'ALREADY_PRESENT' ; exit 0 }
$bk = '.continue/path-backup.txt'
if (-not (Test-Path $bk)) { $current | Out-File -FilePath $bk -Encoding utf8 -Force; Write-Host 'BACKUP_SAVED' } else { Write-Host 'BACKUP_EXISTS' }
$new = if ($current.Length -gt 0) { "$current;$add" } else { $add }
[Environment]::SetEnvironmentVariable('Path',$new,'User')
Write-Host 'ADDED'
# verify
[Environment]::GetEnvironmentVariable('Path','User') -split ';' | Select-String 'Ollama' | ForEach-Object { Write-Host $_.Line }
