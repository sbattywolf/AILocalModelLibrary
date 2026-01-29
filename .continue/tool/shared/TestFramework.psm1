# Duplicate shim for tests referencing agent\shared path
Import-Module (Join-Path $PSScriptRoot "..\SimRacingAgent.Tests\shared\TestFramework.psm1") -ErrorAction SilentlyContinue

try {
	Export-ModuleMember -Function * -ErrorAction Stop
} catch {
	Write-Verbose "Export-ModuleMember skipped (not running inside a module): $($_.Exception.Message)"
}

<# Shim loader for TestFramework: locate the real framework in common locations and import it #>

# Ensure $PSScriptRoot is set when dot-sourced
if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }

# Resolve repository root by walking up until we find markers (.git or agent folder)
$RepoRoot = $PSScriptRoot
while ($true) {
	if (Test-Path (Join-Path $RepoRoot '.git') -or Test-Path (Join-Path $RepoRoot 'agent') -or Test-Path (Join-Path $RepoRoot 'templates\agent')) { break }
	$parent = Split-Path -Parent $RepoRoot
	if ($parent -eq $RepoRoot -or [string]::IsNullOrEmpty($parent)) { break }
	$RepoRoot = $parent
}

$candidates = @(
	(Join-Path $PSScriptRoot '..\SimRacingAgent.Tests\shared\TestFramework.psm1'),
	(Join-Path $RepoRoot '.continue\tool\SimRacingAgent.Tests\shared\TestFramework.psm1'),
	(Join-Path $RepoRoot 'agent\SimRacingAgent.Tests\shared\TestFramework.psm1'),
	(Join-Path $RepoRoot 'agent\shared\TestFramework.psm1')
)

$found = $null
foreach ($c in $candidates) { if (Test-Path $c) { $found = $c; break } }

if ($found) {
	try { Import-Module $found -Force -ErrorAction SilentlyContinue ; Write-Verbose "TestFramework loaded from $found" } catch { Write-Warning "Failed to import TestFramework from $found: $_" }
	# Publish repo and agent paths as globals so tests can reuse a single source of truth
	try { $Global:RepoRoot = $RepoRoot } catch {}
	try {
		# Prefer existing `agent` folder, otherwise use `templates/agent` when present.
		$agentCandidate = Join-Path $RepoRoot 'agent'
		$templateCandidate = Join-Path $RepoRoot 'templates\agent'
		if (Test-Path $agentCandidate) { $Global:AgentPath = $agentCandidate }
		elseif (Test-Path $templateCandidate) { $Global:AgentPath = $templateCandidate }
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




