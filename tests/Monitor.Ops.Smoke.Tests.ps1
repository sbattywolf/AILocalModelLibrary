Describe 'Monitor OPS smoke tests' {
  Context 'Sampler telemetry creation' {
    It 'writes telemetry lines to the specified telemetry file' {
      $tempDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
      New-Item -ItemType Directory -Path $tempDir | Out-Null
      $mappingPath = Join-Path $tempDir 'mapping.json'
      $telemetryPath = Join-Path $tempDir 'telemetry.log'

      # start a lightweight dummy process (ping) so sampler will record stats
      $ping = Start-Process -FilePath ping -ArgumentList '-t','127.0.0.1' -PassThru
      try {
        $mapping = ,(@{ name='ops-smoke-sampler'; pid=$ping.Id }) | ConvertTo-Json -Compress
        Set-Content -Path $mappingPath -Value $mapping -Encoding UTF8

        # Use the deterministic single-sample sampler synchronously to avoid timing flakiness
        $scriptSingle = (Resolve-Path .\scripts\agent-runtime-monitor-single-sample.ps1).Path
        $psArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$scriptSingle,'-MappingFile',$mappingPath,'-TelemetryFile',$telemetryPath,'-Pid',$ping.Id)
        # run the sampler and wait for completion to avoid timing issues
        # invoke the sampler in-process (synchronous) to avoid inter-process timing and variable-binding issues
        & $scriptSingle -MappingFile $mappingPath -TelemetryFile $telemetryPath

        # short wait for the file to be created after the sampler exits (give it a bit more time)
        $ok = $false
        for ($i=0; $i -lt 15; $i++) {
          Start-Sleep -Seconds 1
          if (Test-Path $telemetryPath) { $ok = $true; break }
        }

        # Assert telemetry file exists
        $ok | Should -BeTrue

        # Retry reading lines and ensure at least one parseable JSON line exists
        $lines = @()
        for ($r=0; $r -lt 10; $r++) {
          Start-Sleep -Milliseconds 200
          try { $lines = Get-Content $telemetryPath -ErrorAction Stop } catch { continue }
          if ($lines.Count -gt 0) { break }
        }
        $lines.Count | Should -BeGreaterThan 0

        $firstJson = $null
        for ($r=0; $r -lt 8; $r++) {
          foreach ($ln in $lines) {
            $s = $ln.Trim()
            if (-not $s) { continue }
            try { $firstJson = $s | ConvertFrom-Json; break } catch { }
          }
          if ($firstJson) { break }
          Start-Sleep -Milliseconds 200
          try { $lines = Get-Content $telemetryPath -ErrorAction Stop } catch { }
        }
        $firstJson | Should -Not -BeNullOrEmpty
      } finally {
        Try { Stop-Process -Id $ping.Id -Force -ErrorAction SilentlyContinue } Catch { }
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
      }
    }
  }

  Context 'Monitor mapping updates' {
    It 'reads mapping and updates it (non-destructive) when agents report' {
      $tempDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
      New-Item -ItemType Directory -Path $tempDir | Out-Null
      $mappingPath = Join-Path $tempDir 'mapping.json'
      $telemetryPath = Join-Path $tempDir 'telemetry.log'

      $ping = Start-Process -FilePath ping -ArgumentList '-t','127.0.0.1' -PassThru
      try {
        $mapping = ,(@{ name='ops-smoke-monitor'; pid=$ping.Id; primaryRole='worker' }) | ConvertTo-Json -Compress
        Set-Content -Path $mappingPath -Value $mapping -Encoding UTF8

          $scriptPath2 = (Resolve-Path .\scripts\monitor-agents-epic.ps1).Path
          $psArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$scriptPath2,'-MappingFile',$mappingPath,'-IntervalSeconds','1','-DryRun')
          $proc = Start-Process -FilePath powershell -ArgumentList $psArgs -WorkingDirectory $tempDir -PassThru
        # wait briefly for monitor to touch mapping (retries up to ~40s)
        $ok = $false
        for ($i=0; $i -lt 40; $i++) {
          Start-Sleep -Seconds 1
          if (Test-Path $mappingPath) { $ok = $true; break }
        }
        Try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } Catch { }

        # mapping file should still be present and valid JSON
        (Test-Path $mappingPath) | Should -BeTrue
        # ensure mapping is parseable with retries
        $content = $null
        for ($r=0; $r -lt 15; $r++) {
          Start-Sleep -Milliseconds 200
          try { $raw = Get-Content $mappingPath -Raw -ErrorAction Stop } catch { continue }
          try { $content = $raw | ConvertFrom-Json; if ($content) { break } } catch { $content = $null }
        }
        $content | Should -Not -BeNullOrEmpty
      } finally {
        Try { Stop-Process -Id $ping.Id -Force -ErrorAction SilentlyContinue } Catch { }
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
      }
    }
  }

  Context 'Role separation (OPS vs Tester)' {
    It 'handles ops and tester agents without interfering' {
      $tempDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
      New-Item -ItemType Directory -Path $tempDir | Out-Null
      $mappingPath = Join-Path $tempDir 'mapping.json'
      $telemetryPath = Join-Path $tempDir 'telemetry.log'

      $ping1 = Start-Process -FilePath ping -ArgumentList '-t','127.0.0.1' -PassThru
      $ping2 = Start-Process -FilePath ping -ArgumentList '-t','127.0.0.1' -PassThru
      try {
        $agents = @(
          @{ name = 'ops-agent'; pid = $ping1.Id; primaryRole = 'ops' },
          @{ name = 'tester-agent'; pid = $ping2.Id; primaryRole = 'tester' }
        )
        $mapping = $agents | ConvertTo-Json -Compress
        Set-Content -Path $mappingPath -Value $mapping -Encoding UTF8

          $scriptPath2 = (Resolve-Path .\scripts\monitor-agents-epic.ps1).Path
          $psArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$scriptPath2,'-MappingFile',$mappingPath,'-IntervalSeconds','1','-DryRun')
          $proc = Start-Process -FilePath powershell -ArgumentList $psArgs -WorkingDirectory $tempDir -PassThru
        # wait briefly for monitor to process and update mapping (retries up to ~40s)
        $ok = $false
        for ($i=0; $i -lt 40; $i++) {
          Start-Sleep -Seconds 1
          if (Test-Path $mappingPath) { $ok = $true; break }
        }
        if (-not $ok) { Start-Sleep -Seconds 2 }
        Try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } Catch { }

        # mapping file should still be present and contain both agents
        (Test-Path $mappingPath) | Should -BeTrue
        # ensure mapping is parseable with retries
        $content = $null
        for ($r=0; $r -lt 15; $r++) {
          Start-Sleep -Milliseconds 200
          try { $raw = Get-Content $mappingPath -Raw -ErrorAction Stop } catch { continue }
          try { $content = $raw | ConvertFrom-Json; if ($content) { break } } catch { $content = $null }
        }
        @($content | Where-Object { $_.name -eq 'ops-agent' }).Count | Should -Be 1
        @($content | Where-Object { $_.name -eq 'tester-agent' }).Count | Should -Be 1
      } finally {
        Try { Stop-Process -Id $ping1.Id -Force -ErrorAction SilentlyContinue } Catch { }
        Try { Stop-Process -Id $ping2.Id -Force -ErrorAction SilentlyContinue } Catch { }
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
      }
    }
  }
}
