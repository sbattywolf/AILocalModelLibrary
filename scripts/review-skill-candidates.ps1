<#
.SYNOPSIS
    Review and triage skill candidate entries discovered by CI/tests.

USAGE
    .\review-skill-candidates.ps1 [-Interactive] [-AutoPromoteTeam <team>] [-AutoAddToAgent <agent>] [-WhatIf]

This helper reads .continue/skill-candidates.json and allows summarizing and promoting
candidate values into .continue/team-presets.json or .continue/agent-roles.json.
It is WhatIf-safe and uses tests/TestHelpers.psm1 helpers for atomic JSON writes.
#>

param(
    [switch]$Interactive = $true,
    [string]$AutoPromoteTeam,
    [string]$AutoAddToAgent,
    [switch]$WhatIf
)

function Log { param($m) Write-Output "[review] $m" }

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
. (Join-Path $repoRoot 'tests\TestHelpers.psm1')

$candidatesPath = Join-Path $repoRoot '.continue\skill-candidates.json'
if (-not (Test-Path $candidatesPath)) { Log "No candidate file found at $candidatesPath"; exit 0 }

$rep = Test-LoadJson -Path $candidatesPath
if (-not $rep -or -not $rep.candidates) { Log 'No candidates present'; exit 0 }

$candidates = $rep.candidates

# Normalize candidate values to strings where possible
foreach ($c in $candidates) {
    if ($c.value -is [string]) { continue }
    if ($c.value -is [System.Object[]]) { $c._values = $c.value -join ','; continue }
    try { $c._values = $c.value.ToString() } catch { $c._values = $null }
}

function Summarize {
    $byType = $candidates | Group-Object -Property type | ForEach-Object {
        [PSCustomObject]@{ Type = $_.Name; Count = $_.Count }
    }
    Log "Candidates summary:"
    $byType | Format-Table -AutoSize
}

Summarize

if ($AutoPromoteTeam) {
    Log "Auto-promoting all candidates to team preset '$AutoPromoteTeam'"
    $teamPath = Join-Path $repoRoot '.continue\team-presets.json'
    $teams = @{}
    if (Test-Path $teamPath) { $teams = Test-LoadJson -Path $teamPath }
    if (-not $teams) { $teams = @{} }
    foreach ($c in $candidates) {
        $skill = $null
        if ($c.value -is [string]) { $skill = $c.value }
        elseif ($c._values) { $skill = $c._values }
        if ($skill) {
            if (-not $teams.ContainsKey($AutoPromoteTeam)) { $teams.$AutoPromoteTeam = @() }
            if ($teams.$AutoPromoteTeam -notcontains $skill) { $teams.$AutoPromoteTeam += $skill }
            Write-Output "Promoted $skill -> team $AutoPromoteTeam"
        }
    }
    if ($WhatIf) { Log "Would write updated team-presets to $teamPath" } else { Test-WriteJsonAtomic -Path $teamPath -Object $teams; Log "Wrote $teamPath" }
    exit 0
}

if ($AutoAddToAgent) {
    Log "Auto-adding candidate skills to agent '$AutoAddToAgent'"
    $rolesPath = Join-Path $repoRoot '.continue\agent-roles.json'
    if (-not (Test-Path $rolesPath)) { Log "No agent-roles.json found at $rolesPath"; exit 1 }
    $roles = Test-LoadJson -Path $rolesPath
    $agent = $roles.agents | Where-Object { $_.name -eq $AutoAddToAgent }
    if (-not $agent) { Log "Agent $AutoAddToAgent not found"; exit 1 }
    if (-not $agent.skills) { $agent.skills = @() }
    foreach ($c in $candidates) {
        $skill = $null
        if ($c.value -is [string]) { $skill = $c.value }
        elseif ($c._values) { $skill = $c._values }
        if ($skill -and ($agent.skills -notcontains $skill)) { $agent.skills += $skill; Write-Output "Added $skill -> agent $AutoAddToAgent" }
    }
    if ($WhatIf) { Log "Would write updated agent-roles to $rolesPath" } else { Test-WriteJsonAtomic -Path $rolesPath -Object $roles; Log "Wrote $rolesPath" }
    exit 0
}

if ($Interactive) {
    for ($i = 0; $i -lt $candidates.Count; $i++) {
        $c = $candidates[$i]
        Write-Host "[$i] file:$($c.file) type:$($c.type) agent:$($c.agent) property:$($c.property) value:$($c.value)"
        $action = Read-Host "Action? (t=team, a=agent, s=skip, r=remove)"
        switch ($action.ToLower()) {
            't' {
                $team = Read-Host 'Team name to add to'
                $teamPath = Join-Path $repoRoot '.continue\team-presets.json'
                $teams = @{}
                if (Test-Path $teamPath) { $teams = Test-LoadJson -Path $teamPath }
                if (-not $teams) { $teams = @{} }
                $skill = if ($c.value -is [string]) { $c.value } else { $c._values }
                if ($skill) {
                    if (-not $teams.ContainsKey($team)) { $teams.$team = @() }
                    if ($teams.$team -notcontains $skill) { $teams.$team += $skill; Write-Host "Added $skill -> team $team" }
                    if (-not $WhatIf) { Test-WriteJsonAtomic -Path $teamPath -Object $teams }
                }
            }
            'a' {
                $agentName = Read-Host 'Agent name to add to'
                $rolesPath = Join-Path $repoRoot '.continue\agent-roles.json'
                if (-not (Test-Path $rolesPath)) { Write-Host 'No agent-roles.json present'; continue }
                $roles = Test-LoadJson -Path $rolesPath
                $agent = $roles.agents | Where-Object { $_.name -eq $agentName }
                if (-not $agent) { Write-Host "Agent $agentName not found"; continue }
                if (-not $agent.skills) { $agent.skills = @() }
                $skill = if ($c.value -is [string]) { $c.value } else { $c._values }
                if ($skill -and ($agent.skills -notcontains $skill)) { $agent.skills += $skill; Write-Host "Added $skill -> agent $agentName"; if (-not $WhatIf) { Test-WriteJsonAtomic -Path $rolesPath -Object $roles } }
            }
            'r' {
                Write-Host "Removing candidate entry"
                # mark for removal
                $candidates[$i]._remove = $true
            }
            default { Write-Host 'Skipped' }
        }
    }

    # prune removed candidates and write back
    $remaining = $candidates | Where-Object { -not $_._remove }
    $out = @{ generated = (Get-Date).ToString('o'); candidates = $remaining }
    if ($WhatIf) { Log "Would write back $candidatesPath with $($remaining.Count) entries" } else { Test-WriteJsonAtomic -Path $candidatesPath -Object $out; Log "Wrote $candidatesPath" }
}
