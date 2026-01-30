Describe 'Combinatorial scheduling behaviors' {

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
    return $scheduled
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
    $matrixVram = @(5,10)
    $matrixParallel = @(1,2)
    foreach ($mv in $matrixVram) {
      foreach ($mp in $matrixParallel) {
        It ("schedules <= MaxParallel and <= MaxVram (Vram=$mv,Par=$mp)") {
          $agents = @(
            [PSCustomObject]@{ name='a1'; vram=3 },
            [PSCustomObject]@{ name='a2'; vram=4 },
            [PSCustomObject]@{ name='a3'; vram=5 }
          )
          $s = SimulateSchedule -agents $agents -MaxVramGB $mv -PreferMaxAgent $false -MaxParallel $mp
          # Ensure scheduled count <= MaxParallel and total vram <= MaxVramGB
          ($s.Count -le $mp) | Should -BeTrue
          $totalV = ($s | Measure-Object -Property vram -Sum).Sum
          if (-not $totalV) { $totalV = 0 }
          ($totalV -le $mv) | Should -BeTrue
        }
      }
    }
  }

}
