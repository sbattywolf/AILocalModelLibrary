Title: Reduce globals and sanitize WMIC usage

File: agent/src/modules/USBMonitor.psm1

Problem
- Analyzer found high `PSAvoidGlobalVars` and `PSAvoidUsingWMICmdlet` warnings.

Suggested fixes
- Initialize caches as `Script:` variables and avoid `Global:` scope.
- Replace WMIC usage with more modern CIM/CMDLET calls where possible, or
  add fallbacks with clear error handling.

Patch example
```powershell
if (-not (Test-Path Variable:Script:UsbCache)) { Set-Variable -Name 'UsbCache' -Value @() -Scope Script }

try {
    $devices = Get-CimInstance -ClassName Win32_USBControllerDevice -ErrorAction Stop
} catch {
    Write-AgentWarning -Message "CIM query failed, falling back to WMIC: $($_.Exception.Message)"
    $devices = (wmic path Win32_USBControllerDevice get /format:list) -split "\r?\n"
}
```

Post-change checks
- Run `validate-repo.ps1` and unit tests.
