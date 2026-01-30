<#
Run a minimal local team DryRun: create agents and roles from presets and run monitor suggestions.

Usage: .\run-team-dryrun.ps1 [-WhatIf]
#>

param(
    [switch]$WhatIf
)

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$continue = Join-Path $repoRoot '.continue'
if (-not (Test-Path $continue)) { New-Item -Path $continue -ItemType Directory | Out-Null }

$teamPresetsPath = Join-Path $continue 'team-presets.json'
$agentsPath = Join-Path $continue 'agents-epic.json'
$rolesPath = Join-Path $continue 'agent-roles.json'

if (-not (Test-Path $teamPresetsPath)) { Write-Host "Missing $teamPresetsPath; please create presets."; exit 1 }

# Load presets
$presets = Get-Content -Path $teamPresetsPath -Raw | ConvertFrom-Json

# Build simple agents and roles from presets
$agents = @()
$roles = @{}

foreach ($team in $presets.PSObject.Properties) {
    $teamName = $team.Name
    $skills = $team.Value
    # create one agent per skill for this simple run
    $agentNames = @()
    foreach ($s in $skills) {
        $prefix = if ($teamName -and $teamName.Length -ge 3) { $teamName.Substring(0,3) } else { $teamName }
        $agentName = ("{0}-{1}" -f ($prefix -replace '\s',''), ($s -replace '[^a-zA-Z0-9]',''))
        $agent = [ordered]@{
            name = $agentName
            skills = @(@{ name = $s; weight = 3 })
            vramGB = 4
            memoryGB = 16
        }
        $agents += $agent
        $agentNames += $agentName
    }
    $roles.$teamName = $agentNames
}

# Write files (WhatIf-safe)
if ($WhatIf) {
    Write-Host "WhatIf: Would write $agentsPath and $rolesPath with $($agents.Count) agents"
} else {
    $agents | ConvertTo-Json -Depth 10 | Set-Content -Path $agentsPath -Encoding UTF8
    $roles | ConvertTo-Json -Depth 10 | Set-Content -Path $rolesPath -Encoding UTF8
    Write-Host "Wrote $agentsPath and $rolesPath"
}

# Run monitor once in DryRun to produce suggestions and dashboard
$monitorScript = Join-Path $repoRoot 'scripts\monitor-background.ps1'
if (-not (Test-Path $monitorScript)) { Write-Host "Missing monitor script: $monitorScript"; exit 1 }

if ($WhatIf) {
    Write-Host "WhatIf: Would invoke monitor in DryRun mode"
} else {
    & $monitorScript -DryRun -Once
    Write-Host "Monitor run complete. Check .continue/skill-suggestions.json and .continue/monitor-dashboard.md"
}
