param(
  [switch]$Kill,
  [switch]$Yes
)

function Write-Log { param($m) $t=(Get-Date).ToString('s'); "$t`t$m" | Write-Host }

if (-not (Get-Command nvidia-smi -ErrorAction SilentlyContinue)) {
  Write-Log "nvidia-smi not found on PATH. Cannot inspect GPU processes."
  exit 2
}

Write-Log "Querying GPU memory usage..."
try {
  $mem = & nvidia-smi --query-gpu=index,name,memory.total,memory.used --format=csv,noheader,nounits 2>$null
  if ($mem) { $mem | ForEach-Object { Write-Host $_ } } else { Write-Log "No GPU info returned." }
} catch { Write-Log "Failed to query GPU memory: $_" }

Write-Log "Listing GPU processes (if supported by driver)..."
$procs = @()
try {
  $lines = & nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader,nounits 2>$null
  if ($lines) {
    $lines | ForEach-Object {
      $parts = $_ -split ',' | ForEach-Object { $_.Trim() }
      if ($parts.Count -ge 3) {
        $p = [PSCustomObject]@{ pid = [int]$parts[0]; process = $parts[1]; usedMB = [int]$parts[2] }
        $procs += $p
      }
    }
  }
} catch { }

if ($procs.Count -eq 0) {
  Write-Log "No GPU processes reported by nvidia-smi (or driver doesn't support compute-apps query)."
} else {
  Write-Log "GPU processes:"
  $procs | ForEach-Object { Write-Host "PID=$($_.pid) Name=$($_.process) UsedMB=$($_.usedMB)" }
}

if ($Kill) {
  if (-not $Yes) {
    Write-Host "About to kill the above PIDs. Re-run with -Kill -Yes to proceed."; exit 0
  }
  foreach ($p in $procs) {
    try {
      if ($p.pid -ne $PID) {
        Write-Log "Killing PID $($p.pid) ($($p.process))"
        Stop-Process -Id $p.pid -Force -ErrorAction Stop
      } else { Write-Log "Skipping current PS PID $PID" }
    } catch { Write-Log "Failed to kill PID $($p.pid): $_" }
  }
  Write-Log "Kill attempts complete. Re-run agent startup.";
}

exit 0
