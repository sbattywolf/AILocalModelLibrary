<#
Minimal library wrapper for TemplateAgent.
This module imports internal core and module files and exposes a small public API
so other projects (or a VS Code extension) can import the agent as a library.
No tests are included in this module.
#>

# Ensure path resolution works when module is imported from other locations
if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }

# Import core modules
try { Import-Module (Join-Path $PSScriptRoot 'Core\ConfigManager.psm1') -Force -ErrorAction Stop } catch { Write-Verbose "Could not import ConfigManager: $_" }
try { Import-Module (Join-Path $PSScriptRoot 'Core\AgentCore.psm1') -Force -ErrorAction Stop } catch { Write-Verbose "Could not import AgentCore: $_" }

# Import functional modules
try { Import-Module (Join-Path $PSScriptRoot 'Modules\USBMonitor.psm1') -Force -ErrorAction Stop } catch { Write-Verbose "Could not import USBMonitor: $_" }
try { Import-Module (Join-Path $PSScriptRoot 'Modules\ProcessManager.psm1') -Force -ErrorAction SilentlyContinue } catch {}

# Public helper: Get-AgentConfiguration
function Get-AgentConfiguration {
    [CmdletBinding()]
    param()
    try { return Get-DefaultConfiguration } catch { throw "Failed to get default configuration: $($_.Exception.Message)" }
}

# Public helper: Run health check
function Invoke-AgentHealthCheck {
    [CmdletBinding()]
    param()
    try { return Get-USBHealthCheck } catch { throw "Health check failed: $($_.Exception.Message)" }
}

# Public helper: Agent status
function Get-AgentStatusSummary {
    [CmdletBinding()]
    param()
    try { return Get-AgentStatus } catch { throw "Get-AgentStatus failed: $($_.Exception.Message)" }
}

if ($PSModuleInfo) {
    Export-ModuleMember -Function Get-AgentConfiguration,Invoke-AgentHealthCheck,Get-AgentStatusSummary -ErrorAction Stop
} else {
    Write-Verbose "Export-ModuleMember skipped (not running inside a module)"
}
