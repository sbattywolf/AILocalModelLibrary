Describe 'Monitor Skills Schema' {
  It 'ensures agents have a skills array when present in roles file' {
    $roles = Get-Content .\.continue\agent-roles.json -Raw | ConvertFrom-Json
    $agents = $roles.agents
    foreach ($a in $agents) {
      if ($a.skills) { ($a.skills -is [System.Array]) | Should -BeTrue }
    }
  }

  It 'validates example skill formatting category:capability' {
    $roles = Get-Content .\.continue\agent-roles.json -Raw | ConvertFrom-Json
    $agents = $roles.agents
    $pattern = '^[a-z]+:[a-z0-9\-]+$'
    foreach ($a in $agents) {
      if ($a.skills) {
        foreach ($s in $a.skills) { $s | Should -Match $pattern }
      }
    }
  }
}
