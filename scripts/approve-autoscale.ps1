param(
    [string]$User = $env:USERNAME,
    [string]$Note = ''
)
$path = '.continue/autoscale-approve'
$payload = @{ approvedBy = $User; approvedAt = (Get-Date).ToString('o'); note = $Note }
$tmp = [System.IO.Path]::GetTempFileName()
$payload | ConvertTo-Json | Out-File -FilePath $tmp -Encoding UTF8
Move-Item -Path $tmp -Destination $path -Force
Write-Output "Wrote approval token to $path (single-use)."
