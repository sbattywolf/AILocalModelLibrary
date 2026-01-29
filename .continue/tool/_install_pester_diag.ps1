Write-Host 'Checking PowerShell repositories...'
Get-PSRepository | Format-Table -AutoSize

try {
    Write-Host 'Attempting Install-Module Pester 4.10.0 (CurrentUser)...'
    Install-Module -Name Pester -RequiredVersion 4.10.0 -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop -Verbose 4>&1 | ForEach-Object { Write-Host $_ }
    Write-Host 'Install-Module returned successfully.'
} catch {
    Write-Host 'Install-Module exception details:'
    $_ | Format-List * -Force
    exit 2
}

Write-Host 'Available Pester modules after install attempt:'
Get-Module -ListAvailable -Name Pester | Select-Object Name,Version,Path | Format-Table -AutoSize
