<#
Simulate a DryRun with minimal agents to validate monitor and dashboard output.
The script will create example `.continue/agents-epic.json` and `.continue/agent-roles.json` if missing,
then invoke the monitor in DryRun Once mode.
#>

param(
    [switch]$ForceCreate
)

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$agentsFile = Join-Path $repoRoot ".continue\agents-epic.json"
$rolesFile = Join-Path $repoRoot ".continue\agent-roles.json"

if ($ForceCreate -or -not (Test-Path $agentsFile)) {
    $sampleAgents = @(
        @{ name = 'agent-code-1'; skills = @(@{ name='code'; weight=5 }, @{ name='debug'; weight=3 }) },
        @{ name = 'agent-text-1'; skills = @(@{ name='writing'; weight=4 }, 'summarize') },
        @{ name = 'agent-data-1'; skills = @('sql','etl') }
    )
    $sampleAgents | ConvertTo-Json -Depth 10 | Set-Content -Path $agentsFile -Encoding UTF8
    Write-Host "Wrote sample agents to $agentsFile"
}

if ($ForceCreate -or -not (Test-Path $rolesFile)) {
    $roles = @{ 'backend' = @('agent-code-1'); 'content' = @('agent-text-1'); 'data' = @('agent-data-1') }
    $roles | ConvertTo-Json -Depth 10 | Set-Content -Path $rolesFile -Encoding UTF8
    Write-Host "Wrote sample roles to $rolesFile"
}

Write-Host "Running monitor (DryRun Once)"
& (Join-Path $repoRoot 'scripts\monitor-background.ps1') -DryRun -Once

Write-Host "DryRun simulate finished. Check .continue/skill-suggestions.json and .continue/monitor-dashboard.md"
