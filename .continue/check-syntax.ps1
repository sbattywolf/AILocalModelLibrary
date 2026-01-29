$errs=@()
Get-ChildItem -Recurse -Include *.ps1,*.psm1 | ForEach-Object {
    $file = $_.FullName
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors)
    if ($errors) {
        foreach ($e in $errors) {
            Write-Output ('{0}: {1} at line {2}, col {3}' -f $file, $e.Message, $e.Extent.StartLineNumber, $e.Extent.StartColumn)
        }
        $errs += $file
    }
}
if ($errs.Count -eq 0) { Write-Output 'No PowerShell syntax errors detected' ; exit 0 } else { Write-Output ('Found syntax errors in {0} files' -f $errs.Count); exit 2 }
