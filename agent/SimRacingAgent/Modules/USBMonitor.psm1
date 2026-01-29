function Get-USBDevices {
    [CmdletBinding()]
    param()
    try {
        $wmi = Get-WmiObject -Class Win32_PnPEntity -ErrorAction Stop
        $usb = @()
        foreach ($item in $wmi) {
            if ($item.DeviceID -and ($item.DeviceID -like 'USB\\*' -or $item.PNPClass -eq 'USB' -or $item.PNPClass -eq 'HIDClass')) {
                $usb += [PSCustomObject]@{
                    DeviceID = $item.DeviceID
                    Description = $item.Description
                    Status = ($item.Status -or 'Unknown')
                    PNPClass = ($item.PNPClass -or '')
                }
            }
        }
        return ,$usb
    } catch {
        return @()
    }
}

function Get-USBHealthCheck {
    param()
    $devices = Get-USBDevices
    $total = $devices.Count
    $errors = ($devices | Where-Object { $_.Status -ne 'OK' }).Count
    $overall = if ($total -eq 0) { 100 } else { [math]::Round(((($total - $errors) / $total) * 100),0) }
    return @{ DeviceCount = $total; ErrorCount = $errors; OverallHealth = $overall }
}

function Initialize-USBMonitoring {
    param(
        [int]$PollingInterval = 10
    )
    # Basic initialization - query devices and return success
    try { Get-USBDevices | Out-Null; return $true } catch { return $false }
}

if ($PSModuleInfo) {
    Export-ModuleMember -Function Get-USBDevices,Get-USBHealthCheck,Initialize-USBMonitoring -ErrorAction Stop
} else {
    Write-Verbose "Export-ModuleMember skipped (not running inside a module)"
}
