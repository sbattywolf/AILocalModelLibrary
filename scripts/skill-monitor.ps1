<#
Scans agent roles and validates skill constraints:
- Max total skills across all agents: 10
- Trigger a warning when total skills >= 6
- Each skill must be concise: max 10 words
Writes .continue/skills-warnings.json with warnings and proposals.
#>
param(
    [string]$RolesFile = ".continue/agent-roles.json",
    [string]$OutputDir = ".continue",
    [int]$MaxSkillsTotal = 10,
    [int]$WarnAt = 6,
    [int]$MaxSkillWords = 10
)

Set-StrictMode -Version Latest

if (-not (Test-Path $RolesFile)) { Write-Error "Roles file not found: $RolesFile" ; exit 2 }

$roles = Get-Content $RolesFile -Raw | ConvertFrom-Json

$totalSkills = 0
$agentWarnings = @()

foreach ($agent in $roles) {
    $skills = @()
    if ($null -ne $agent.skills) {
        # Normalize to array
        if ($agent.skills -is [System.Array]) { $skills = $agent.skills } else { $skills = @($agent.skills) }
    }

    $totalSkills += $skills.Count

    # Check each skill word count
    foreach ($s in $skills) {
        $wordCount = ($s -split '\s+').Count
        if ($wordCount -gt $MaxSkillWords) {
            $agentWarnings += [ordered]@{
                name = $agent.name
                issue = 'SkillTooLong'
                skill = $s
                words = $wordCount
                suggestion = ($s -split '\s+')[0..($MaxSkillWords-1)] -join ' ' + ' ...'
            }
        }
    }

    if ($skills.Count -eq 0) {
        $agentWarnings += [ordered]@{ name = $agent.name ; issue = 'NoSkills' ; suggestion = 'please-review-and-add-concise-skills' }
    }
}

# Global warnings: total skill count
if ($totalSkills -ge $WarnAt) {
    $agentWarnings += [ordered]@{ name = 'global' ; issue = 'SkillCountWarning' ; totalSkills = $totalSkills ; warnAt = $WarnAt }
}

if ($totalSkills -gt $MaxSkillsTotal) {
    $agentWarnings += [ordered]@{ name = 'global' ; issue = 'SkillCountExceeded' ; totalSkills = $totalSkills ; max = $MaxSkillsTotal }
}

[IO.Directory]::CreateDirectory($OutputDir) | Out-Null
$outPath = Join-Path $OutputDir 'skills-warnings.json'

$out = [ordered]@{
    timestamp = (Get-Date).ToString('o')
    totalSkills = $totalSkills
    warnings = $agentWarnings
}

$out | ConvertTo-Json -Depth 6 | Out-File -FilePath $outPath -Encoding UTF8
Write-Output "Wrote skill warnings to: $outPath"

exit 0
