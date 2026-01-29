<#
.SYNOPSIS
  Attempts to install App Installer / winget on Windows.

.DESCRIPTION
  Tries multiple safe approaches to install App Installer (winget). Includes a DryRun
  mode that reports actions without making changes. When run with -Apply the script
  will attempt to download an MSIX bundle and install it using Add-AppxPackage. If
  administrator elevation is required the script will re-launch itself elevated.

.PARAMETER Apply
  Perform actions (default is DryRun).

.PARAMETER DryRun
  When specified, only report intended steps. Default: $true.

.PARAMETER LogPath
  Path to append logs. Default: .\.continue\install-trace.log

EXAMPLE
  .\scripts\install-winget.ps1 -DryRun
  .\scripts\install-winget.ps1 -Apply -LogPath .\.continue\install-trace.log
#>
param(
    [switch]$Apply,
    [switch]$DryRun = $true,
    [string]$LogPath = '.\.continue\install-trace.log'
)

function Write-Log {
    param([string]$Message)
    $ts = (Get-Date).ToString('s')
    $line = "$ts`t$Message"
    Write-Host $line
    try { Add-Content -Path $LogPath -Value $line -ErrorAction SilentlyContinue } catch {}
}

Write-Log "Starting install-winget.ps1 (Apply=$Apply, DryRun=$DryRun)"

# Quick check: is winget already available?
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Log "winget is already installed and on PATH. Nothing to do."
    exit 0
}

Write-Log "winget not found on PATH. Proceeding with checks..."

# If DryRun, describe actions and exit
if ($DryRun -and -not $Apply) {
    Write-Log "DRY RUN: The script will attempt the following (no changes in DryRun):"
    Write-Log "  1) Open Microsoft Store page for App Installer to allow manual install."
    Write-Log "  2) Attempt to download an MSIX bundle (candidate URLs) and install via Add-AppxPackage."
    Write-Log "  3) If MSIX install fails and Chocolatey is present, optionally install via Chocolatey."
    Write-Log "  4) If all automated approaches fail, provide instructions for manual installation."
    Write-Log "To run for real, re-run with -Apply."
    exit 0
}

# From here on we are in Apply mode. Ensure we are elevated for Add-AppxPackage.
function Test-IsAdmin {
    try { return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch { return $false }
}

if (-not (Test-IsAdmin)) {
    Write-Log "Not running elevated. Attempting to re-launch elevated to perform install."
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Apply"
    if ($LogPath) { $args += " -LogPath `"$LogPath`"" }
    $psi.Arguments = $args
    $psi.Verb = 'runas'
    try {
        [Diagnostics.Process]::Start($psi) | Out-Null
        Write-Log "Launched elevated process; exiting current session."
        exit 0
    } catch {
        Write-Log ("Failed to elevate: {0}" -f (($_ | Out-String).Trim()))
        exit 1
    }
}

Write-Log "Running elevated. Beginning automated installation attempts."

# Register this elevated process so it can be cleaned up later
try {
    $registerScript = Join-Path $PSScriptRoot 'register-elevated-pid.ps1'
    if (Test-Path $registerScript) {
        & $registerScript -PidFile '.\.continue\elevated-pids.txt' -LogPath $LogPath | Out-Null
        Write-Log "Registered elevated PID via $registerScript"
    } else {
        Write-Log "Register script not found at $registerScript; skipping PID registration."
    }
} catch {
    Write-Log ("PID registration failed: {0}" -f (($_ | Out-String).Trim()))
}

# Candidate URLs to attempt download of App Installer bundle
$candidates = @(
    'https://aka.ms/getwinget',
    'https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
)

$tmp = [IO.Path]::Combine($env:TEMP, "winget-msixbundle-$(Get-Random).msixbundle")
$downloaded = $false

foreach ($u in $candidates) {
    Write-Log "Attempting download from: $u"
    try {
        Invoke-WebRequest -Uri $u -OutFile $tmp -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop
        Write-Log "Downloaded candidate to $tmp"
        $downloaded = $true
        break
    } catch {
        Write-Log ("Download failed from {0}: {1}" -f $u, (($_ | Out-String).Trim()))
        if (Test-Path $tmp) { Remove-Item $tmp -ErrorAction SilentlyContinue }
    }
}

if (-not $downloaded) {
    Write-Log "All automated downloads failed. Will attempt opening Store page to guide manual install."
    try {
        Start-Process 'ms-windows-store://pdp/?productid=9NBLGGH4NNS1' -ErrorAction SilentlyContinue
        Write-Log "Opened Microsoft Store App Installer page (user interaction required)."
    } catch {
        Write-Log "Failed to open Microsoft Store. Please install 'App Installer' from Microsoft Store or install winget manually."
    }
    Write-Log "Automated installation unsuccessful. Exiting with code 2."
    exit 2
}

# Try to install the downloaded MSIX bundle
Write-Log "Attempting Add-AppxPackage -Path $tmp"
try {
    Add-AppxPackage -Path $tmp -ErrorAction Stop
    Write-Log "Add-AppxPackage succeeded. Verifying winget presence..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Log "winget installed successfully.";
        exit 0
    } else {
        Write-Log "winget still not found after installing bundle."
    }
} catch {
    Write-Log ("Add-AppxPackage failed: {0}" -f (($_ | Out-String).Trim()))
}

# Cleanup downloaded candidate if present
if (Test-Path $tmp) { Remove-Item $tmp -ErrorAction SilentlyContinue }

Write-Log "Automated install attempts completed but winget not available."
Write-Log "Next steps: Install App Installer from Microsoft Store, or install Chocolatey and use it to bootstrap tools."
exit 3
