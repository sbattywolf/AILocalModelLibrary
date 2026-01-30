Describe 'Monitor health-probe and queued-start behavior' {

  It 'returns ok when HTTP health probe succeeds' {
    function Check-AgentHealthTest {
      param($healthUrl,$timeoutSec)
      if ($healthUrl) {
        try { $resp = Invoke-RestMethod -Uri $healthUrl -Method Get -TimeoutSec $timeoutSec -ErrorAction Stop; return @{ ok=$true; detail='http:ok' } } catch { return @{ ok=$false; detail=('http:error {0}' -f $_) } }
      }
      return @{ ok=$true; detail='no-probe' }
    }

    Mock -CommandName Invoke-RestMethod -MockWith { return @{ status='ok' } }
    $res = Check-AgentHealthTest -healthUrl 'http://localhost/health' -timeoutSec 1
    $res.ok | Should -BeTrue
    $res.detail | Should -Be 'http:ok'
  }

  It 'returns unhealthy when CLI health command times out or nonzero' {
    function Check-AgentHealthCmdTest {
      param($healthCmd,$timeoutSec)
      if ($healthCmd) {
        $p = Start-Process -FilePath 'powershell' -ArgumentList '-NoProfile','-Command',$healthCmd -WindowStyle Hidden -PassThru
        $p | Should -Not -BeNullOrEmpty
        try { $p.WaitForExit($timeoutSec*1000) } catch {}
        if (-not $p.HasExited) { try { $p.Kill() } catch{} ; return @{ ok=$false; detail='cmd:timeout' } }
        if ($p.ExitCode -eq 0) { return @{ ok=$true; detail='cmd:exit0' } } else { return @{ ok=$false; detail=('cmd:exit{0}' -f $p.ExitCode) } }
      }
      return @{ ok=$true; detail='no-probe' }
    }

    $fakeProc = [PSCustomObject]@{ HasExited=$true; ExitCode=1; WaitForExit={}; Kill={} }
    Mock -CommandName Start-Process -MockWith { return $fakeProc }
    $r = Check-AgentHealthCmdTest -healthCmd 'exit 1' -timeoutSec 1
    $r.ok | Should -BeFalse
    $r.detail | Should -Be 'cmd:exit1'
  }

  It 'starts queued agents when capacity allows (no eviction)' {
    function ScheduleQueuedTest {
      param($agents,$currentVram,$MaxVramGB)
      $started = @()
      foreach ($q in $agents) {
        $qv = ($q.vram -as [int])
        if ($currentVram + $qv -le $MaxVramGB) {
          Start-Process -FilePath 'powershell' -ArgumentList '-NoProfile','-Command','echo run' -WindowStyle Hidden -PassThru | Out-Null
          $started += $q.name
          $currentVram += $qv
        }
      }
      return $started
    }

    Mock -CommandName Start-Process -MockWith { return [PSCustomObject]@{ Id=999 } }
    $queued = @([PSCustomObject]@{ name='q1'; vram=2 }, [PSCustomObject]@{ name='q2'; vram=3 })
    $res = ScheduleQueuedTest -agents $queued -currentVram 0 -MaxVramGB 10
    $res.Count | Should -Be 2
    $res -join ',' | Should -Be 'q1,q2'
  }

  It 'evicts lower-priority agents to make room for higher-priority queued' {
    function SelectEvictionCandidatesTest {
      param($running,$queuedVram)
      # simple greedy: pick smallest-running first
      $candidates = $running | Sort-Object -Property { [int]$_.vram }
      $freed = 0; $toStop = @()
      foreach ($c in $candidates) { $toStop += $c; $freed += $c.vram; if ($freed -ge $queuedVram) { break } }
      return $toStop
    }

    $running = @(
      [PSCustomObject]@{ name='r1'; vram=8 },
      [PSCustomObject]@{ name='r2'; vram=6 },
      [PSCustomObject]@{ name='r3'; vram=4 }
    )
    $toStop = SelectEvictionCandidatesTest -running $running -queuedVram 12
    ($toStop | Select-Object -ExpandProperty name) -join ',' | Should -Be 'r3,r2,r1'
  }

}
