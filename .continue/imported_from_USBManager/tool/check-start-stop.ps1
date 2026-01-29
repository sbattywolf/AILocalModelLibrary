<#
.continue/tool/check-start-stop.ps1

Quick validation that `start-model.ps1` and `stop-model.ps1` exist and respond to `-DryRun`.
Exits 0 if both scripts return successfully in dry-run mode, non-zero otherwise.
#>

param(
    [switch]$Verbose
)

function Check-Script($path) {
    if (-not (Test-Path $path)) { Write-Host "MISSING: $path"; return $false }
    Write-Host "Found: $path"
    try {
        & $path -DryRun 2>&1 | ForEach-Object { Write-Host "  $_" }
        return $true
    } catch {
        Write-Host "Error running $path -DryRun : $_"; return $false
    }
}

$base = Join-Path (Get-Location) '.continue\tool'
$start = Join-Path $base 'start-model.ps1'
$stop = Join-Path $base 'stop-model.ps1'

Write-Host "Checking start/stop helper scripts..."
$ok1 = Check-Script $start
$ok2 = Check-Script $stop

if ($ok1 -and $ok2) {
    Write-Host "OK: start/stop scripts validated (dry-run)."; exit 0
} else {
    Write-Host "FAIL: one or more scripts missing or failed dry-run."; exit 2
}
