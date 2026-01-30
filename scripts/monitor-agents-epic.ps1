param(
    [string]$MappingFile = ".continue/agents-epic.json",
    [int]$IntervalSeconds = 10,
    [int]$MaxVramGB = 32,
    [int]$MaxParallel = 3,
    [int]$HealthTimeoutSec = 5,
    [switch]$DryRun,
    [switch]$PreferMaxAgent
)

function Read-Mapping {
    param($path)
    if (-not (Test-Path $path)) { return @() }
    try { return Get-Content $path -Raw | ConvertFrom-Json } catch { return @() }
}

# Load roles to map agent -> primaryRole (best-effort)
function Read-Roles {
    param($path='.continue/agent-roles.json')
    if (-not (Test-Path $path)) { return @{} }
    try {
        $r = Get-Content $path -Raw | ConvertFrom-Json
        $m = @{}
        foreach ($a in $r.agents) {
            $m[$a.name] = @{ primaryRole = $a.primaryRole; priority = $a.priority; vram = ($a.resources.vramGB -as [int]); memory = ($a.resources.memoryGB -as [int]); cpus = ($a.resources.cpus -as [int]) }
        }
        return $m
    } catch { return @{} }
}

# Read config.agent to find per-agent health probe definitions
function Read-Config {
    param($path='.continue/config.agent')
    if (-not (Test-Path $path)) { return @{ agents=@() } }
    try { return Get-Content $path -Raw | ConvertFrom-Json } catch { return @{ agents=@() } }
}

# Atomic mapping writer
function Write-Mapping {
    param($m)
    $tmp = [System.IO.Path]::GetTempFileName()
    try { $m | ConvertTo-Json -Depth 5 | Out-File -FilePath $tmp -Encoding UTF8; Move-Item -Path $tmp -Destination $MappingFile -Force } catch { Write-Output ("[Monitor] Failed to write mapping: {0}" -f $_) }
}

# Probe an agent's health using either an HTTP URL or a health command (CLI)
function Check-AgentHealth {
    param(
        $agentEntry, # mapping entry (object)
        $def,        # config.agent entry (object) optional
        $timeoutSec
    )
    try {
        $healthUrl = $null
        $healthCmd = $null
        if ($agentEntry.healthUrl) { $healthUrl = $agentEntry.healthUrl }
        if ($def -and $def.options -and $def.options.healthUrl) { $healthUrl = $def.options.healthUrl }
        if ($def -and $def.options -and $def.options.healthCmd) { $healthCmd = $def.options.healthCmd }

        if ($healthUrl) {
            try {
                $resp = Invoke-RestMethod -Uri $healthUrl -Method Get -TimeoutSec $timeoutSec -ErrorAction Stop
                return @{ ok = $true; detail = 'http:ok' }
            } catch { return @{ ok = $false; detail = ('http:error {0}' -f $_) } }
        }

        if ($healthCmd) {
            # Run the health command in a separate PowerShell process and capture exit code
            $exe = 'powershell'
            $args = "-NoProfile -ExecutionPolicy Bypass -Command `"& { $healthCmd ; exit `$LASTEXITCODE }`""
            $p = Start-Process -FilePath $exe -ArgumentList $args -WindowStyle Hidden -PassThru
            try { $p.WaitForExit($timeoutSec * 1000) } catch { }
            if (-not $p.HasExited) { try { $p.Kill() } catch { } ; return @{ ok = $false; detail = 'cmd:timeout' } }
            if ($p.ExitCode -eq 0) { return @{ ok = $true; detail = ('cmd:exit0') } } else { return @{ ok = $false; detail = ('cmd:exit{0}' -f $p.ExitCode) } }
        }

        # No probe configured; treat as healthy by default
        return @{ ok = $true; detail = 'no-probe' }
    } catch { return @{ ok = $false; detail = ('probe-exception {0}' -f $_) } }
}

function Is-ProcessAlive {
    param($pid)
    try { return Get-Process -Id $pid -ErrorAction Stop | Out-Null; return $true } catch { return $false }
}

# Return basic process stats: total CPU seconds and working set (MB)
function Get-ProcessStats {
    param($pid)
    try {
        $p = Get-Process -Id $pid -ErrorAction Stop
        $cpuSec = 0
        try { $cpuSec = [math]::Round($p.CPU,3) } catch { $cpuSec = 0 }
        $wsMB = [math]::Round(($p.WorkingSet64 / 1MB),2)
        return @{ cpuSec = $cpuSec; workingSetMB = $wsMB }
    } catch { return @{ cpuSec = 0; workingSetMB = 0 } }
}

# Normalize agent resource access (handles legacy flat vram or nested resources)
function Get-AgentResources {
    param($agent)
    $v=0; $m=0; $c=0
    if ($agent -and $agent.resources) {
        $v = ($agent.resources.vramGB -as [int])
        $m = ($agent.resources.memoryGB -as [int])
        $c = ($agent.resources.cpus -as [int])
    } else {
        if ($agent.vram) { $v = ($agent.vram -as [int]) }
        if ($agent.memoryGB) { $m = ($agent.memoryGB -as [int]) }
        if ($agent.cpus) { $c = ($agent.cpus -as [int]) }
    }
    return @{ vram = $v; memory = $m; cpus = $c }
}

Write-Output ("[Monitor] Watching {0} (interval {1}s)" -f $MappingFile, $IntervalSeconds)

# Setup graceful shutdown for Ctrl-C
$global:scriptStopping = $false
$null = Register-EngineEvent Console.CancelKeyPress -Action {
    Write-Output "[Monitor] SIGINT received — stopping monitor and leaving mapping as-is."
    $global:scriptStopping = $true
}

# In-memory rolling sampler for per-agent stats used to compute rolling averages
$agentSamples = @{}
$RollingWindow = 60 # number of samples to keep (e.g., 60 samples * IntervalSeconds => 5m at 5s interval)

while ($true) {
    if ($global:scriptStopping) { Write-Output '[Monitor] Exiting due to SIGINT'; break }
    $agents = Read-Mapping -path $MappingFile
    $roleMap = Read-Roles
    $configDefs = Read-Config
    # Check for autoscale apply requests written by autoscale controller
    $applyPath = '.continue/autoscale-apply.request'
    if (Test-Path $applyPath) {
        try {
            $req = Get-Content $applyPath -Raw | ConvertFrom-Json
            $sugg = $null
            if ($req.PSObject.Properties.Name -contains 'suggestion') { $sugg = $req.suggestion }
            elseif ($req.PSObject.Properties.Name -contains 'recommendation') { $sugg = $req.recommendation }
            else { $sugg = $req }

            $newParallel = $sugg.MaxParallel -as [int]
            $newVram = $sugg.MaxVramGB -as [int]
            if ($null -ne $newParallel -and $newParallel -gt 0 -and $null -ne $newVram -and $newVram -ge 0) {
                Write-Output ("[Monitor] Autoscale apply request detected: MaxParallel={0}, MaxVramGB={1}" -f $newParallel, $newVram)
                # Require manual approval file before applying to production runtimes
                $approvePath = '.continue/autoscale-approve'
                if (-not (Test-Path $approvePath)) {
                    Write-Output '[Monitor] Autoscale request present but no approval file (.continue/autoscale-approve) found; skipping apply.'
                    continue
                }
                if (-not $DryRun) {
                    # apply atomically by writing an applied file and removing request
                    $applied = @{ appliedAt = (Get-Date).ToString('o'); MaxParallel = $newParallel; MaxVramGB = $newVram; source = 'autoscale' }
                    $appliedPath = '.continue/autoscale-applied.json'
                    $tmp = [System.IO.Path]::GetTempFileName()
                    $applied | ConvertTo-Json -Depth 5 | Out-File -FilePath $tmp -Encoding UTF8
                    Move-Item -Path $tmp -Destination $appliedPath -Force
                    # Set runtime variables
                    $MaxParallel = $newParallel
                    $MaxVramGB = $newVram
                    # remove request and approval token (single-use)
                    Remove-Item $applyPath -Force
                    Remove-Item $approvePath -Force
                    Write-Output ("[Monitor] Applied autoscale suggestion; new MaxParallel={0}, MaxVramGB={1}" -f $MaxParallel, $MaxVramGB)
                } else {
                    Write-Output ("[Monitor] DryRun - would apply autoscale suggestion: MaxParallel={0}, MaxVramGB={1}" -f $newParallel, $newVram)
                }
            } else {
                Write-Output '[Monitor] Autoscale apply request malformed or missing fields; ignoring.'
            }
        } catch { Write-Output ("[Monitor] Failed to process autoscale apply request: {0}" -f $_) }
    }
    # Enforce single coordinator: if multiple coordinator processes reported, stop extras (keep the earliest/highest-priority if available)
    try {
        $coordEntries = $agents | Where-Object { ($roleMap.ContainsKey($_.name) -and $roleMap[$_.name] -eq 'coordinator') -or ($_.primaryRole -eq 'coordinator') }
        $aliveCoords = @()
        foreach ($ce in $coordEntries) { if ($ce.pid -and (Is-ProcessAlive -pid $ce.pid)) { $aliveCoords += $ce } }
        if ($aliveCoords.Count -gt 1) {
            Write-Output "[Monitor] Multiple coordinator processes detected: $($aliveCoords.Count). Enforcing single coordinator."
            # choose one to keep: prefer lowest priority value if present, else earliest startedAt
            $keep = $aliveCoords | Sort-Object startedAt | Select-Object -First 1
            foreach ($c in $aliveCoords) {
                if ($c.pid -ne $keep.pid) {
                    Write-Output ("[Monitor] Stopping extra coordinator {0} (pid {1})" -f $c.name, $c.pid)
                    if (-not $DryRun) { Try { Stop-Process -Id $c.pid -Force -ErrorAction Stop } Catch { Write-Output ("[Monitor] Failed to stop {0}: {1}" -f $c.name, $_) } }
                }
            }
        }
    } catch { }

    
    foreach ($a in $agents) {
        $name = $a.name
        $agentPid = $a.pid
        if (-not $agentPid) { Write-Output ("[Monitor] {0}: no pid recorded" -f $name); continue }
        $alive = Is-ProcessAlive -pid $agentPid
        if ($alive) {
            # Run health probe if configured
            $def = $configDefs.agents | Where-Object { $_.name -eq $name } | Select-Object -First 1
            $probe = Check-AgentHealth -agentEntry $a -def $def -timeoutSec $HealthTimeoutSec
            $a.health = if ($probe.ok) { 'healthy' } else { 'unhealthy' }
            $a.lastHealthCheck = (Get-Date).ToString('o')
            # collect runtime stats and append to telemetry
            $stats = Get-ProcessStats -pid $agentPid
            $tele = @{ ts = (Get-Date).ToString('o'); name = $name; pid = $agentPid; cpuSec = $stats.cpuSec; workingSetMB = $stats.workingSetMB }
            try { $tele | ConvertTo-Json -Compress | Add-Content -Path '.continue/agent-runtime-telemetry.log' -Encoding UTF8 } catch { }
            # maintain in-memory rolling samples for this agent
            if (-not $agentSamples.ContainsKey($name)) { $agentSamples[$name] = New-Object System.Collections.ArrayList }
            $prevCpu = $null
            if ($agentSamples[$name].Count -gt 0) { $prev = $agentSamples[$name][$agentSamples[$name].Count - 1]; $prevCpu = $prev.cpuSec }
            $cpuRate = 0
            if ($prevCpu -ne $null) { try { $cpuRate = [math]::Round((($stats.cpuSec - $prevCpu) / [double]$IntervalSeconds),4) } catch { $cpuRate = 0 } }
            $sample = @{ ts = (Get-Date).ToString('o'); cpuSec = $stats.cpuSec; cpuRate = $cpuRate; workingSetMB = $stats.workingSetMB }
            $null = $agentSamples[$name].Add($sample)
            while ($agentSamples[$name].Count -gt $RollingWindow) { $agentSamples[$name].RemoveAt(0) }
            # also write mapping (with latest probe info)
            Write-Mapping -m $agents

            if (-not $probe.ok) {
                Write-Output ("[Monitor] {0} responded unhealthy ({1}) - attempting restart" -f $name,$probe.detail)
                if ($DryRun) { Write-Output ("[Monitor] DryRun - would restart unhealthy {0}" -f $name); continue }
                try { Stop-Process -Id $agentPid -Force -ErrorAction Stop } catch { }

                # Attempt restart: use entry to launch via powershell/python like orchestrator.
                $entry = $a.entry
                $log = $a.log
                if ($entry -match '\.py$') {
                    Start-Process -FilePath "python" -ArgumentList $entry -NoNewWindow -WindowStyle Hidden
                } else {
                    $command = "& { & '$entry' } 2>&1 | Tee-Object -FilePath '$log'"
                    Start-Process -FilePath "powershell" -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-Command",$command -WindowStyle Hidden
                }
                Start-Sleep -Seconds 1
                # Refresh mapping: attach new pid if discovered
                try {
                    $basename = Split-Path $entry -Leaf
                    $proc = Get-Process | Where-Object { $_.Path -and ($_.Path -like "*$basename*") } | Sort-Object StartTime -Descending | Select-Object -First 1
                    if ($proc) {
                        foreach ($na in $agents) { if ($na.name -eq $name) { $na.pid = $proc.Id; $na.status = 'running' } }
                        Write-Mapping -m $agents
                        Write-Output ("[Monitor] Restarted {0} -> pid {1}" -f $name, $proc.Id)
                    }
                } catch { }
            }

            continue
        }

        $msg = ("[Monitor] {0} (pid {1}) not running" -f $name, $agentPid)
        Write-Output $msg
        if ($DryRun) { Write-Output (("[Monitor] DryRun - would attempt restart for {0}" -f $name)); continue }

        # Attempt restart: use entry to launch via powershell/python like orchestrator.
        $entry = $a.entry
        $log = $a.log
        Write-Output "[Monitor] Attempting restart for $name -> $entry (log: $log)"

        if ($entry -match '\.py$') {
            Start-Process -FilePath "python" -ArgumentList $entry -NoNewWindow -WindowStyle Hidden
        } else {
            $command = "& { & '$entry' } 2>&1 | Tee-Object -FilePath '$log'"
            Start-Process -FilePath "powershell" -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-Command",$command -WindowStyle Hidden
        }

        Start-Sleep -Seconds 1
        # Refresh mapping: write new pid if process started (best-effort)
        $newAgents = Read-Mapping -path $MappingFile
        # naive approach: replace entry with updated pid via Get-Process -Name matching entry basename
        try {
            $basename = Split-Path $entry -Leaf
            $proc = Get-Process | Where-Object { $_.Path -and ($_.Path -like "*$basename*") } | Sort-Object StartTime -Descending | Select-Object -First 1
            if ($proc) {
                foreach ($na in $newAgents) { if ($na.name -eq $name) { $na.pid = $proc.Id } }
                $tmp = [System.IO.Path]::GetTempFileName()
                $newAgents | ConvertTo-Json -Depth 5 | Out-File -FilePath $tmp -Encoding UTF8
                Move-Item -Path $tmp -Destination $MappingFile -Force
                Write-Output ("[Monitor] Restarted {0} -> pid {1}" -f $name, $proc.Id)
            }
        } catch { }
    }

    # Schedule queued agents when capacity allows (vram-aware)
    try {
        $currentVram = 0
        foreach ($ag in $agents) {
            if ($global:scriptStopping) { break }
            $ares = Get-AgentResources -agent $ag
            if ($ares.vram -and $ag.pid -and (Is-ProcessAlive -pid $ag.pid)) { $currentVram += $ares.vram }
        }

        # sample overall system resources to influence eviction heuristics
        $sysFreeKB = 0
        try { $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue; if ($os) { $sysFreeKB = ($os.FreePhysicalMemory -as [int]) } } catch { }
        $sysFreeGB = [math]::Round(($sysFreeKB/1024/1024),2)
        $cpuLoad = 0
        try { $cpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue } catch { }

        $queued = $agents | Where-Object { ($_.status -eq 'queued') -or (-not $_.status) }
        # If requested, prefer starting queued agents with highest estimated vram first
        if ($PreferMaxAgent) {
            $queued = $queued | Sort-Object @{ Expression = { (Get-AgentResources -agent $_).vram } } -Descending
            Write-Output "[Monitor] PreferMaxAgent enabled: ordering queued agents by vram desc"
        }
        foreach ($q in $queued) {
            $qres = Get-AgentResources -agent $q
            $qv = $qres.vram
            $qmem = $qres.memory

            # Enforce MaxParallel: count alive running agents and defer if limit reached
            $runningCount = 0
            try { $runningCount = (($agents | Where-Object { $_.status -eq 'running' -and $_.pid -and (Is-ProcessAlive -pid $_.pid) }) | Measure-Object).Count } catch { $runningCount = 0 }
            if ($MaxParallel -gt 0 -and $runningCount -ge $MaxParallel) {
                Write-Output ("[Monitor] MaxParallel limit reached ({0}) - deferring start of {1}" -f $MaxParallel, $q.name)
                continue
            }
            if ($currentVram + $qv -le $MaxVramGB) {
                # Enough capacity, start normally
            } else {
                # Need to consider evicting lower-priority running agents
                $roleInfo = $roleMap[$q.name]
                $qPriority = 'medium'
                if ($roleInfo -and $roleInfo.priority) { $qPriority = $roleInfo.priority }
                $prioWeight = @{ 'low' = 1; 'medium' = 2; 'high' = 3 }
                $qWeight = $prioWeight[$qPriority] -as [int]

                # Build list of running candidates (exclude coordinators)
                $running = $agents | Where-Object { $_.status -eq 'running' -and $_.pid -and (Is-ProcessAlive -pid $_.pid) }
                $candidates = @()
                foreach ($r in $running) {
                    $info = $roleMap[$r.name]
                    $rPriority = 'medium'
                    if ($info -and $info.priority) { $rPriority = $info.priority }
                    $rWeight = $prioWeight[$rPriority] -as [int]
                    $rres = Get-AgentResources -agent $r
                    $rVram = $rres.vram
                    $rMem = $rres.memory
                    # compute rolling averages if available
                    $avgCpuRate = 0
                    $avgMem = $rMem
                    if ($agentSamples.ContainsKey($r.name) -and $agentSamples[$r.name].Count -gt 0) {
                        $arr = $agentSamples[$r.name]
                        try { $avgCpuRate = [math]::Round((($arr | Measure-Object -Property cpuRate -Average).Average),4) } catch { $avgCpuRate = 0 }
                        try { $avgMem = [math]::Round((($arr | Measure-Object -Property workingSetMB -Average).Average),2) } catch { $avgMem = $rMem }
                    }
                    $rPrimary = $null
                    if ($info -and $info.primaryRole) { $rPrimary = $info.primaryRole }
                    if ($rPrimary -eq 'coordinator') { continue }
                    # Candidate only if its priority weight is lower than queued agent (or if system under pressure, consider all)
                    if ($rWeight -lt $qWeight -or ($sysFreeGB -lt 6 -or $cpuLoad -gt 80)) {
                        $candidates += [PSCustomObject]@{ name=$r.name; pid=$r.pid; vram=$rVram; memory=$rMem; avgMem=$avgMem; avgCpuRate=$avgCpuRate; weight=$rWeight; startedAt=$r.startedAt }
                    }
                }

                if ($candidates.Count -gt 0) {
                    # Sort candidates by weight asc. If system under memory/CPU pressure prefer evicting high-memory or high-cpu agents.
                    if ($sysFreeGB -lt 4 -or $cpuLoad -gt 85) {
                        $candidates = $candidates | Sort-Object @{ Expression = { $_.weight } }, @{ Expression = { -($_.avgMem) } }, @{ Expression = { -($_.avgCpuRate) } }
                    } else {
                        $candidates = $candidates | Sort-Object weight, startedAt
                    }
                    $freed = 0
                    $toStop = @()
                    foreach ($cand in $candidates) {
                        $toStop += $cand
                        $freed += ($cand.vram -as [int])
                        if ($currentVram + $qv - $freed -le $MaxVramGB) { break }
                    }

                    if ($toStop.Count -gt 0) {
                        Write-Output ("[Monitor] Evicting {0} lower-priority agents to make room for {1}" -f $toStop.Count, $q.name)
                        foreach ($s in $toStop) {
                            Write-Output ("[Monitor] Evict candidate {0} pid {1} vram {2} memory {3}" -f $s.name, $s.pid, $s.vram, $s.memory)
                            if (-not $DryRun) {
                                Try { Stop-Process -Id $s.pid -Force -ErrorAction Stop; Write-Output ("[Monitor] Stopped {0}" -f $s.name) } Catch { Write-Output ("[Monitor] Failed to stop {0}: {1}" -f $s.name, $_) }
                                # Update mapping to clear pid and mark stopped
                                $nm = Read-Mapping -path $MappingFile
                                foreach ($na in $nm) { if ($na.name -eq $s.name) { $na.pid = $null; $na.status = 'stopped' } }
                                $tmp = [System.IO.Path]::GetTempFileName()
                                $nm | ConvertTo-Json -Depth 5 | Out-File -FilePath $tmp -Encoding UTF8
                                Move-Item -Path $tmp -Destination $MappingFile -Force
                            } else {
                                Write-Output ("[Monitor] DryRun - would stop {0} (pid {1})" -f $s.name, $s.pid)
                            }
                        }
                        # Recompute currentVram after eviction
                        $currentVram = 0
                        foreach ($ag2 in (Read-Mapping -path $MappingFile)) { if ($ag2.vram -and $ag2.pid -and (Is-ProcessAlive -pid $ag2.pid)) { $currentVram += ($ag2.vram -as [int]) } }
                    }
                }
            }

            if ($currentVram + $qv -le $MaxVramGB) {
                Write-Output ("[Monitor] Scheduling queued agent {0} (vram={1}); currentVram={2}, MaxVramGB={3}" -f $q.name, $qv, $currentVram, $MaxVramGB)
                if (-not $DryRun) {
                    $entry = $q.entry
                    $log = $q.log
                    if ($entry -match '\.py$') {
                        Start-Process -FilePath "python" -ArgumentList $entry -NoNewWindow -WindowStyle Hidden
                    } else {
                        $command = "& { & '$entry' } 2>&1 | Tee-Object -FilePath '$log'"
                        Start-Process -FilePath "powershell" -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-Command",$command -WindowStyle Hidden
                    }
                    Start-Sleep -Seconds 1
                    # Refresh mapping and attach pid if found
                    $newAgents = Read-Mapping -path $MappingFile
                    try {
                        $basename = Split-Path $entry -Leaf
                        $proc = Get-Process | Where-Object { $_.Path -and ($_.Path -like "*$basename*") } | Sort-Object StartTime -Descending | Select-Object -First 1
                        if ($proc) {
                            foreach ($na in $newAgents) { if ($na.name -eq $q.name) { $na.pid = $proc.Id; $na.status = 'running' } }
                            $tmp = [System.IO.Path]::GetTempFileName()
                            $newAgents | ConvertTo-Json -Depth 5 | Out-File -FilePath $tmp -Encoding UTF8
                            Move-Item -Path $tmp -Destination $MappingFile -Force
                            Write-Output ("[Monitor] Started queued {0} -> pid {1}" -f $q.name, $proc.Id)
                            $currentVram += $qv
                        }
                    } catch { }
                } else {
                    Write-Output ("[Monitor] DryRun - would start queued {0} (vram={1})" -f $q.name, $qv)
                    $currentVram += $qv
                }
            }
        }
    } catch { }

    Start-Sleep -Seconds $IntervalSeconds
}
