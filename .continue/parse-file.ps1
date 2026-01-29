param([string]$Path)
$tokens=$null; $errors=$null
[System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
if ($errors) { foreach ($e in $errors) { '{0}: {1} at {2}:{3}' -f $Path, $e.Message, $e.Extent.StartLineNumber, $e.Extent.StartColumn } } else { Write-Output 'No errors' }
