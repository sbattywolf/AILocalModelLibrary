<#
.continue/tool/cleanup-old-scripts.ps1

Safely remove old/deprecated scripts and artifacts from the `.continue` folder.
Defaults to DryRun; requires -Force to actually delete. Writes a log of removed
files to `.continue/cleanup.log` when run for real.

Usage:
  # preview deletions
  .\cleanup-old-scripts.ps1 -DryRun

  # delete matching files (after review)
  .\cleanup-old-scripts.ps1 -DryRun:$false -Force

  # provide explicit patterns
  .\cleanup-old-scripts.ps1 -Patterns @('*.old.ps1','*_bak.ps1') -DryRun
#>

param(
    [string[]]$Patterns = @(
        '*.old.ps1',
        '*_old.ps1',
        '*.bak',
        '*.backup',
        '*~',
        '*.tmp',
        'agent-runner.ps1.bak',
        'agent-runner.old.ps1',
        'start-model-old.ps1',
        'stop-model-old.ps1'
    ),
    [switch]$DryRun = $true,
    [switch]$Force = $false,
    [string]$LogFile = '.continue/cleanup.log'
)

function Expand-Patterns($base, $patterns) {
    $results = @()
    foreach ($p in $patterns) {
        $found = Get-ChildItem -Path $base -Recurse -Filter $p -File -ErrorAction SilentlyContinue
        if ($found) { $results += $found }
    }
    return $results | Sort-Object -Property FullName -Unique
}

$base = Join-Path (Get-Location) '.continue'
if (-not (Test-Path $base)) { Write-Warning "No .continue folder found at $base"; exit 2 }

Write-Host "Scanning $base for patterns: $($Patterns -join ', ')"
$matches = Expand-Patterns -base $base -patterns $Patterns

if (-not $matches -or $matches.Count -eq 0) {
    Write-Host "No matching obsolete files found."
    exit 0
}

Write-Host "Found $($matches.Count) candidate(s):"
$matches | ForEach-Object { Write-Host " - $($_.FullName)" }

if ($DryRun) { Write-Host "Dry-run mode: no files will be deleted. Rerun with -DryRun:$false -Force to delete."; exit 0 }

if (-not $Force) {
    $confirm = Read-Host "Proceed to delete these $($matches.Count) files? Type 'yes' to confirm"
    if ($confirm -ne 'yes') { Write-Host "Aborted."; exit 3 }
}

$deleted = @()
foreach ($f in $matches) {
    try {
        Remove-Item -Path $f.FullName -Force -ErrorAction Stop
        $deleted += $f.FullName
        Write-Host "Deleted: $($f.FullName)"
    } catch { Write-Warning "Failed to delete $($f.FullName): $_" }
}

if ($deleted.Count -gt 0) {
    $logDir = Split-Path $LogFile -Parent
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $entry = "$(Get-Date -Format o) - Deleted $($deleted.Count) files:`n$($deleted -join "`n")`n"
    Add-Content -Path $LogFile -Value $entry -Encoding UTF8
    Write-Host "Wrote cleanup log to $LogFile"
}

Write-Host "Cleanup complete."
