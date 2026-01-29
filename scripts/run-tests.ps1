# Installs/loads Pester and runs tests under tests/*.Tests.ps1
param(
    [string]$TestsPath = '.\tests',
    [switch]$ForceInstallPester
)
if ($ForceInstallPester -or -not (Get-Module -ListAvailable -Name Pester)) {
    Write-Host 'Installing Pester module (current user) version 4.10.0…'
    try { Install-Module -Name Pester -RequiredVersion 4.10.0 -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop } catch { Write-Warning ("Could not install requested Pester version: {0}" -f $_.Exception.Message) }
}
# Import Pester v4 if available; prefer explicit version to avoid older/module mismatch
try { Import-Module Pester -RequiredVersion 4.10.0 -ErrorAction Stop } catch { Import-Module Pester -ErrorAction SilentlyContinue }
$testFiles = Get-ChildItem -Path $TestsPath -Filter '*.Tests.ps1' -File -Recurse | Select-Object -ExpandProperty FullName
if (-not $testFiles) { Write-Host 'No tests found.'; exit 0 }
$result = Invoke-Pester -Script $testFiles -PassThru
if ($result.FailedCount -gt 0) { Write-Host "Tests failed: $($result.FailedCount)"; exit 1 } else { Write-Host 'All tests passed'; exit 0 }
