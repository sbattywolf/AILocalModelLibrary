Import-Module Pester -MinimumVersion '5.0'
$failed = Get-Content '.\\.continue\\pester_failed_tests.json' | ConvertFrom-Json
foreach ($t in $failed) {
   $name = $t.Name
   $safe = ($name -replace '[^A-Za-z0-9\\-\\_\\.]','_')
   $out = Join-Path '.\\.continue\\ci-failures' ($safe + '.txt')
   Write-Output "Running: $name -> $out"
   Invoke-Pester -TestName $name -Output Detailed | Tee-Object -FilePath $out
}
