<#
.SYNOPSIS
  Elevated helper to safely update the System (Machine) PATH.

.DESCRIPTION
  Backs up current System PATH to a backup file and appends a provided folder
  to the Machine PATH when run elevated. Supports a `-DryRun` mode and basic
  validation to avoid duplicating entries.

.PARAMETER AddPath
  The absolute folder path to add to the System PATH.

.PARAMETER BackupPath
  Where to write the System PATH backup (relative to repository by default).

.PARAMETER DryRun
  Preview changes without applying them.

.PARAMETER Force
  Skip prompts.
#>
param(
  [Parameter(Mandatory=$true)][string]$AddPath,
  [string]$BackupPath = '.continue/system-path-backup.txt',
  [switch]$DryRun,
  [switch]$Force
)

function Write-Info { param($m) Write-Host $m -ForegroundColor Cyan }
function Write-Warn { param($m) Write-Host $m -ForegroundColor Yellow }
function Write-Err { param($m) Write-Host $m -ForegroundColor Red }

# Normalize path
$AddPath = (Resolve-Path -LiteralPath $AddPath -ErrorAction SilentlyContinue)
if ($null -eq $AddPath) { Write-Err "AddPath not found: $AddPath" ; exit 2 }
$AddPath = $AddPath.Path

if ($DryRun) { Write-Info "DRY RUN: will not change System PATH." }

# If not DryRun, check elevation and elevate if necessary
if (-not $DryRun) {
  $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) {
    if ($Force) { Write-Err "Elevation required but -Force supplied; aborting." ; exit 3 }
    Write-Info "Not running elevated. Relaunching with elevation..."
    # Prefer pwsh if available, otherwise fall back to powershell
    $psExe = (Get-Command pwsh -ErrorAction SilentlyContinue).Path
    if (-not $psExe) { $psExe = (Get-Command powershell -ErrorAction SilentlyContinue).Path }
    $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File', (Get-Item $PSCommandPath).FullName, '-AddPath', "'$AddPath'")
    if ($DryRun) { $argList += '-DryRun' }
    if ($Force) { $argList += '-Force' }
    Start-Process -FilePath $psExe -ArgumentList $argList -Verb RunAs -Wait
    exit $LASTEXITCODE
  }
}

try {
  # Read current Machine PATH
  $machinePath = [Environment]::GetEnvironmentVariable('Path',[EnvironmentVariableTarget]::Machine)
  if ($null -eq $machinePath) { $machinePath = '' }

  # Ensure backup directory exists
  $backupFull = (Resolve-Path -LiteralPath (Split-Path $BackupPath -Parent -ErrorAction SilentlyContinue) -ErrorAction SilentlyContinue)
  if ($null -eq $backupFull) { New-Item -ItemType Directory -Force -Path (Split-Path $BackupPath -Parent) | Out-Null }

  # Write backup
  $machinePath | Out-File -FilePath $BackupPath -Encoding utf8 -Force
  Write-Info "Backed up System PATH to $BackupPath"

  # Check if AddPath already present
  if ($machinePath -like "*$AddPath*") {
    Write-Info "Path already present in Machine PATH: $AddPath"
    exit 0
  }

  $new = if ($machinePath.Length -gt 0) { "$machinePath;$AddPath" } else { $AddPath }
  Write-Info "New Machine PATH length: $($new.Length)"

  if ($DryRun) {
    Write-Info "DRY RUN: preview only; not applying System PATH. Preview first 200 chars:"
    Write-Host $new.Substring(0,[Math]::Min(200,$new.Length))
    exit 0
  }

  # Apply new Machine PATH
  try {
    [Environment]::SetEnvironmentVariable('Path',$new,[EnvironmentVariableTarget]::Machine)
    Write-Info "System PATH updated. New sessions (and some services) will pick this up after restart." 
    exit 0
  } catch {
    Write-Err "Failed to set Machine PATH: $($_.Exception.Message)"
    exit 4
  }
} catch {
  Write-Err "Exception: $($_.Exception.Message)"
  exit 5
}
