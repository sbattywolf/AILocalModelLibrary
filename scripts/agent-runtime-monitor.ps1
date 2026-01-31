param(
  [string]$MappingFile = ".continue/agents-epic.json",
  [int]$IntervalSeconds = 10,
  [string]$TelemetryFile = '.continue/agent-runtime-telemetry.log'
)

function Is-ProcessAlive { param($pid) try { Get-Process -Id $pid -ErrorAction Stop | Out-Null; return $true } catch { return $false } }
function Get-ProcessStats { param($pid) try { $p = Get-Process -Id $pid -ErrorAction Stop; $cpu = 0; try { $cpu = [math]::Round($p.CPU,3) } catch { }; $ws = [math]::Round(($p.WorkingSet64/1MB),2); return @{ cpuSec=$cpu; workingSetMB=$ws } } catch { return @{ cpuSec=0; workingSetMB=0 } } }

Write-Output ("[AgentRuntimeMonitor] Sampling mapping {0} every {1}s" -f $MappingFile, $IntervalSeconds)
while ($true) {
  try {
    if (-not (Test-Path $MappingFile)) { Start-Sleep -Seconds $IntervalSeconds; continue }
    $agents = Get-Content $MappingFile -Raw | ConvertFrom-Json
    foreach ($a in $agents) {
      if ($a.pid -and (Is-ProcessAlive -pid $a.pid)) {
        $s = Get-ProcessStats -pid $a.pid
        $entry = @{ ts = (Get-Date).ToString('o'); name = $a.name; pid = $a.pid; cpuSec = $s.cpuSec; workingSetMB = $s.workingSetMB }
        try { $entry | ConvertTo-Json -Compress | Add-Content -Path $TelemetryFile -Encoding UTF8 } catch { }
      }
    }
  } catch { }
  Start-Sleep -Seconds $IntervalSeconds
}
