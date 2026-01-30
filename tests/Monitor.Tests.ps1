Describe 'Monitor scheduling algorithms' {

  Context 'Queued ordering by vram (PreferMaxAgent)' {
    It 'sorts queued agents descending by vram' {
      $queued = @(
        @{ name='A'; vram=2 },
        @{ name='B'; vram=10 },
        @{ name='C'; vram=5 }
      )
      $sorted = $queued | Sort-Object -Property { [int]$_.vram } -Descending
      $sorted[0].name | Should -Be 'B'
      $sorted[1].name | Should -Be 'C'
      $sorted[2].name | Should -Be 'A'
    }
  }

  Context 'Eviction candidate selection' {
    It 'picks lower-priority running agents sufficient to free required vram' {
      # Priorities: low=1, medium=2, high=3
      $prioWeight = @{ 'low'=1; 'medium'=2; 'high'=3 }
      $running = @(
        [PSCustomObject]@{ name='r1'; vram=8; priority='low'; startedAt='2026-01-01T00:00:00Z' },
        [PSCustomObject]@{ name='r2'; vram=6; priority='medium'; startedAt='2026-01-01T00:01:00Z' },
        [PSCustomObject]@{ name='r3'; vram=4; priority='low'; startedAt='2026-01-01T00:02:00Z' }
      )
      $queued = [PSCustomObject]@{ name='q1'; vram=12; priority='high' }

      $qWeight = $prioWeight[$queued.priority]
      $candidates = @()
      foreach ($r in $running) {
        $rWeight = $prioWeight[$r.priority]
        if ($rWeight -lt $qWeight) { $candidates += $r }
      }
      # Sort candidates by weight asc then by startedAt (oldest first)
      $candidates = $candidates | Sort-Object -Property { [int]$prioWeight[$_.priority] }, { [datetime]$_.startedAt }
      # Choose until freed >= queued.vram - assume currentVram= sum running
      $freed = 0
      $toStop = @()
      foreach ($c in $candidates) {
        $toStop += $c
        $freed += $c.vram
        if ($freed -ge $queued.vram) { break }
      }

      $toStop.Count | Should -BeGreaterThan 0
      # Expect to stop r1 (8) + r3 (4) = 12 -> 2 candidates
      ($toStop | Select-Object -ExpandProperty name) -join ',' | Should -Be 'r1,r3'
    }
  }

  Context 'Coordinator enforcement: keep earliest' {
    It 'selects the earliest started coordinator to keep' {
      $coords = @(
        [PSCustomObject]@{ name='c1'; pid=101; startedAt='2026-01-01T00:05:00Z' },
        [PSCustomObject]@{ name='c2'; pid=102; startedAt='2026-01-01T00:03:00Z' },
        [PSCustomObject]@{ name='c3'; pid=103; startedAt='2026-01-01T00:04:00Z' }
      )
      $keep = $coords | Sort-Object -Property { [datetime]$_.startedAt } | Select-Object -First 1
      $keep.name | Should -Be 'c2'
    }
  }

}
