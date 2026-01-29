param([string]$file)
$tokens=$null
$errors=$null
[System.Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors)
if ($errors) {
    foreach ($e in $errors) {
        Write-Output ('{0}:{1} {2}' -f $e.Extent.StartLineNumber,$e.Extent.StartColumn,$e.Message)
    }
    exit 2
} else {
    Write-Output 'OK'
}
