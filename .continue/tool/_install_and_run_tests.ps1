Write-Host 'Installing Pester 4.10.0 with SkipPublisherCheck...'
try {
    Install-Module -Name Pester -RequiredVersion 4.10.0 -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -ErrorAction Stop -Verbose 4>&1 | ForEach-Object { Write-Host $_ }
    Write-Host 'Install-Module completed.'
} catch {
    Write-Host 'Install-Module failed:'
    $_ | Format-List * -Force
    exit 2
}

try {
    Import-Module Pester -Force -ErrorAction Stop
} catch {
    Write-Host 'Import-Module Pester failed:'
    $_ | Format-List * -Force
    exit 3
}

Write-Host 'Pester available versions:'
Get-Module -ListAvailable -Name Pester | Select-Object Name,Version,Path | Format-Table -AutoSize

Write-Host 'Running tests:'
& .\scripts\run-tests.ps1
$code = $LASTEXITCODE
Write-Host "Runner exit code: $code"
exit $code
