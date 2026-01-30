Describe 'Monitor Single-Agent-Per-Role' {
  Context 'Enforce single agent per role on developer machine' {
    It 'ensures only one `tester` agent instance runs on a developer machine' {
      $tmpDir = Join-Path $env:TEMP ([guid]::NewGuid().ToString())
      New-Item -ItemType Directory -Path $tmpDir | Out-Null
      $mappingPath = Join-Path $tmpDir 'mapping.json'

      $p1 = Start-Process -FilePath ping -ArgumentList '-t','127.0.0.1' -PassThru
      $p2 = Start-Process -FilePath ping -ArgumentList '-t','127.0.0.1' -PassThru
      try {
        $agents = @(
          @{ name='tester-1'; pid=$p1.Id; primaryRole='tester'; startedAt=(Get-Date).ToString('o') },
          @{ name='tester-2'; pid=$p2.Id; primaryRole='tester'; startedAt=(Get-Date).ToString('o') }
        )
        $agents | ConvertTo-Json -Compress | Set-Content -Path $mappingPath -Encoding UTF8
        # debug: emit initial mapping written and append to repo debug log
        try { $init = Get-Content $mappingPath -Raw -ErrorAction Stop; Write-Output '[TestDebug] Initial mapping:'; Write-Output $init } catch { Write-Output '[TestDebug] Failed to read initial mapping' }

        $enforcer = (Resolve-Path .\scripts\enforce-single-agent-per-role.ps1).Path
        $outLog = Join-Path $tmpDir 'enforcer.out'
        $merged = & $enforcer -MappingFile $mappingPath 2>&1
        try { $merged | Out-File -FilePath $outLog -Encoding UTF8 -Force } catch { }
        if ($merged) { Write-Output '[TestDebug] Enforcer output:'; $merged | Write-Output }
        Start-Sleep -Milliseconds 200
        try { $rawMap = Get-Content $mappingPath -Raw -ErrorAction Stop; Write-Output '[TestDebug] Mapping after enforcer (len=' + ($rawMap.Length) + '):'; Write-Output $rawMap } catch { Write-Output '[TestDebug] Mapping not readable after enforcer' }

        $ok = $false
        $maxWait = 30
        for ($i=0; $i -lt $maxWait; $i++) {
          Start-Sleep -Seconds 1
          try {
            $content = Get-Content $mappingPath -Raw
            $parsed = $null
            try { $parsed = $content | ConvertFrom-Json } catch { $parsed = $null }
            $aliveCount = 0
            if ($parsed) { $aliveCount = ($parsed | Where-Object { $_.primaryRole -eq 'tester' -and $_.pid -ne $null }).Count }
            if ($aliveCount -le 1) { $ok = $true; break }
          } catch { }
        }

        # enforcer ran synchronously with -Wait; no background process to stop

        if (-not $ok) {
          Write-Output "[TestDebug] Mapping content after timeout:"
          try { Get-Content $mappingPath -Raw | Write-Output } catch { Write-Output "[TestDebug] Failed to read mapping" }
        }
        $ok | Should -BeTrue
        # ensure final mapping is parseable before asserting (mitigate transient read/parse race)
        $content = $null
        for ($r=0; $r -lt 10; $r++) {
          Start-Sleep -Milliseconds 200
          try { $raw = Get-Content $mappingPath -Raw -ErrorAction Stop } catch { continue }
          try { $content = $raw | ConvertFrom-Json; if ($content) { break } } catch { $content = $null }
        }
        (@($content | Where-Object { $_.primaryRole -eq 'tester' -and $_.pid -ne $null })).Count | Should -Be 1
      } finally {
        Try { Stop-Process -Id $p1.Id -Force -ErrorAction SilentlyContinue } Catch { }
        Try { Stop-Process -Id $p2.Id -Force -ErrorAction SilentlyContinue } Catch { }
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
      }
    }
  }

  Context 'One orchestrator per PC' {
    It 'ensures only one `coordinator`/orchestrator instance runs per PC' {
      $tmpDir = Join-Path $env:TEMP ([guid]::NewGuid().ToString())
      New-Item -ItemType Directory -Path $tmpDir | Out-Null
      $mappingPath = Join-Path $tmpDir 'mapping.coordinator.json'

      $p1 = Start-Process -FilePath ping -ArgumentList '-t','127.0.0.1' -PassThru
      $p2 = Start-Process -FilePath ping -ArgumentList '-t','127.0.0.1' -PassThru
      try {
        $agents = @(
          @{ name='coord-1'; pid=$p1.Id; primaryRole='coordinator'; startedAt=(Get-Date).ToString('o') },
          @{ name='coord-2'; pid=$p2.Id; primaryRole='coordinator'; startedAt=(Get-Date).ToString('o') }
        )
        $agents | ConvertTo-Json -Compress | Set-Content -Path $mappingPath -Encoding UTF8
        # debug: emit initial mapping written and append to repo debug log
        try { $init = Get-Content $mappingPath -Raw -ErrorAction Stop; Write-Output '[TestDebug] Initial mapping:'; Write-Output $init } catch { Write-Output '[TestDebug] Failed to read initial mapping' }

        $enforcer = (Resolve-Path .\scripts\enforce-single-agent-per-role.ps1).Path
        $outLog = Join-Path $tmpDir 'enforcer.out'
        $merged = & $enforcer -MappingFile $mappingPath 2>&1
        try { $merged | Out-File -FilePath $outLog -Encoding UTF8 -Force } catch { }
        if ($merged) { Write-Output '[TestDebug] Enforcer output:'; $merged | Write-Output }
        Start-Sleep -Milliseconds 200
        try { $rawMap = Get-Content $mappingPath -Raw -ErrorAction Stop; Write-Output '[TestDebug] Mapping after enforcer (len=' + ($rawMap.Length) + '):'; Write-Output $rawMap } catch { Write-Output '[TestDebug] Mapping not readable after enforcer' }

        # poll for up to 12s for coordinator enforcement
        $ok2 = $false
        $maxWait2 = 12
        for ($j=0; $j -lt $maxWait2; $j++) {
          Start-Sleep -Seconds 1
          try {
            $contentRaw2 = Get-Content $mappingPath -Raw
            $parsed2 = $null
            try { $parsed2 = $contentRaw2 | ConvertFrom-Json } catch { $parsed2 = $null }
            $coordAlive = 0
            if ($parsed2) { $coordAlive = ($parsed2 | Where-Object { $_.primaryRole -eq 'coordinator' -and $_.pid -ne $null }).Count }
            if ($coordAlive -le 1) { $ok2 = $true; break }
          } catch { }
        }
        # enforcer ran synchronously with -Wait; no background process to stop
        if (-not $ok2) {
          Write-Output "[TestDebug] Coordinator mapping after timeout:"
          try { Get-Content $mappingPath -Raw | Write-Output } catch { Write-Output "[TestDebug] Failed to read mapping" }
        }
        $ok2 | Should -BeTrue
        # ensure final mapping is parseable before asserting (mitigate transient read/parse race)
        $content = $null
        for ($r=0; $r -lt 10; $r++) {
          Start-Sleep -Milliseconds 200
          try { $raw2 = Get-Content $mappingPath -Raw -ErrorAction Stop } catch { continue }
          try { $content = $raw2 | ConvertFrom-Json; if ($content) { break } } catch { $content = $null }
        }
        (@($content | Where-Object { $_.primaryRole -eq 'coordinator' -and $_.pid -ne $null })).Count | Should -Be 1
      } finally {
        Try { Stop-Process -Id $p1.Id -Force -ErrorAction SilentlyContinue } Catch { }
        Try { Stop-Process -Id $p2.Id -Force -ErrorAction SilentlyContinue } Catch { }
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
      }
    }
  }

  Context 'DryRun validation scaffold' {
    It 'creates a DryRun config scaffold for single-agent-per-role testing' {
      # Helper: generate a minimal DryRun mapping placeholder for manual runs
      $tmp = Join-Path $env:TEMP ([guid]::NewGuid().ToString())
      New-Item -ItemType Directory -Path $tmp | Out-Null
      $mappingPath = Join-Path $tmp 'mapping.single-role.json'
      $agents = @(
        @{ name='tester-1'; pid=0; primaryRole='tester' },
        @{ name='tester-2'; pid=0; primaryRole='tester' }
      )
      $agents | ConvertTo-Json -Compress | Set-Content -Path $mappingPath -Encoding UTF8
      (Test-Path $mappingPath) | Should -BeTrue
      Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}
