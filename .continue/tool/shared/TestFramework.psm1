<#
TestFramework.psm1 - shim loader for repository tests

This module locates a shared TestFramework implementation in a small
set of candidate locations (historical names supported), imports it if
found, and publishes RepoRoot / AgentPath as globals for tests.
#>

if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }

$RepoRoot = $PSScriptRoot
while ($true) {
    if (Test-Path (Join-Path $RepoRoot '.git') -or Test-Path (Join-Path $RepoRoot 'agent') -or Test-Path (Join-Path $RepoRoot 'templates\\agent')) { break }
    $parent = Split-Path -Parent $RepoRoot
    if ($parent -eq $RepoRoot -or [string]::IsNullOrEmpty($parent)) { break }
    $RepoRoot = $parent
}

$candidates = @(
    Join-Path $PSScriptRoot '..\\TemplateAgent.Tests\\shared\\TestFramework.psm1',
    Join-Path $RepoRoot '.continue\\tool\\TemplateAgent.Tests\\shared\\TestFramework.psm1',
    Join-Path $RepoRoot 'agent\\TemplateAgent.Tests\\shared\\TestFramework.psm1',
    Join-Path $RepoRoot 'agent\\shared\\TestFramework.psm1'
)

$found = $null
foreach ($c in $candidates) {
    if (Test-Path $c) { $found = $c; break }
}

if ($found) {
    try {
        Import-Module $found -Force -ErrorAction SilentlyContinue
        Write-Verbose "TestFramework loaded from $found"
    } catch {
        Write-Warning ("Failed to import TestFramework from {0}: {1}" -f $found, $_)
    }

    try { $Global:RepoRoot = $RepoRoot } catch {}
    try {
        $agentCandidate = Join-Path $RepoRoot 'agent'
        $templateCandidate = Join-Path $RepoRoot 'templates\\agent'
        if (Test-Path (Join-Path $agentCandidate 'TemplateAgent')) { $Global:AgentPath = $agentCandidate }
        elseif (Test-Path (Join-Path $templateCandidate 'TemplateAgent')) { $Global:AgentPath = $templateCandidate }
        else { $Global:AgentPath = $agentCandidate }
    } catch {}
} else {
    Write-Verbose "TestFramework not found in candidates; tests that dot-source relative paths will need the framework available."
}

try {
    Export-ModuleMember -Function * -ErrorAction Stop
} catch {
    Write-Verbose "Export-ModuleMember skipped (not running inside a module): $($_.Exception.Message)"
}
