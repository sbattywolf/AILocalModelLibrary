<#
.continue/tool/stop-model.ps1

Stops a model runtime previously started by start-model.ps1. Supports dry-run.
It reads PID from the pidfile and attempts a graceful stop, cleaning marker files.
#>

param(
    [string]$PidFile = '.continue/model.pid',
    [string]$MarkerFile = '.continue/model.marker',
    [switch]$DryRun = $true
)

Write-Host "stop-model: DryRun=$DryRun PidFile=$PidFile MarkerFile=$MarkerFile"

if (-not (Test-Path $PidFile)) {
    Write-Warning "PID file not found: $PidFile"; exit 2
}

$pidText = Get-Content -Path $PidFile -ErrorAction SilentlyContinue
if (-not $pidText) { Write-Warning "PID file empty"; exit 3 }

[int]$pid = 0
try { $pid = [int]$pidText.Trim() } catch { Write-Warning "Invalid pid in $PidFile"; exit 4 }

if ($DryRun) {
    Write-Host "Dry-run: would stop process pid=$pid and remove marker $MarkerFile"; exit 0
}

try {
    $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "Stopping process id=$pid..."
        $proc.CloseMainWindow() | Out-Null
        Start-Sleep -Seconds 1
        if (-not $proc.HasExited) { $proc | Stop-Process -Force }
    } else { Write-Warning "Process $pid not found." }

    # cleanup files
    Remove-Item -Path $PidFile -ErrorAction SilentlyContinue
    if (Test-Path $MarkerFile) { Remove-Item -Path $MarkerFile -ErrorAction SilentlyContinue }
    Write-Host "Stopped and cleaned up."; exit 0
} catch {
    Write-Warning "Error stopping process: $_"; exit 5
}
