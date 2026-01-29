<#
.SYNOPSIS
  Gracefully stop then optionally force-stop Ollama processes by Role or PID.

.DESCRIPTION
  Attempts a soft stop (Stop-Process without -Force), waits `-GraceSeconds`,
  then forces termination if still running. Updates the mapping file
  atomically and logs a concise summary to `.\.continue\install-trace.log`.

.PARAMETER Role
  Role name to stop (stops all entries with that role).

.PARAMETER PID
  Specific PID to stop.

.PARAMETER GraceSeconds
  Seconds to wait after soft stop before forcing. Default 5.

.PARAMETER DryRun
  If set, do not stop processes or write mapping; only report what would change.
#>
param(
  [string]$Role,
  [int]$PidArg,
  [int]$GraceSeconds = 5,
  [switch]$DryRun
)

function Write-Log { param($m) $t=(Get-Date).ToString('s'); $line="$t`t$m"; Add-Content -Path '.\.continue\install-trace.log' -Value $line -ErrorAction SilentlyContinue }

$mapFile = '.\.continue\ollama-processes.json'
if (-not (Test-Path $mapFile)) { Write-Log "kill: mapping file not found: $mapFile"; Write-Host "No mapping file found."; exit 0 }

try { $maps = Get-Content -Path $mapFile -Raw | ConvertFrom-Json -ErrorAction Stop } catch { Write-Log "kill: failed to read mapping file: $($_.Exception.Message)"; Write-Host "Failed to read mapping file: $($_.Exception.Message)"; exit 1 }

if ($maps -and -not ($maps -is [System.Array])) { $maps = @($maps) }

$matches = @()
foreach ($m in $maps) {
  $match = $false
  if ($Role) { if ($m.Role -eq $Role) { $match = $true } }
  if ($PidArg) { if ([int]$m.PID -eq $PidArg) { $match = $true } }
  if (-not $Role -and -not $PidArg) { $match = $true }
  if ($match) { $matches += $m }
}

if (-not $matches -or $matches.Count -eq 0) { Write-Host "No matching entries found."; Write-Log "kill: no matches for Role=$Role PID=$Pid"; exit 0 }

$stopped = @()
$kept = @($maps)

foreach ($entry in $matches) {
    $pidVal = [int]$entry.PID
    Write-Host "Killing PID $pidVal (role=$($entry.Role))..."
    Write-Log "kill: attempting soft stop PID $pidVal (role=$($entry.Role))"
    if (-not $DryRun) {
        try { Stop-Process -Id $pidVal -ErrorAction SilentlyContinue } catch { }
        Start-Sleep -Seconds $GraceSeconds
        if (Get-Process -Id $pidVal -ErrorAction SilentlyContinue) {
            Write-Log "kill: soft stop failed; forcing PID $pidVal"
            try { Stop-Process -Id $pidVal -Force -ErrorAction SilentlyContinue } catch { }
        } else {
            Write-Log "kill: soft stop succeeded PID $pidVal"
        }
    } else {
        Write-Log "kill: DryRun would stop PID $pidVal (role=$($entry.Role))"
    }

    # If not DryRun and process no longer running, remove from map
    $stillRunning = $false
    if (-not $DryRun) { if (Get-Process -Id $pidVal -ErrorAction SilentlyContinue) { $stillRunning = $true } }
    if (-not $stillRunning) {
        $stopped += $entry
        # remove all matching entries with same PID from kept
        $kept = $kept | Where-Object { [int]$_.PID -ne $pidVal }
    }
}

# Persist remaining mappings if not DryRun
if (-not $DryRun) {
    try {
        $tmp = "$mapFile.tmp.$([System.Guid]::NewGuid().ToString())"
        $kept | ConvertTo-Json -Depth 4 | Out-File -FilePath $tmp -Encoding utf8 -Force
        Move-Item -Path $tmp -Destination $mapFile -Force
        Write-Log "kill: removed {0} entries; kept {1} entries" -f $stopped.Count, $kept.Count
        Write-Host "Removed $($stopped.Count) entries. Remaining: $($kept.Count)"
    } catch { Write-Log "kill: failed to persist mapping: $($_.Exception.Message)"; Write-Host "Failed writing mapping file: $($_.Exception.Message)" }
} else {
    Write-Host "DryRun complete: would remove $($matches.Count) entries"
}

exit 0
