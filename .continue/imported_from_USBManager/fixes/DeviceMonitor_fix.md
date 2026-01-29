Title: Reduce global variables and add ShouldProcess guards

File: agent/src/modules/DeviceMonitor.psm1

Problem
- PSA reported many `PSAvoidGlobalVars` occurrences and `PSUseShouldProcessForStateChangingFunctions` warnings.

Suggested fix (safe changes)
- Convert globals used as caches to `Script:` scope variables and initialize them.
- Add `SupportsShouldProcess = $true` on functions that perform state changes and
  call `if (-not $PSCmdlet.ShouldProcess($Name)) { return }` when appropriate.

Patch examples
```powershell
# initialize script-scoped cache
if (-not (Test-Path Variable:Script:DeviceCache)) { Set-Variable -Name 'DeviceCache' -Value @{} -Scope Script }

function Set-DeviceState {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([string]$DeviceId, [string]$State)
    if (-not $PSCmdlet.ShouldProcess($DeviceId, "Set state to $State")) { return }
    # existing logic
}
```

Post-change checks
- Run `validate-repo.ps1` and PS ScriptAnalyzer.
- Run unit tests.
