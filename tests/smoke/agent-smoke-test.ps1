<#
.SYNOPSIS
  Smoke test for SimRacingAgent core modules.

.DESCRIPTION
  Attempts to locate the agent code (agent/SimRacingAgent or templates/agent/SimRacingAgent),
  imports core modules and invokes `Get-USBHealthCheck` if available. Exits with
  code 0 on success, non-zero otherwise.
#>

# Resolve $PSScriptRoot when dot-sourced or run
if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }

# Walk up to repo root
$RepoRoot = $PSScriptRoot
while ($true) {
    if (Test-Path (Join-Path $RepoRoot '.git') -or Test-Path (Join-Path $RepoRoot 'agent') -or Test-Path (Join-Path $RepoRoot 'templates\agent')) { break }
    $parent = Split-Path -Parent $RepoRoot
    if ($parent -eq $RepoRoot -or [string]::IsNullOrEmpty($parent)) { break }
    $RepoRoot = $parent
}

# Determine agent base path (prefer agent if it contains SimRacingAgent, otherwise templates/agent)
$agentCandidate = Join-Path $RepoRoot 'agent'
$templateCandidate = Join-Path $RepoRoot 'templates\agent'
if (Test-Path (Join-Path $agentCandidate 'SimRacingAgent')) { $AgentPath = $agentCandidate }
elseif (Test-Path (Join-Path $templateCandidate 'SimRacingAgent')) { $AgentPath = $templateCandidate }
else { $AgentPath = $templateCandidate }

Write-Host "Using AgentPath: $AgentPath" -ForegroundColor Cyan

try {
    $cfgPath = Join-Path $AgentPath 'SimRacingAgent\Core\ConfigManager.psm1'
    $usbPath = Join-Path $AgentPath 'SimRacingAgent\Modules\USBMonitor.psm1'

    if (-not (Test-Path $cfgPath)) { Write-Host "Missing module: $cfgPath" -ForegroundColor Yellow }
    else { Import-Module $cfgPath -Force -ErrorAction Stop ; Write-Host "Imported ConfigManager" -ForegroundColor Green }

    if (-not (Test-Path $usbPath)) { Write-Host "Missing module: $usbPath" -ForegroundColor Yellow }
    else { Import-Module $usbPath -Force -ErrorAction Stop ; Write-Host "Imported USBMonitor" -ForegroundColor Green }

    if (Get-Command -Name Get-USBHealthCheck -ErrorAction SilentlyContinue) {
        Write-Host "Invoking Get-USBHealthCheck()..." -ForegroundColor Cyan
        $hc = Get-USBHealthCheck
        if ($hc -and $hc.ContainsKey('OverallHealth')) {
            Write-Host "OverallHealth: $($hc.OverallHealth)" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "Get-USBHealthCheck returned unexpected shape: $($hc | Out-String)" -ForegroundColor Yellow
            exit 2
        }
    } else {
        Write-Host "Get-USBHealthCheck not found after importing modules." -ForegroundColor Red
        exit 3
    }
} catch {
    Write-Host "Smoke test failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 4
}
