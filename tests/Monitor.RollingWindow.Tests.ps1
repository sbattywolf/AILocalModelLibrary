Describe 'Monitor RollingWindow setting' {
  It 'sets RollingWindow to 60 in monitor-agents-epic.ps1' {
    $path = 'scripts/monitor-agents-epic.ps1'
    (Test-Path $path) | Should -BeTrue
    $content = Get-Content $path -Raw
    $content | Should -Match '\$RollingWindow\s*=\s*60'
  }
}
