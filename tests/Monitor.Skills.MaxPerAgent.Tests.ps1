Describe 'Monitor Skills - Max 3 per agent' {
  It 'ensures no agent has more than 3 skills assigned' {
    Import-Module (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.psm1')).Path -Force
    $roles = Load-JsonDefensive '.continue/agent-roles.json'
    if ($null -eq $roles) { throw 'Failed to load .continue/agent-roles.json' }
    foreach ($a in $roles.agents) {
      if ($a.skills) { ($a.skills.Count -le 3) | Should -BeTrue }
    }
  }
}