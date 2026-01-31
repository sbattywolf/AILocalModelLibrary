Describe 'Monitor Skills - Max 3 per agent (clean)' {
  It 'ensures no agent has more than 3 skills assigned' {
    $roles = Get-Content .\.continue\agent-roles.fixed.json -Raw | ConvertFrom-Json
    foreach ($a in $roles.agents) {
      if ($a.skills) { ($a.skills.Count -le 3) | Should -BeTrue }
    }
  }
}
