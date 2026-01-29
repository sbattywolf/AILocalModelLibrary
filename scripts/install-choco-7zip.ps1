<#
.SYNOPSIS
  Installs Chocolatey (if missing) and then installs 7-Zip via Chocolatey.

.DESCRIPTION
  Safe installer with DryRun/Apply modes. When run with -Apply the script will
  attempt to bootstrap Chocolatey and then install 7zip. Requires admin; the
  script will re-launch elevated when needed. Logs appended to .continue/install-trace.log by default.
#>
param(
    [switch]$Apply,
    [switch]$DryRun = $true,
    [string]$LogPath = '.\.continue\install-trace.log'
)

function Write-Log { param([string]$m) $t=(Get-Date).ToString('s'); $line="$t`t$m"; Write-Host $line; try{ Add-Content -Path $LogPath -Value $line -ErrorAction SilentlyContinue } catch {} }

Write-Log "Starting install-choco-7zip.ps1 (Apply=$Apply, DryRun=$DryRun)"

if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Log "Chocolatey already installed. Will install 7zip via choco if missing."
} else {
    Write-Log "Chocolatey not found. Will bootstrap Chocolatey."
}

if ($DryRun -and -not $Apply) {
    Write-Log "DRY RUN: The script will:"
    Write-Log "  1) Bootstrap Chocolatey (if missing) via official install script."
    Write-Log "  2) Run 'choco install 7zip -y' to install 7-Zip."
    Write-Log "To run for real, re-run with -Apply."
    exit 0
}

function Test-IsAdmin { try { return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch { return $false } }

if (-not (Test-IsAdmin)) {
    Write-Log "Not elevated. Relaunching elevated to perform Chocolatey install and package installs."
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Apply"
    if ($LogPath) { $args += " -LogPath `"$LogPath`"" }
    $psi.Arguments = $args
    $psi.Verb = 'runas'
    try { [Diagnostics.Process]::Start($psi) | Out-Null; Write-Log "Launched elevated process; exiting."; exit 0 } catch { Write-Log "Failed to elevate: $($_ | Out-String)"; exit 1 }
}

Write-Log "Running elevated. Starting bootstrap/install sequence."

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

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Log "Bootstrapping Chocolatey via official install script."
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        $script = (New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')
        Invoke-Expression $script
        Write-Log "Chocolatey bootstrap attempted."
    } catch {
        Write-Log ("Chocolatey bootstrap failed: {0}" -f (($_ | Out-String).Trim()))
        exit 2
    }
} else {
    Write-Log "Chocolatey already present."
}

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Log "Chocolatey not available after bootstrap. Aborting."
    exit 3
}

Write-Log "Installing 7-Zip via Chocolatey: 'choco install 7zip -y'"
try {
    choco install 7zip -y | ForEach-Object { Write-Log ("choco: {0}" -f ($_ | Out-String).Trim()) }
    Write-Log "choco install completed."
} catch {
    Write-Log ("choco install failed: {0}" -f (($_ | Out-String).Trim()))
    exit 4
}

Write-Log "Install sequence finished successfully."
exit 0
