Write-Host 'Searching for token-like strings (ghp_) in working tree...'
$hits = Get-ChildItem -Path . -Recurse -File -ErrorAction SilentlyContinue | Select-String -Pattern 'ghp_[A-Za-z0-9_]{36}' -List
if ($hits) {
  foreach ($h in $hits) { Write-Host ("FOUND: {0}:{1} => {2}" -f $h.Path,$h.LineNumber,$h.Line.Trim()) }
} else { Write-Host 'No ghp_ tokens found in working tree.' }

Write-Host 'Clearing GITHUB_TOKEN from current session...'
Remove-Item Env:GITHUB_TOKEN -ErrorAction SilentlyContinue

Write-Host 'Clearing persistent GITHUB_TOKEN (User and Machine)...'
try { [Environment]::SetEnvironmentVariable('GITHUB_TOKEN',$null,'User'); Write-Host 'Cleared User env' } catch { Write-Host "Failed to clear User env: $_" }
try { [Environment]::SetEnvironmentVariable('GITHUB_TOKEN',$null,'Machine'); Write-Host 'Cleared Machine env' } catch { Write-Host "Failed to clear Machine env: $_" }

Write-Host 'Deleting .continue\hkcu-environment.log if present...'
$path = Join-Path -Path (Get-Location) -ChildPath '.continue\hkcu-environment.log'
if (Test-Path $path) {
  try { Remove-Item -LiteralPath $path -Force -ErrorAction Stop; Write-Host "Deleted $path" } catch { Write-Host ("Failed to delete {0}: {1}" -f $path, $_) }
} else { Write-Host 'No .continue/hkcu-environment.log found on disk' }
