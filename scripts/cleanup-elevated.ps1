<#
.SYNOPSIS
  Terminate elevated processes recorded in .continue/elevated-pids.txt and clean up the file.

.DESCRIPTION
  Reads PIDs from .continue/elevated-pids.txt (one entry per line) and attempts
  to stop each process gracefully, then force if needed. Logs to .continue/install-trace.log.
#>
param(
    [string]$PidFile = '.\.continue\elevated-pids.txt',
    [string]$LogPath = '.\.continue\install-trace.log'
)

function Write-Log { param($m) $t=(Get-Date).ToString('s'); $line="$t`t$m"; Write-Host $line; try { Add-Content -Path $LogPath -Value $line -ErrorAction SilentlyContinue } catch {} }

if (-not (Test-Path $PidFile)) {
    Write-Log "No elevated PID file found at $PidFile. Nothing to do."
    exit 0
}

$lines = Get-Content -Path $PidFile -ErrorAction SilentlyContinue
if (-not $lines) {
    Write-Log "PID file empty; removing $PidFile"
    Remove-Item -Path $PidFile -ErrorAction SilentlyContinue
    exit 0
}

foreach ($l in $lines) {
    # Expect lines like: 2026-01-29T18:00:00.0000000Z	PID:	12345
    $parts = $l -split '\t'
    $pid = $null
    if ($parts.Length -ge 3) { $pid = $parts[2] } else { $pid = ($l -split '\s')[-1] }
    if (-not [int]::TryParse($pid, [ref]0)) {
        Write-Log "Skipping invalid PID entry: $l"
        continue
    }
    $pidInt = [int]$pid
    Write-Log "Attempting to stop process PID $pidInt"
    try {
        Stop-Process -Id $pidInt -ErrorAction Stop
        Write-Log "Stopped process $pidInt"
    } catch {
        $err = $_ | Out-String
        Write-Log ("Stop-Process graceful failed for {0}; trying force. Error: {1}" -f $pidInt, $err)
        try {
            Stop-Process -Id $pidInt -Force -ErrorAction Stop
            Write-Log "Force-stopped $pidInt"
        } catch {
            $err2 = $_ | Out-String
            Write-Log ("Failed to terminate {0}: {1}" -f $pidInt, $err2)
        }
    }
}

try { Remove-Item -Path $PidFile -ErrorAction SilentlyContinue; Write-Log "Removed PID file $PidFile" } catch { Write-Log "Failed to remove PID file: $($_ | Out-String)" }

Write-Log "cleanup-elevated completed."
exit 0
