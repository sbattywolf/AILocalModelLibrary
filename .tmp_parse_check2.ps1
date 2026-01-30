$errors = [ref]@()
[void][System.Management.Automation.Language.Parser]::ParseFile('e:\Workspaces\Git\AILocalModelLibrary\scripts\monitor-agents-epic.ps1',[ref]$null,$errors)
if ($errors.Value -and $errors.Value.Count -gt 0) {
  $errors.Value | ForEach-Object { $_.ToString() }
  exit 1
} else { Write-Host 'PARSE_OK' }
