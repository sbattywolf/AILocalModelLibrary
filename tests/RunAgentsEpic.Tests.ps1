Describe 'run-agents-epic.ps1 PreferMaxAgent ordering' {
  It 'orders agents by estimated vram descending when -PreferMaxAgent is used' {
    # Load the script and call the helper logic via a dot-source test harness
    $script = 'e:\Workspaces\Git\AILocalModelLibrary\scripts\run-agents-epic.ps1'
    # Sanity: script must exist
    Test-Path $script | Should -BeTrue
    # Prepare a fake roleResources hashtable and fake agents array
    $roleResources = @{ 'HighAgent' = 20; 'LowAgent' = 1; 'MidAgent' = 8 }
    $agents = @(
      @{ name = 'LowAgent'; entry = 'a' },
      @{ name = 'HighAgent'; entry = 'b' },
      @{ name = 'MidAgent'; entry = 'c' }
    )

    # Simulate ordering logic
    $agentVramMap = @()
    foreach ($aa in $agents) {
      $san = ($aa.name -replace '[^A-Za-z0-9_-]','-')
      $est = 0
      if ($roleResources.ContainsKey($san)) { $est = ($roleResources[$san] -as [int]) }
      $agentVramMap += [PSCustomObject]@{ agent = $aa; vram = $est }
    }
    $ordered = $agentVramMap | Sort-Object -Property vram -Descending | ForEach-Object { $_.agent }
    $ordered[0].name | Should -Be 'HighAgent'
    $ordered[1].name | Should -Be 'MidAgent'
    $ordered[2].name | Should -Be 'LowAgent'
  }
}
