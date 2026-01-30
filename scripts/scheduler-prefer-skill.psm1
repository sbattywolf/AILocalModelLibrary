function Invoke-PreferSkillScheduler {
    param(
        [string]$AgentsJson = ".\.continue\agent-roles.json",
        [string]$BacklogJson = ".\sample-backlog.json",
        [string]$OutPath = ".\.continue\agents_proposal.json",
        [switch]$DryRun
    )

    function Load-Json($path) {
        if (Test-Path $path) { Get-Content $path -Raw | ConvertFrom-Json } else { return $null }
    }

    $agentsRaw = Load-Json $AgentsJson
    $backlog = Load-Json $BacklogJson

    # Normalize agents shape
    $agentsList = @()
    if ($agentsRaw -eq $null) { Write-Warning "Agents file not found: $AgentsJson"; $agentsList=@() }
    elseif ($agentsRaw -is [System.Collections.IEnumerable] -and -not ($agentsRaw -is [string])) { $agentsList = $agentsRaw }
    elseif ($agentsRaw.PSObject.Properties.Name -contains 'agents') { $agentsList = $agentsRaw.agents }
    else { $agentsList = @($agentsRaw) }

    $agents = @()
    foreach ($a in $agentsList) {
        if ($null -ne $a.agentName -and $a.agentName -ne '') { $name = $a.agentName }
        elseif ($null -ne $a.name -and $a.name -ne '') { $name = $a.name }
        elseif ($null -ne $a.id -and $a.id -ne '') { $name = $a.id }
        elseif ($null -ne $a.key -and $a.key -ne '') { $name = $a.key }
        else { $name = '' }

        if ($null -ne $a.capacityPoints) { try { $capacity = [int]$a.capacityPoints } catch { $capacity = 8 } }
        elseif ($null -ne $a.capacity) { try { $capacity = [int]$a.capacity } catch { $capacity = 8 } }
        elseif ($null -ne $a.points) { try { $capacity = [int]$a.points } catch { $capacity = 8 } }
        else { $capacity = 8 }
        $skills = @()
        if ($a.skills) {
            if ($a.skills -is [System.Array]) { $skills = $a.skills }
            elseif ($a.skills -is [System.Collections.Hashtable]) { $skills = $a.skills.Keys }
            else { $skills = @($a.skills) }
        }
        $agents += [PSCustomObject]@{
            Name = $name
            CapacityPoints = [int]$capacity
            AssignedPoints = 0
            Skills = ($skills | ForEach-Object { $_.ToString().ToLower() })
            Assignments = @()
        }
    }

    if (-not $backlog) { Write-Warning "Backlog file not found: $BacklogJson"; $backlog = @() }

    # Normalize backlog items
    $items = @()
    if ($backlog -is [System.Array]) { $items = $backlog } elseif ($backlog.items) { $items = $backlog.items } else { $items = @($backlog) }

    foreach ($it in $items) {
        if ($null -ne $it.points) { try { $points = [int]$it.points } catch { $points = 1 } }
        elseif ($null -ne $it.estimate) { try { $points = [int]$it.estimate } catch { $points = 1 } }
        else { $points = 1 }
        $keywords = @()
        if ($it.skills) {
            if ($it.skills -is [System.Array]) { $keywords = $it.skills } elseif ($it.skills -is [string]) { $keywords = $it.skills -split ',' }
        }
        if ($it.tags) { $keywords += ($it.tags -split ',') }
        $keywords = ($keywords | ForEach-Object { $_.ToString().Trim().ToLower() } | Where-Object { $_ -ne '' })

        # find candidate agents with matching skills and enough remaining capacity
        $candidates = @()
        foreach ($ag in $agents) {
            $remaining = $ag.CapacityPoints - $ag.AssignedPoints
            $matchCount = 0
            foreach ($k in $keywords) { if ($ag.Skills -contains $k) { $matchCount++ } }
            if ($matchCount -gt 0 -and $remaining -ge $points) { $candidates += [PSCustomObject]@{ Agent=$ag; Score=$matchCount; Remaining=$remaining } }
        }

        if ($candidates.Count -gt 0) {
            # pick best candidate: highest score, then most remaining, then name
            $pick = $candidates | Sort-Object -Property @{Expression='Score';Descending=$true}, @{Expression='Remaining';Descending=$true}, @{Expression={'$($_.Agent.Name)'}} | Select-Object -First 1
            if ($null -ne $it.id) { $assignId = $it.id } elseif ($null -ne $it.key) { $assignId = $it.key } elseif ($null -ne $it.title) { $assignId = $it.title } else { $assignId = '' }
            if ($null -ne $it.title) { $assignTitle = $it.title } elseif ($null -ne $it.name) { $assignTitle = $it.name } else { $assignTitle = '' }
            $pick.Agent.Assignments += [PSCustomObject]@{ Id = $assignId; Title = $assignTitle; Points = [int]$points }
            $pick.Agent.AssignedPoints += [int]$points
        } else {
            # unassigned items could be collected; for now skip
        }
    }

    $proposal = [PSCustomObject]@{
        Generated = (Get-Date).ToString('o')
        Agents = $agents | ForEach-Object {
            [PSCustomObject]@{
                Name = $_.Name
                CapacityPoints = $_.CapacityPoints
                AssignedPoints = $_.AssignedPoints
                Assignments = $_.Assignments
            }
        }
    }

    $dir = Split-Path -Parent $OutPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    # Always write the proposal JSON to the requested path (DryRun only means no actions taken beyond proposal)
    $proposal | ConvertTo-Json -Depth 6 | Set-Content -Path $OutPath -Encoding UTF8
    Write-Output "Wrote $OutPath (dryRun=$($DryRun.IsPresent))"

    # Also write a monitor-friendly proposal named 'agents-proposal.json' next to the output path
    try {
        $monitorProposalPath = Join-Path $dir 'agents-proposal.json'
        $agentsForMonitor = @()
        foreach ($r in $agentsList) {
            if ($null -ne $r.agentName -and $r.agentName -ne '') { $name = $r.agentName }
            elseif ($null -ne $r.name -and $r.name -ne '') { $name = $r.name }
            elseif ($null -ne $r.id -and $r.id -ne '') { $name = $r.id }
            else { $name = '' }

            $v = 0; $m = 0
            if ($null -ne $r.vramGB) { try { $v = [int]$r.vramGB } catch { $v = 0 } }
            elseif ($null -ne $r.vram) { try { $v = [int]$r.vram } catch { $v = 0 } }

            if ($null -ne $r.memoryGB) { try { $m = [int]$r.memoryGB } catch { $m = 0 } }
            elseif ($null -ne $r.memory) { try { $m = [int]$r.memory } catch { $m = 0 } }

            $skillsArr = @()
            if ($r.skills) {
                if ($r.skills -is [System.Array]) { $skillsArr = $r.skills }
                elseif ($r.skills -is [System.Collections.Hashtable]) { $skillsArr = $r.skills.Keys }
                else { $skillsArr = @($r.skills) }
            }

            $roleVal = ''
            if ($null -ne $r.role -and $r.role -ne '') { $roleVal = $r.role }
            elseif ($null -ne $r.roleName -and $r.roleName -ne '') { $roleVal = $r.roleName }
            elseif ($name -ne '') { $roleVal = $name }

            $agentsForMonitor += [ordered]@{
                name = $name
                role = $roleVal
                vramGB = $v
                memoryGB = $m
                skills = $skillsArr
            }
        }
        $monitorOut = [ordered]@{
            timestamp = (Get-Date).ToString('o')
            agents = $agentsForMonitor
        }
        # Avoid overwriting the main OutPath if the monitor filename matches it
        try {
            $outResolved = [System.IO.Path]::GetFullPath($OutPath)
            $monitorResolved = [System.IO.Path]::GetFullPath($monitorProposalPath)
        } catch { $outResolved = $null; $monitorResolved = $null }
        if ($null -eq $outResolved -or ($monitorResolved -ne $outResolved)) {
            $monitorOut | ConvertTo-Json -Depth 6 | Set-Content -Path $monitorProposalPath -Encoding UTF8
            Write-Output "Wrote monitor proposal to: $monitorProposalPath"
        } else {
            Write-Verbose "Monitor proposal path equals OutPath; skipping monitor write to avoid overwrite"
        }
    } catch {
        Write-Warning "Failed to write monitor proposal: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function Invoke-PreferSkillScheduler
