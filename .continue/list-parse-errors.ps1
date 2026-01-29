$out = '.\.continue\parse-errors.txt'
if (Test-Path $out) { Remove-Item $out -Force }
Get-ChildItem -Recurse -Include *.ps1,*.psm1 | ForEach-Object {
    $file = $_.FullName
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors)
    if ($errors) {
        foreach ($e in $errors) {
            ('{0}: {1} at {2}:{3}' -f $file, $e.Message, $e.Extent.StartLineNumber, $e.Extent.StartColumn) | Out-File -FilePath $out -Append -Encoding UTF8
        }
    }
}
if (Test-Path $out) { Get-Content $out -Raw }
