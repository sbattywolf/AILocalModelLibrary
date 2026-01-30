<#
.SYNOPSIS
  Orchestrate running all agents declared in `.continue/config.agent`.

.DESCRIPTION
  Reads `.continue/config.agent`, lists each agent, and in DryRun prints
  the commands that would be executed. In run mode it starts each agent as a
  background process (PowerShell invocation of the agent `entry`), captures
  stdout/stderr to `logs/agent-<name>.log`, and writes a mapping to
  `.continue/agents-epic.json` (atomic write).

.PARAMETER DryRun
  If supplied, do not start processes; only print planned actions.

.PARAMETER MaxParallel
  Maximum parallel processes (0 = unlimited). Default 3.

.EXAMPLE
  # Dry run
  .\scripts\run-agents-epic.ps1 -DryRun

  # Start agents
  .\scripts\run-agents-epic.ps1
#>
param(
  [switch]$DryRun,
  [int]$MaxParallel = 3,
  [int]$MaxVramGB = 32,
  [int]$StartupTimeout = 20,
  [switch]$SkipTurbo,
  [switch]$PreferMaxAgent,
  [string]$PythonExe = $null
)

function Write-Log { param($m) $t=(Get-Date).ToString('s'); $line="$t`t$m"; Write-Host $line }

$configPath = '.continue/config.agent'
if (-not (Test-Path $configPath)) { Write-Log "Missing $configPath"; exit 2 }

try { $cfg = Get-Content $configPath -Raw | ConvertFrom-Json -ErrorAction Stop } catch { Write-Log "Failed to parse config: $_"; exit 2 }

if (-not (Test-Path 'logs')) { New-Item -ItemType Directory -Path 'logs' | Out-Null }
if (-not (Test-Path '.continue')) { New-Item -ItemType Directory -Path '.continue' | Out-Null }

$agents = $cfg.agents

# Ensure roleResources is initialized (avoid null when role file missing)
if (-not $roleResources) { $roleResources = @{} }

# If requested, prefer scheduling the highest-capability (highest estimated VRAM) agents first.
# Build an agent->vram estimate map and order descending when -PreferMaxAgent is supplied.
$agentsOrdered = $agents
if ($PreferMaxAgent) {
  $agentVramMap = @()
  foreach ($aa in $agents) {
    $san = ($aa.name -replace '[^A-Za-z0-9_-]','-')
    $est = 0
    if ($roleResources.ContainsKey($san)) { $est = ($roleResources[$san] -as [int]) }
    $agentVramMap += [PSCustomObject]@{ agent = $aa; vram = $est }
  }
  $agentsOrdered = $agentVramMap | Sort-Object -Property vram -Descending | ForEach-Object { $_.agent }
  Write-Log "PreferMaxAgent: ordering agents by estimated vram descending"
} else {
  $agentsOrdered = $agents
}

# Load role resource estimates to respect per-agent VRAM when scheduling
$rolesPath = '.continue/agent-roles.json'
$roleResources = @{}
if (Test-Path $rolesPath) {
  try { $r = Get-Content $rolesPath -Raw | ConvertFrom-Json -ErrorAction Stop; foreach ($ra in $r.agents) { $roleResources[$ra.name] = ($ra.resources.vramGB -as [int]) } } catch { }
}
if (-not $agents -or $agents.Count -eq 0) { Write-Log 'No agents found in config.agent'; exit 0 }

# Determine Python executable to use for .py agent entries
$pythonExe = $PythonExe
if (-not $pythonExe) {
  $pyCandidates = @('python','py','python3')
  foreach ($c in $pyCandidates) {
    $cmd = Get-Command $c -ErrorAction SilentlyContinue
    if ($cmd) { $pythonExe = $cmd.Source; break }
  }
}
if (-not $pythonExe) { Write-Log "Warning: python executable not found in PATH; .py agents may fail to start." } else { Write-Log "Using Python executable: $pythonExe" }

$map = @()
$jobs = @()
$currentVram = 0

# Helper: atomic write of mapping
function Write-Mapping {
  param($m)
  $tmp = '.continue/agents-epic.json.tmp'
  try { $m | ConvertTo-Json -Depth 5 | Set-Content -Path $tmp -Encoding UTF8; Move-Item -Path $tmp -Destination '.continue/agents-epic.json' -Force } catch { Write-Log "Failed to write mapping: $_" }
}

# Graceful Ctrl-C / SIGINT handling
$global:scriptStopping = $false
$null = Register-EngineEvent Console.CancelKeyPress -Action {
  Write-Log "SIGINT received - shutting down started agents..."
  $global:scriptStopping = $true
  try {
    foreach ($pj in $jobs) { if ($pj -and $pj.Id) { Try { Stop-Process -Id $pj.Id -Force -ErrorAction Stop } Catch { } } }
  } catch { }
  try {
    foreach ($m in $map) { if ($m.pid) { Try { Stop-Process -Id $m.pid -Force -ErrorAction Stop } Catch { } $m.pid = $null; $m.status = 'stopped' } }
    Write-Mapping -m $map
  } catch { }
  Write-Log "Shutdown complete. Exiting."; exit 130
}

foreach ($a in $agentsOrdered) {
    $name = $a.name -replace '[^A-Za-z0-9_-]','-'
    $entry = $a.entry
    $model = $null
    if ($a.options -and $a.options.model) { $model = $a.options.model }

  if ($SkipTurbo -and $a.options -and $a.options.mode -and ($a.options.mode -eq 'turbo')) {
    Write-Log "Skipping turbo agent: $name"
    $map += [ordered]@{ name=$name; entry=$entry; model=$model; log="logs/agent-$name.log"; status='skipped' }
    continue
  }

    $logFile = "logs/agent-$name.log"
    $startedAt = (Get-Date).ToString('o')

    $agentVram = 0
    if ($roleResources.ContainsKey($name)) { $agentVram = $roleResources[$name] }

    if ($DryRun) {
      # In DryRun show scheduling decision (would run vs would queue)
      if ($currentVram + $agentVram -le $MaxVramGB) {
        Write-Log "[DryRun] SCHEDULED Agent: $name  entry=$entry  model=$model  log=$logFile  vram=$agentVram"
        $map += [ordered]@{ name=$name; entry=$entry; model=$model; log=$logFile; status='scheduled'; vram=$agentVram }
        $currentVram += $agentVram
      } else {
        Write-Log "[DryRun] QUEUED Agent: $name  entry=$entry  model=$model  log=$logFile  vram=$agentVram (exceeds MaxVramGB=$MaxVramGB)"
        $map += [ordered]@{ name=$name; entry=$entry; model=$model; log=$logFile; status='queued'; vram=$agentVram }
      }
      continue
    }

    # Build a safe command that captures combined stdout/stderr via Tee-Object.
    # Use the script entry extension to choose an appropriate runner (python for .py, powershell for .ps1).
    $ext = [System.IO.Path]::GetExtension($entry)
    # We'll start agents directly with Start-Process below; no intermediate shell command string needed.


    # If launching this agent would exceed MaxVramGB, queue it instead of starting now
    if ($currentVram + $agentVram -gt $MaxVramGB) {
      Write-Log "Queueing agent $name (vram=$agentVram) because currentVram=$currentVram would exceed MaxVramGB=$MaxVramGB"
      $map += [ordered]@{ name=$name; entry=$entry; model=$model; log=$logFile; status='queued'; vram=$agentVram }
      continue
    }

    # Start the agent with direct Start-Process argument lists and redirect output to the log file.
    Write-Log "Starting agent $name -> $entry (log: $logFile)"
    if ($ext -eq '.py') {
      $exe = if ($pythonExe) { $pythonExe } else { 'python' }
      try {
        $proc = Start-Process -FilePath $exe -ArgumentList @($entry) -RedirectStandardOutput $logFile -RedirectStandardError "$logFile.err" -WindowStyle Hidden -PassThru
      } catch {
        # Fallback to non-redirected start if redirection not supported
        $proc = Start-Process -FilePath $exe -ArgumentList @($entry) -WindowStyle Hidden -PassThru
      }
    } else {
      $safePrompt = 'StressRun'
      try {
        $proc = Start-Process -FilePath powershell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$entry,'-Agent',$name,'-Prompt',$safePrompt) -RedirectStandardOutput $logFile -RedirectStandardError "$logFile.err" -WindowStyle Hidden -PassThru
      } catch {
        $proc = Start-Process -FilePath powershell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$entry,'-Agent',$name,'-Prompt',$safePrompt) -WindowStyle Hidden -PassThru
      }
    }
    # Startup watchdog: ensure process did not immediately exit
    
    $startupSucceeded = $true
    for ($s=0; $s -lt $StartupTimeout; $s++) {
      Start-Sleep -Seconds 1
      try { $proc.Refresh() } catch { }
      if ((Test-Path $logFile) -and ((Get-Item $logFile).Length -gt 0)) { break }
      if ($proc.HasExited) { break }
    }

    # If process exited during startup, inspect exit code
    if ($proc.HasExited) {
      try { $exit = $proc.ExitCode } catch { $exit = $null }
      if ($exit -eq 0) {
        Write-Log "Agent $name exited cleanly during startup (exit 0). Marking as completed. See $logFile"
        $map += [ordered]@{ name=$name; entry=$entry; model=$model; log=$logFile; pid=$null; startedAt=$startedAt; status='completed'; exitCode=0; vram=$agentVram }
        continue
      } else {
        Write-Log "Agent $name exited during startup (within $StartupTimeout s). Marking as failed (exit $exit). See $logFile"
        $map += [ordered]@{ name=$name; entry=$entry; model=$model; log=$logFile; pid=$null; startedAt=$startedAt; status='failed'; exitCode=$exit; vram=$agentVram }
        continue
      }
    }

    $map += [ordered]@{ name=$name; entry=$entry; model=$model; log=$logFile; pid=$proc.Id; startedAt=$startedAt; status='running'; vram=$agentVram }
    $jobs += $proc
    $currentVram += $agentVram

    # If MaxParallel is set and we've reached it, wait for any to exit (best-effort)
    if ($MaxParallel -gt 0 -and $jobs.Count -ge $MaxParallel) {
      Write-Log "Reached MaxParallel ($MaxParallel) - waiting for processes to free up"
      # Wait with a short timeout loop to make cancellation responsive
      $waitId = ($jobs | Select-Object -First 1).Id
      while (-not $global:scriptStopping) {
        try { Wait-Process -Id $waitId -Timeout 5 } catch { }
        $jobs = $jobs | Where-Object { $_.HasExited -eq $false }
        if ($jobs.Count -lt $MaxParallel) { break }
      }
    }
}

# Write mapping atomically
Write-Mapping -m $map
Write-Log "Wrote mapping to .continue/agents-epic.json"

if (-not $DryRun) { Write-Log 'Started agents (background). Use task manager or logs to inspect.' }

exit 0
