<#
.SYNOPSIS
  Detects available package managers and installs 7-Zip using the preferred tool.

.DESCRIPTION
  - Detects `winget` and `choco` on PATH.
  - Logs decisions and actions to `.continue/install-trace.log`.
  - Interactive by default: offers choices to the user. Use `-Auto` to proceed
    non-interactively (prefer `winget` when available, else `choco` with bootstrap).
  - `-DryRun` prints planned actions without performing installs.
#>
param(
    [switch]$Auto,
    [bool]$DryRun = $true,
    [switch]$NoDryRun,
    [string]$LogPath = '.\.continue\install-trace.log'
)

function Write-Log { param($m) $t=(Get-Date).ToString('s'); $line="$t`t$m"; Write-Host $line; try { Add-Content -Path $LogPath -Value $line -ErrorAction SilentlyContinue } catch {} }

Write-Log "Starting install-7zip-auto.ps1 (Auto=$Auto, DryRun=$DryRun, NoDryRun=$NoDryRun)"

if ($NoDryRun) { $DryRun = $false; Write-Log "NoDryRun requested: DryRun set to False" }

$hasWinget = $false
$hasChoco = $false
if (Get-Command winget -ErrorAction SilentlyContinue) { $hasWinget = $true }
if (Get-Command choco -ErrorAction SilentlyContinue) { $hasChoco = $true }

Write-Log ("Detected: winget={0}, choco={1}" -f $hasWinget, $hasChoco)

if ($DryRun -and -not $Auto) {
    Write-Log "DRY RUN: Planned actions based on detection:"
    if ($hasWinget) { Write-Log "  - Use winget: 'winget install --id=7zip.7zip -e --silent'" } 
    elseif ($hasChoco) { Write-Log "  - Use choco: 'choco install 7zip -y'" }
    else { Write-Log "  - No package manager found. Options:\n      (1) Install winget via scripts/install-winget.ps1\n      (2) Install Chocolatey via scripts/install-choco-7zip.ps1 -Apply\n      (3) Abort" }
    Write-Log "Re-run with -Auto to proceed non-interactively.";
    exit 0
}

if ($Auto) {
    if ($hasWinget) {
        Write-Log "Auto: using winget to install 7-Zip."
        if ($DryRun) { Write-Log "DRY RUN: winget install --id=7zip.7zip -e --silent"; exit 0 }
        Write-Log "Running: winget install --id=7zip.7zip -e --silent"
        winget install --id=7zip.7zip -e --silent 2>&1 | ForEach-Object { Write-Log ("winget: {0}" -f ($_ | Out-String).Trim()) }
        exit 0
    } elseif ($hasChoco) {
        Write-Log "Auto: using Chocolatey to install 7-Zip."
        if ($DryRun) { Write-Log "DRY RUN: choco install 7zip -y"; exit 0 }
        # Ensure elevated for choco install
        function Test-IsAdmin { try { return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch { return $false } }
        if (-not (Test-IsAdmin)) { Write-Log "Not elevated: please re-run this script in an Administrator PowerShell."; exit 2 }
        choco install 7zip -y | ForEach-Object { Write-Log ("choco: {0}" -f ($_ | Out-String).Trim()) }
        exit 0
    } else {
        Write-Log "Auto: no package manager available. Consider running scripts/install-winget.ps1 -Apply or scripts/install-choco-7zip.ps1 -Apply"
        exit 3
    }
}

# Interactive flow
Write-Log "Interactive mode. Choose an option:"
Write-Log "  1) Use winget (if available)"
Write-Log "  2) Use Chocolatey (if available)"
Write-Log "  3) Install winget (open Store / attempt msix install)"
Write-Log "  4) Bootstrap Chocolatey and install 7-Zip"
Write-Log "  5) Abort"

$choice = Read-Host "Enter choice number"
switch ($choice) {
    '1' {
        if (-not $hasWinget) { Write-Log "winget not available."; exit 5 }
        Write-Log "Running winget install (interactive)."
        winget install --id=7zip.7zip -e --silent 2>&1 | ForEach-Object { Write-Log ("winget: {0}" -f ($_ | Out-String).Trim()) }
    }
    '2' {
        if (-not $hasChoco) { Write-Log "choco not available."; exit 6 }
        Write-Log "Running choco install 7zip -y (interactive)."
        choco install 7zip -y | ForEach-Object { Write-Log ("choco: {0}" -f ($_ | Out-String).Trim()) }
    }
    '3' {
        Write-Log "Launching winget installer helper (scripts/install-winget.ps1 -Apply)."
        powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-winget.ps1 -Apply -LogPath $LogPath
    }
    '4' {
        Write-Log "Launching Chocolatey bootstrap + install (scripts/install-choco-7zip.ps1 -Apply)."
        powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-choco-7zip.ps1 -Apply -LogPath $LogPath
    }
    default { Write-Log "Abort chosen or unknown option."; exit 0 }
}

Write-Log "install-7zip-auto completed."
exit 0
