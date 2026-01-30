function SimulateSchedule {
  param($agents, $MaxVramGB, $PreferMaxAgent, $MaxParallel)
  $list = $agents
  if ($PreferMaxAgent) { $list = $list | Sort-Object -Property { [int]$_.vram } -Descending }
  $scheduled = @(); $currentVram = 0
  foreach ($a in $list) {
    if ($MaxParallel -gt 0 -and $scheduled.Count -ge $MaxParallel) { break }
    $v = [int]$a.vram
    if ($currentVram + $v -le $MaxVramGB) { $scheduled += $a; $currentVram += $v }
  }
  return ,$scheduled
}

Describe 'Combinatorial scheduling behaviors' {

  BeforeAll {
    Set-Item -Path Function:\SimulateSchedule -Value {
      param($agents, $MaxVramGB, $PreferMaxAgent, $MaxParallel)
      $list = $agents
      if ($PreferMaxAgent) { $list = $list | Sort-Object -Property { [int]$_.vram } -Descending }
      $scheduled = @(); $currentVram = 0
      foreach ($a in $list) {
        if ($MaxParallel -gt 0 -and $scheduled.Count -ge $MaxParallel) { break }
        $v = [int]$a.vram
        if ($currentVram + $v -le $MaxVramGB) { $scheduled += $a; $currentVram += $v }
      }
      return ,$scheduled
    }
  }
  Context 'PreferMaxAgent ordering influences scheduling' {
    It 'schedules highest-vram agents first when preference enabled' {
      $agents = @(
        [PSCustomObject]@{ name='A'; vram=8 },
        [PSCustomObject]@{ name='B'; vram=4 },
        [PSCustomObject]@{ name='C'; vram=2 }
      )
      $res = SimulateSchedule -agents $agents -MaxVramGB 10 -PreferMaxAgent $true -MaxParallel 2
      # With MaxVram=10 and MaxParallel=2, scheduling will pick A (8) then skip B(4) and take C(2) to fit the vram budget
      ($res | Select-Object -ExpandProperty name) -join ',' | Should -Be 'A,C'
    }
  }

  Context 'Combinatorial matrix over thresholds' {
    It 'schedules <= MaxParallel and <= MaxVram (Vram=5,Par=1)' {
      $agents = @(
        [PSCustomObject]@{ name='a1'; vram=3 },
        [PSCustomObject]@{ name='a2'; vram=4 },
        [PSCustomObject]@{ name='a3'; vram=5 }
      )
      $s = SimulateSchedule -agents $agents -MaxVramGB 5 -PreferMaxAgent $false -MaxParallel 1
      $dbgCount = (@($s)).Count
      $dbgTotal = ($s | Measure-Object -Property vram -Sum).Sum; if (-not $dbgTotal) { $dbgTotal = 0 }
      $dbgNames = if ($s) { ($s | ForEach-Object { $_.name }) -join ',' } else { '' }
      Write-Host "DEBUG: mv=5 mp=1 scheduled=($dbgNames) count=$dbgCount total=$dbgTotal"
      ($dbgCount -le 1) | Should -BeTrue
      ($dbgTotal -le 5) | Should -BeTrue
    }

    It 'schedules <= MaxParallel and <= MaxVram (Vram=5,Par=2)' {
      $agents = @(
        [PSCustomObject]@{ name='a1'; vram=3 },
        [PSCustomObject]@{ name='a2'; vram=4 },
        [PSCustomObject]@{ name='a3'; vram=5 }
      )
      $s = SimulateSchedule -agents $agents -MaxVramGB 5 -PreferMaxAgent $false -MaxParallel 2
      $dbgCount = (@($s)).Count
      $dbgTotal = ($s | Measure-Object -Property vram -Sum).Sum; if (-not $dbgTotal) { $dbgTotal = 0 }
      $dbgNames = if ($s) { ($s | ForEach-Object { $_.name }) -join ',' } else { '' }
      Write-Host "DEBUG: mv=5 mp=2 scheduled=($dbgNames) count=$dbgCount total=$dbgTotal"
      ($dbgCount -le 2) | Should -BeTrue
      ($dbgTotal -le 5) | Should -BeTrue
    }

    It 'schedules <= MaxParallel and <= MaxVram (Vram=10,Par=1)' {
      $agents = @(
        [PSCustomObject]@{ name='a1'; vram=3 },
        [PSCustomObject]@{ name='a2'; vram=4 },
        [PSCustomObject]@{ name='a3'; vram=5 }
      )
      $s = SimulateSchedule -agents $agents -MaxVramGB 10 -PreferMaxAgent $false -MaxParallel 1
      $dbgCount = (@($s)).Count
      $dbgTotal = ($s | Measure-Object -Property vram -Sum).Sum; if (-not $dbgTotal) { $dbgTotal = 0 }
      $dbgNames = if ($s) { ($s | ForEach-Object { $_.name }) -join ',' } else { '' }
      Write-Host "DEBUG: mv=10 mp=1 scheduled=($dbgNames) count=$dbgCount total=$dbgTotal"
      ($dbgCount -le 1) | Should -BeTrue
      ($dbgTotal -le 10) | Should -BeTrue
    }

    It 'schedules <= MaxParallel and <= MaxVram (Vram=10,Par=2)' {
      $agents = @(
        [PSCustomObject]@{ name='a1'; vram=3 },
        [PSCustomObject]@{ name='a2'; vram=4 },
        [PSCustomObject]@{ name='a3'; vram=5 }
      )
      $s = SimulateSchedule -agents $agents -MaxVramGB 10 -PreferMaxAgent $false -MaxParallel 2
      $dbgCount = (@($s)).Count
      $dbgTotal = ($s | Measure-Object -Property vram -Sum).Sum; if (-not $dbgTotal) { $dbgTotal = 0 }
      $dbgNames = if ($s) { ($s | ForEach-Object { $_.name }) -join ',' } else { '' }
      Write-Host "DEBUG: mv=10 mp=2 scheduled=($dbgNames) count=$dbgCount total=$dbgTotal"
      ($dbgCount -le 2) | Should -BeTrue
      ($dbgTotal -le 10) | Should -BeTrue
    }
  }

}
