$log = '.\.continue\install-trace.log'
function Log($m){ $t=(Get-Date).ToString('s'); "$t`t$m" | Tee-Object -FilePath $log -Append }

Log 'Scanning netstat for :11434'
$lines = netstat -ano 2>$null | Select-String ':11434'
if (-not $lines) { Log 'No listeners found on 11434'; exit 0 }
$pids = $lines | ForEach-Object { ($_.ToString() -split '\s+')[-1] } | Sort-Object -Unique
Log ("Found PIDs on 11434: {0}" -f ($pids -join ','))

foreach ($p in $pids) {
        try {
            $proc = Get-Process -Id $p -ErrorAction Stop
            if ($proc.ProcessName -match 'ollama') {
                Log ("Stopping PID {0} ({1}): Graceful" -f $p, $proc.ProcessName)
                try { Stop-Process -Id $p -ErrorAction SilentlyContinue } catch {}
                Start-Sleep -Seconds 1
                if (Get-Process -Id $p -ErrorAction SilentlyContinue) {
                    Log ("PID {0} still alive, forcing stop" -f $p)
                    try { Stop-Process -Id $p -Force -ErrorAction SilentlyContinue } catch {}
                }
                Log ("Stopped PID {0}" -f $p)
            } else {
                Log ("Skipping PID {0} (not ollama): {1}" -f $p, $proc.ProcessName)
            }
        } catch {
            $msg = $_.Exception.Message
            Log ("Could not inspect/stop PID {0}: {1}" -f $p, $msg)
        }
}
Start-Sleep -Seconds 1
Log 'Netstat after stops:'
$after = netstat -ano 2>$null | Select-String ':11434' | ForEach-Object { $_.ToString().Trim() }
if (-not $after) { Log 'No listeners on 11434 after stop' } else { $after | ForEach-Object { Log $_ } }

# Start new role-labeled serve
Log 'Starting new role-labeled serve for SimRacingAgent'
& powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-ollama-role.ps1 -Role SimRacingAgent -Action serve -LogDir .\logs 2>&1 | Tee-Object -FilePath $log -Append
Start-Sleep -Seconds 2
# Show mapping and tail log
try { Get-Content -Path .\.continue\ollama-processes.json -Raw | ConvertFrom-Json | Select-Object -Last 3 | ConvertTo-Json -Depth 4 | Tee-Object -FilePath $log -Append } catch { }
$latestLog = Get-ChildItem -Path .\logs -Filter 'ollama-SimRacingAgent-*' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($latestLog) { Log ("Tailing log: $($latestLog.FullName)"); Get-Content -Path $latestLog.FullName -Tail 80 | Tee-Object -FilePath $log -Append }
Log 'Done'
Get-Content -Path $log -Tail 200
