$m=[Environment]::GetEnvironmentVariable('Path','Machine')
$matches = $m -split ';' | Select-String -Pattern 'Ollama' -SimpleMatch
if ($matches) { $matches | ForEach-Object { $_.Line } } else { Write-Host 'NO_MATCH'; $m -split ';' | ForEach-Object { Write-Host $_ } }