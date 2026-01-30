param(
  [Parameter(Mandatory=$true)] [string]$Skill,
  [string]$RolesFile = '.\.continue\agent-roles.json',
  [string]$OutFile = '.\.continue\prefer-skill-proposal.json',
  [switch]$DryRun
)

function Load-Roles { param($p) if (-not (Test-Path $p)) { throw "Roles file not found: $p" } ; return (Get-Content $p -Raw | ConvertFrom-Json).agents }

try {
  $agents = Load-Roles -p $RolesFile
  # Select agents that advertise the requested skill
  $candidates = @()
  foreach ($a in $agents) {
    if ($a.skills) {
      foreach ($s in $a.skills) { if ($s -eq $Skill) { $candidates += $a; break } }
    }
  }

  # Sort candidates by priority (if present) then by resources.vramGB desc
  $ord = $candidates | Sort-Object -Property @{Expression={ if ($_.priority) { switch ($_.priority.ToString().ToLower()) { 'low' { 2 } 'medium' { 1 } 'high' { 0 } default { 1 } } } else { 1 } } }, @{Expression={ -($_.resources.vramGB -as [int]) }}

  $proposal = @{ requestedSkill = $Skill; timestamp = (Get-Date).ToString('o'); candidates = $ord }
  if ($DryRun) { Write-Output ($proposal | ConvertTo-Json -Depth 5) ; exit 0 }
  $proposal | ConvertTo-Json -Depth 10 | Set-Content -Path $OutFile -Encoding UTF8 -Force
  Write-Output "Wrote proposal to $OutFile (candidates: $($ord.Count))"
} catch {
  Write-Output "[Scheduler] Error: $($_.Exception.Message)"
  exit 2
}
