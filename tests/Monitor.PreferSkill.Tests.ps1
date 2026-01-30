Describe 'Monitor PreferSkill Scheduler' {
  It 'proposes agents that match a given skill' {
    $skill = 'nlp:unit-test-gen'
    $out = Join-Path $env:TEMP ([guid]::NewGuid().ToString() + '.json')
    $script = (Resolve-Path .\scripts\scheduler-prefer-skill.ps1).Path
    & $script -Skill $skill -RolesFile '.\.continue\agent-roles.json' -OutFile $out -DryRun | Out-Null
    # DryRun outputs JSON to stdout; capture by calling script directly
    $res = & $script -Skill $skill -RolesFile '.\.continue\agent-roles.json' -DryRun
    $parsed = $res | ConvertFrom-Json
    ($parsed.candidates.Count) | Should -BeGreaterThan 0
  }
}
