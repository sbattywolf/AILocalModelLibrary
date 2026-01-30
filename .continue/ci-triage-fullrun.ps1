Import-Module Pester -MinimumVersion '5.0'
Invoke-Pester -Path .\tests -Output Detailed | Tee-Object '.\\.continue\\ci-failures\\pester-full-run.txt'
$failed = Get-Content '.\\.continue\\pester_failed_tests.json' | ConvertFrom-Json
foreach ($t in $failed) {
  $name = $t.Name
  $safe = ($name -replace '[^A-Za-z0-9\-_\.]','_')
  $out = Join-Path '.\\.continue\\ci-failures' ($safe + '.txt')
  Select-String -Path '.\\.continue\\ci-failures\\pester-full-run.txt' -Pattern ([regex]::Escape($name)) -Context 3,10 | Out-String | Set-Content -Path $out
}
