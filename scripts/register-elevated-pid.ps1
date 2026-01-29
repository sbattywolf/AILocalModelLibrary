<#
.SYNOPSIS
  Register the current elevated PowerShell process PID to a tracking file.

.DESCRIPTION
  When you run elevated installers that spawn long-running elevated processes,
  call this script at the start of the elevated process to record its PID. This
  allows `cleanup-elevated.ps1` to find and terminate those processes later.

.NOTES
  This script is intentionally minimal for reliability and PS5.1 compatibility.
#>
param(
    [string]$PidFile = '.\.continue\elevated-pids.txt',
    [string]$LogPath = '.\.continue\install-trace.log'
)

function Write-Log { param($m) $t=(Get-Date).ToString('s'); $line="$t`t$m"; Write-Host $line; try { Add-Content -Path $LogPath -Value $line -ErrorAction SilentlyContinue } catch {} }

function Test-IsAdmin { try { return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch { return $false } }

if (-not (Test-IsAdmin)) {
    Write-Log "register-elevated-pid: Not elevated; PID not registered. Run this in an elevated session."
    exit 2
}

$entry = "$(Get-Date -Format o)`tPID:`t$PID"
try {
    $dir = Split-Path -Path $PidFile -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Add-Content -Path $PidFile -Value $entry -Force
    Write-Log "Registered elevated PID $PID to $PidFile"
} catch {
    Write-Log "Failed to register PID: $($_ | Out-String)"
    exit 1
}

exit 0
