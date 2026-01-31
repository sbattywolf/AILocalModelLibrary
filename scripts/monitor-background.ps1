param(
    [switch]$DryRun,
    [switch]$Once
)

$repoRoot = Split-Path -Path $PSScriptRoot -Parent
$logPath = Join-Path $repoRoot ".continue\monitor-background.log"
function Log($msg) {
    $line = "$(Get-Date -Format o) - $msg"
    Add-Content -Path $logPath -Value $line -Encoding UTF8
}

# Load helpers
$helpers = Join-Path $repoRoot "tests\TestHelpers.psm1"
if (Test-Path $helpers) { . $helpers } else { throw "Missing TestHelpers module at $helpers" }

$agentsPath = Join-Path $repoRoot ".continue\agents-epic.json"
$rolesPath  = Join-Path $repoRoot ".continue\agent-roles.json"
$outPath    = Join-Path $repoRoot ".continue\skill-suggestions.json"

function Invoke-AnalyzeSuggest {
    Log "Starting analysis"

    try {
        $agents = Test-LoadJson -Path $agentsPath
    } catch {
        Log "Failed to load agents: $_"
        $agents = @()
    }

    try {
        $roles = Test-LoadJson -Path $rolesPath
    } catch {
        Log "Failed to load roles: $_"
        $roles = @{}
    }

    # Aggregate global skill counts
    $skillCounts = @{}
    foreach ($a in $agents) {
        $skills = @()
        if ($a.PSObject.Properties.Match('skills')) { $skills = $a.skills } elseif ($a.skills) { $skills = $a.skills }
        foreach ($s in $skills) {
            if ($s -is [string]) { $name = $s; $w = 1 } else { $name = $s.name; $w = ($s.weight -as [int]) -or 1 }
            if (-not $name) { continue }
            if (-not $skillCounts.ContainsKey($name)) { $skillCounts[$name] = 0 }
            $skillCounts[$name] += $w
        }
    }

    $topSkills = $skillCounts.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 10

    $suggestions = [ordered]@{
        timestamp = (Get-Date).ToString('o')
        summary = "monitor suggestions"
        topSkills = @()
        roleSuggestions = @()
        heavyWeights = @()
    }

    foreach ($ts in $topSkills) { $suggestions.topSkills += @{ name = $ts.Name; weight = $ts.Value } }

    # Per-role coverage heuristic (defensive: handle arrays/nulls)
    $roleProps = $null
    try { $roleProps = $roles.PSObject.Properties } catch { $roleProps = $null }
    $rpCount = 0
    if ($roleProps) { $rpCount = ($roleProps | Measure-Object).Count }
    if ($roles -and $roleProps -and $rpCount -gt 0) {
        foreach ($prop in $roleProps) {
            $roleName = $prop.Name
            $assigned = $prop.Value
            $roleSkills = @{}
            foreach ($agentName in $assigned) {
                $a = $agents | Where-Object { $_.name -eq $agentName }
                if ($a) {
                    foreach ($s in ($a.skills -as [System.Collections.IEnumerable])) {
                        if ($s -is [string]) { $n = $s; $w = 1 } else { $n = $s.name; $w = ($s.weight -as [int]) -or 1 }
                        if (-not $n) { continue }
                        if (-not $roleSkills.ContainsKey($n)) { $roleSkills[$n] = 0 }
                        $roleSkills[$n] += $w
                    }
                }
            }

            # Compare with global top skills and suggest missing ones
            $missing = @()
            foreach ($g in $suggestions.topSkills) {
                if (-not $roleSkills.ContainsKey($g.name)) { $missing += $g }
            }

            $suggestions.roleSuggestions += @{ role = $roleName; missingTopSkills = $missing }
        }
    }

    # Detect heavy weights (any aggregated skill weight > 5)
    foreach ($kv in $skillCounts.GetEnumerator()) {
        if ($kv.Value -gt 5) { $suggestions.heavyWeights += @{ name = $kv.Name; totalWeight = $kv.Value } }
    }

    # If heavy weight suggestions exist, recommend child-agent creation per skill
    if ($suggestions.heavyWeights.Count -gt 0) {
        foreach ($h in $suggestions.heavyWeights) {
            $h.suggestChildAgent = "Consider creating a child agent focused on '$($h.name)' to keep per-agent weights <=5"
        }
    }

    # Write suggestions atomically
    Test-WriteJsonAtomic -Path $outPath -Object $suggestions | Out-Null
    Log "Wrote suggestions to $outPath"

    # Also write a small markdown dashboard summarizing top skills and heavy weights
    $dashboardPath = Join-Path $repoRoot ".continue\monitor-dashboard.md"
    $lines = @()
    $lines += "# Monitor Dashboard"
    $lines += "Generated: $((Get-Date).ToString('o'))"
    $lines += ""
    $lines += "## Top Skills"
    foreach ($t in $suggestions.topSkills) { $lines += "- $($t.name): $($t.weight)" }
    $lines += ""
    $lines += "## Heavy Weights"
    if ($suggestions.heavyWeights.Count -eq 0) { $lines += "- None" } else { foreach ($h in $suggestions.heavyWeights) { $lines += "- $($h.name): $($h.totalWeight)" } }
    $lines += ""
    $lines += "## Role Suggestions (missing top skills)"
    foreach ($r in $suggestions.roleSuggestions) {
        $missingNames = @()
        if ($r.missingTopSkills) {
            foreach ($m in $r.missingTopSkills) { if ($m -and $m.name) { $missingNames += $m.name } }
        }
        if ($missingNames.Count -eq 0) { $lines += "- $($r.role): Missing top skills: None" } else { $lines += "- $($r.role): Missing top skills: $(([string]::Join(', ', $missingNames)))" }
    }

    Set-Content -Path $dashboardPath -Value $lines -Encoding UTF8
    Log "Wrote dashboard to $dashboardPath"
}

if ($DryRun -or $Once) {
    Invoke-AnalyzeSuggest
    return
}

while ($true) {
    Invoke-AnalyzeSuggest
    Start-Sleep -Seconds 60
}
