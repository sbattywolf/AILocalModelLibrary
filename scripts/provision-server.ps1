<#
Provision helper for local AI server.
This script does not install system packages automatically; it prepares directories,
checks for basic prerequisites, and prints step-by-step install instructions.

Usage: run in an elevated PowerShell prompt on the target server:
    .\scripts\provision-server.ps1 [-PerformChecks]
#>

param(
    [switch]$PerformChecks
)

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$log = Join-Path $repoRoot ".continue\provision.log"
function Log([string]$m) { "$((Get-Date).ToString('o')) - $m" | Add-Content -Path $log -Encoding UTF8 }

Write-Host "Provision helper — preparing folders and checks"
Log "Provision run started"

# Ensure .continue exists
$continue = Join-Path $repoRoot ".continue"
if (-not (Test-Path $continue)) { New-Item -ItemType Directory -Path $continue -Force | Out-Null; Log "Created .continue" }

# Create recommended dirs
$dirs = @(".continue/telemetry",".continue/artifacts",".continue/agents","scripts","docs")
foreach ($d in $dirs) {
    $p = Join-Path $repoRoot $d
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null; Log "Created $p" }
}

if ($PerformChecks) {
    Write-Host "Checking prerequisites..."
    Log "Performing checks"
    # Check GPU presence via nvidia-smi if available
    $nvidia = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if ($nvidia) { Write-Host "nvidia-smi available"; Log "nvidia-smi detected" } else { Write-Host "nvidia-smi not found; ensure NVIDIA drivers are installed"; Log "nvidia-smi missing" }

    # Check PowerShell version
    Write-Host "PowerShell version: $($PSVersionTable.PSVersion)"
    Log "PowerShell version $($PSVersionTable.PSVersion)"
}

Write-Host "Manual install steps (recommended):"
Write-Host "1. Install NVIDIA drivers and CUDA as required for RTX 3090."
Write-Host "2. Install Ollama (https://ollama.com) per OS instructions; configure model storage and VRAM limits."
Write-Host "3. Install VS Code and Remote - SSH extension; configure user accounts for remote access."
Write-Host "4. Optional: install Docker for containers/NAS agents."
Write-Host "5. Configure backups for .continue and telemetry directories."

Log "Provision helper finished"
Write-Host "Provision helper finished — see $log for details"
