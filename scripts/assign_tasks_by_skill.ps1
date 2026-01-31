<#
.SYNOPSIS
  Assign backlog items to agents by skill match, capacity and priority.

  Usage (DryRun):
    powershell -NoProfile -File .\scripts\assign_tasks_by_skill.ps1 -BacklogPath .\.continue\backlog_proposal.json -OutJson .\.continue\assignments.json -OutTxt .\.continue\assignments.txt -DryRun
#>
param(
    [string]$BacklogPath = '.\.continue\backlog_proposal.json',
    [string]$AgentsConfigPath = '',
    [string]$OutJson = '.\.continue\assignments.json',
    [string]$OutTxt = '.\.continue\assignments.txt',
    [switch]$DryRun
)

function Convert-PriorityToNumber {
    param([object]$p)
    if ($null -eq $p) { return 5 }
    if ($p -is [int]) { return [int]$p }
    $s = $p.ToString().ToLowerInvariant()
    switch ($s) {
        'critical' { return 1 }
        'high'     { return 2 }
        'medium'   { return 3 }
        'low'      { return 4 }
        default    { if ([int]::TryParse($s,[ref]$null)) { return [int]$s } ; return 5 }
    }
}

function Get-ItemPoints {
    param($item)
    # Support hashtable and PSCustomObject shapes
    if ($item -is [hashtable]) {
        if ($item.ContainsKey('points')) { return [double]$item['points'] }
        if ($item.ContainsKey('estimate')) { return [double]$item['estimate'] }
        if ($item.ContainsKey('estimate_points')) { return [double]$item['estimate_points'] }
        if ($item.ContainsKey('estimatePoints')) { return [double]$item['estimatePoints'] }
        return 1
    }
    if ($null -ne $item.PSObject.Properties['points']) { return [double]$item.points }
    if ($null -ne $item.PSObject.Properties['estimate']) { return [double]$item.estimate }
    if ($null -ne $item.PSObject.Properties['estimate_points']) { return [double]$item.estimate_points }
    if ($null -ne $item.PSObject.Properties['estimatePoints']) { return [double]$item.estimatePoints }
    return 1
}

function Get-KeywordsFromItem { param($item) $text = '' ; if ($item.title) { $text += "$($item.title) `n" } if ($item.description) { $text += $item.description } return ($text -split '\W+' | Where-Object { $_ -and $_.Length -gt 2 } ) }

function Get-ItemScoreForAgent {
    param($agent, $item, $keywordMap)
    $points = Get-ItemPoints $item
    $keywords = Get-KeywordsFromItem $item

    # build per-skill hit totals by matching keyword tokens to skill names and synonyms
    $skillHits = @{}
    foreach ($skill in $agent.skills.Keys) { $skillHits[$skill] = 0 }

    $synonyms = @{ 'backlog' = 'CreateBacklog'; 'todo'='CreateBacklog'; 'assign'='Assignment'; 'priorit'='Prioritization'; 'report'='Reporting'; 'simulate'='Simulation'; 'store'='Storage'; 'ui'='UI'; 'api'='API'; 'automate'='Automation'; 'bug'='Assignment'; 'fix'='Assignment' }

    foreach ($k in $keywordMap.Keys) {
        $count = $keywordMap[$k]
        $kl = $k.ToLowerInvariant()
        foreach ($skill in $agent.skills.Keys) {
            $skillLower = $skill.ToLowerInvariant()
            if ($kl -like "*${skillLower}*" -or $kl -eq $skillLower) {
                $skillHits[$skill] += $count
            }
        }
        if ($synonyms.ContainsKey($kl)) {
            $mapped = $synonyms[$kl]
            if ($skillHits.ContainsKey($mapped)) { $skillHits[$mapped] += $count }
        }
    }

    # compute score: sum over skills of level * log(1+hits)
    $score = 0.0
    foreach ($skill in $agent.skills.Keys) {
        $level = [double]$agent.skills[$skill]
        $hits = [double]$skillHits[$skill]
        if ($hits -le 0 -or $level -le 0) { continue }
        $score += $level * [math]::Log(1 + $hits)
    }
    if ($points -gt 0) { $score = $score / $points }
    return @{ Score = $score; Hits = ($skillHits.Values | Measure-Object -Sum).Sum }
}

function Invoke-AssignTasks {
    param(
        [string]$BacklogPathParam = $BacklogPath,
        [string]$AgentsConfigPathParam = $AgentsConfigPath,
        [string]$OutJsonParam = $OutJson,
        [string]$OutTxtParam = $OutTxt
    )

    try {
        if (!(Test-Path $BacklogPathParam)) { Write-Error "Backlog not found: $BacklogPathParam" ; return 2 }
        $backlog = Get-Content $BacklogPathParam -Raw | ConvertFrom-Json
        $items = @()
        if ($backlog.backlog) { $items = $backlog.backlog } elseif ($backlog.items) { $items = $backlog.items } else { Write-Error "No items found in backlog file" ; return 2 }
        if ($AgentsConfigPathParam -and (Test-Path $AgentsConfigPathParam)) {
            $agents = Get-Content $AgentsConfigPathParam -Raw | ConvertFrom-Json
        } else {
            # fallback sample agents; capacities chosen to match earlier simulation defaults
            $agents = @(
                @{ agentName = 'agent-A'; capacityPoints = 8; skills = @{ 'Prioritization' = 5; 'Assignment' = 4; 'Reporting' = 3 } }
                @{ agentName = 'agent-B'; capacityPoints = 6; skills = @{ 'Simulation' = 5; 'Storage' = 4; 'API' = 3 } }
                @{ agentName = 'agent-C'; capacityPoints = 10; skills = @{ 'UI' = 5; 'Automation' = 4; 'CreateBacklog' = 3 } }
            )
        }

        # normalize agents shape (support various field names) and coerce to PSCustomObject
        $normAgents = @()
        foreach ($a in $agents) {
            if ($a -is [hashtable]) { $obj = [PSCustomObject]$a } else { $obj = $a }
            if (-not $obj.PSObject.Properties['agentName']) {
                if ($obj.PSObject.Properties['name']) { $obj | Add-Member -NotePropertyName agentName -NotePropertyValue $obj.name -Force }
            }
            if (-not $obj.PSObject.Properties['capacityPoints']) {
                if ($obj.PSObject.Properties['capacity']) { $obj | Add-Member -NotePropertyName capacityPoints -NotePropertyValue $obj.capacity -Force }
            }
            if (-not $obj.PSObject.Properties['skills']) { $obj | Add-Member -NotePropertyName skills -NotePropertyValue @{} -Force }
            $normAgents += $obj
        }

        # normalize agents state
        $agentStates = @{}
        foreach ($a in $normAgents) { $agentStates[$a.agentName] = @{ CapacityLeft = [double]$a.capacityPoints; Info = $a } }

        # build keyword map from backlog keywords and simple synonyms
        $keywordMap = @{}
        foreach ($item in $items) {
            $words = (Get-KeywordsFromItem $item)
            foreach ($w in $words) { $wl = $w.ToLowerInvariant(); if (-not $keywordMap.ContainsKey($wl)) { $keywordMap[$wl] = 1 } else { $keywordMap[$wl] += 1 } }
        }
        # synonyms (small set)
        $synonyms = @{ 'bug' = 'fix'; 'fix' = 'fix'; 'ui' = 'ui'; 'api' = 'api' }
        foreach ($k in $synonyms.Keys) { if (-not $keywordMap.ContainsKey($k)) { $keywordMap[$k] = 0 } }

        # sort backlog by priority (lower numeric = higher priority)
        $items = $items | ForEach-Object { $_ | Add-Member -PassThru NotePriority (Convert-PriorityToNumber $_.priority) } | Sort-Object -Property NotePriority

        $assignments = @()
        foreach ($item in $items) {
            $points = Get-ItemPoints $item
            $best = $null; $bestScore = -1.0
            foreach ($aName in $agentStates.Keys) {
                $state = $agentStates[$aName]
                if ($state.CapacityLeft -lt $points) { continue }
                $scoreObj = Get-ItemScoreForAgent $state.Info $item $keywordMap
                $score = [double]$scoreObj.Score
                if ($score -gt $bestScore) {
                    $bestScore = $score; $best = $state.Info
                } elseif ([math]::Abs($score - $bestScore) -lt 1e-9) {
                    # tie-breaker: prefer more remaining capacity, then lexicographically smaller agent name
                    $bestRem = $agentStates[$best.agentName].CapacityLeft
                    $curRem = $state.CapacityLeft
                    if ($curRem -gt $bestRem) { $best = $state.Info }
                    elseif ($curRem -eq $bestRem) {
                        if ([string]::Compare($state.Info.agentName, $best.agentName, $true) -lt 0) { $best = $state.Info }
                    }
                }
            }
            $assignedTo = $null
            if ($best -ne $null) {
                $assignedTo = $best.agentName
                $agentStates[$best.agentName].CapacityLeft -= $points
            }
            $assignments += [PSCustomObject]@{
                id = $item.id
                title = $item.title
                priority = $item.priority
                points = $points
                assignedTo = $assignedTo
            }
        }

        # write outputs
        $outObj = @{ generatedAt = (Get-Date).ToString('o'); assignments = $assignments }
        $outJson = $outObj | ConvertTo-Json -Depth 6
        $outJson | Out-File -FilePath $OutJsonParam -Encoding UTF8
        $lines = @()
        foreach ($a in $assignments) { $lines += "[$($a.priority)] $($a.title) -> $($a.assignedTo) ($($a.points)pts)" }
        $lines | Out-File -FilePath $OutTxtParam -Encoding UTF8

        Write-Verbose "Wrote $OutJsonParam and $OutTxtParam"
        return $outObj
    } catch {
        Write-Error $_.Exception.Message
        return 1
    }
}

# Note: This script is intended to be dot-sourced for tests and reuse.
# To run interactively, call `Invoke-AssignTasks` after dot-sourcing, or execute
# the script with `-File` if you prefer a standalone run wrapper.
