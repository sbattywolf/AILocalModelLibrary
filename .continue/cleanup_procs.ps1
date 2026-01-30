$work = 'E:\Workspaces\Git\AILocalModelLibrary'
$patterns = @('agent-runtime-monitor.ps1','monitor-agents-epic.ps1','agent-runtime-monitor','monitor-agents-epic','enforce-single-agent-per-role.ps1','ping.exe -t','ping -t')

Write-Output "[Cleanup] Scanning for processes with patterns: $($patterns -join ', ') or workdir path $work"
$all = Get-CimInstance Win32_Process
$procs = $all | Where-Object { $_.CommandLine -and ($patterns -join '|') -and ($_.CommandLine -match ($patterns -join '|') -or $_.CommandLine -match [regex]::Escape($work)) } | Select-Object ProcessId, Name, CommandLine

if ($procs -and $procs.Count -gt 0) {
  Write-Output "[Cleanup] Found $($procs.Count) matching processes:"
  $procs | ForEach-Object { Write-Output "  PID=$($_.ProcessId) Name=$($_.Name)"; Write-Output "    $($_.CommandLine)" }
  foreach ($p in $procs) {
    try {
      Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
      Write-Output "[Cleanup] Stopped PID $($p.ProcessId)"
    } catch {
      Write-Output "[Cleanup] Failed to stop PID $($p.ProcessId): $($_.Exception.Message)"
    }
  }
} else {
  Write-Output "[Cleanup] No matching processes found."
}

# Stop and remove any PowerShell jobs
try {
  $jobs = Get-Job -ErrorAction SilentlyContinue
  if ($jobs -and $jobs.Count -gt 0) {
    Write-Output "[Cleanup] Found $($jobs.Count) jobs. Stopping and removing."
    foreach ($j in $jobs) {
      try { Stop-Job -Id $j.Id -ErrorAction SilentlyContinue } catch {}
      try { Remove-Job -Id $j.Id -ErrorAction SilentlyContinue } catch {}
      Write-Output "[Cleanup] Cleared job Id=$($j.Id) Name=$($j.Name) State=$($j.State)"
    }
  } else {
    Write-Output "[Cleanup] No PowerShell jobs found."
  }
} catch {
  Write-Output "[Cleanup] Job cleanup failed: $($_.Exception.Message)"
}
