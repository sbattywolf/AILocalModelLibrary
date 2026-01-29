<#
.SYNOPSIS
  Stop Ollama processes recorded in .continue/ollama-processes.json by Role or PID.

.DESCRIPTION
  Reads `.\.continue\ollama-processes.json`, stops matching processes, and
  removes their entries from the mapping file. Writes a short trace to
  `.\.continue\install-trace.log`.

.PARAMETER Role
  Role name to stop (stops all entries with that role).

.PARAMETER PID
  Specific PID to stop.

.PARAMETER RemoveOnly
  If supplied, only remove mapping entries without attempting to stop the process.
#>
param(
    [string]$Role,
    [int]$PidArg,
    [switch]$RemoveOnly
)

function Write-Log { param($m) $t=(Get-Date).ToString('s'); $line="$t`t$m"; Add-Content -Path '.\.continue\install-trace.log' -Value $line -ErrorAction SilentlyContinue }

$mapFile = '.\.continue\ollama-processes.json'
if (-not (Test-Path $mapFile)) { Write-Log "Mapping file not found: $mapFile"; Write-Host "No mapping file found."; exit 0 }

try {
    $maps = Get-Content -Path $mapFile -Raw | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Log "Failed to read mapping file: $($_.Exception.Message)"
    Write-Host "Failed to read mapping file: $($_.Exception.Message)"; exit 1
}
# (Diagnostics removed) Read/parse errors still logged above; proceed with operations

# Ensure array
if ($maps -and -not ($maps -is [System.Array])) { $maps = @($maps) }

$toKeep = @()
$stopped = @()
foreach ($m in $maps) {
    $match = $false
    if ($Role) { if ($m.Role -eq $Role) { $match = $true } }
    if ($PidArg) { if ([int]$m.PID -eq $PidArg) { $match = $true } }
    if (-not $Role -and -not $PID) { $match = $true } # no filter -> stop all

    if ($match) {
        if (-not $RemoveOnly) {
            try {
                if (Get-Process -Id $m.PID -ErrorAction SilentlyContinue) {
                    Write-Log "Stopping PID $($m.PID) (role=$($m.Role))"
                    Stop-Process -Id $m.PID -Force -ErrorAction SilentlyContinue
                } else {
                    Write-Log "PID $($m.PID) not running"
                }
            } catch {
                Write-Log "Failed stopping PID $($m.PID): $($_.Exception.Message)"
            }
        } else {
            Write-Log "RemoveOnly: removing mapping for PID $($m.PID) role=$($m.Role)"
        }
        $stopped += $m
    } else {
        $toKeep += $m
    }
}

# Persist remaining mappings atomically: write to temp file then move
try {
    $tmp = "$mapFile.tmp.$([System.Guid]::NewGuid().ToString())"
    $toKeep | ConvertTo-Json -Depth 4 | Out-File -FilePath $tmp -Encoding utf8 -Force
    Move-Item -Path $tmp -Destination $mapFile -Force
    Write-Log "Updated mapping file after stop; removed {0} entries; kept {1} entries" -f $stopped.Count, $toKeep.Count
} catch {
    Write-Log "Failed writing mapping file atomically: $($_.Exception.Message)"
}

Write-Host "Stopped/removed $($stopped.Count) mapping entries. Remaining: $($toKeep.Count)"
if ($stopped.Count -gt 0) { $stopped | Format-Table PID,Role,Action,StartedAt }

exit 0
