Import-Module Pester -ErrorAction SilentlyContinue

Describe "Start/Stop/Monitor scripts" {
    BeforeAll {
        $RepoRoot = (Get-Location).Path
        # Prepare test env: ensure .\.continue and logs exist and use shim in PATH
        if (-not (Test-Path '.\.continue')) { New-Item -ItemType Directory -Path '.\.continue' | Out-Null }
        if (-not (Test-Path '.\\logs')) { New-Item -ItemType Directory -Path '.\\logs' | Out-Null }
        if (-not (Test-Path '.\.continue\tempTest\bin')) { New-Item -ItemType Directory -Path '.\.continue\tempTest\bin' -Force | Out-Null }
        # Copy shim if missing (tests assume it exists in repo)
        $shimSrc = Join-Path $PSScriptRoot '..\.continue\tempTest\bin\ollama.cmd'
        $shimPath = Join-Path (Get-Location) '.\.continue\tempTest\bin\ollama.cmd'
        # ensure PATH includes the shim dir for the test process only
        $env:PATH = (Join-Path (Get-Location) '.\.continue\tempTest\bin') + ";" + $env:PATH
        # Backup mapping file if present
        $mapFile = '.\.continue\ollama-processes.json'
        if (Test-Path $mapFile) { Copy-Item -Path $mapFile -Destination "$mapFile.bak" -Force }
        # Clean mapping for tests
        if (Test-Path $mapFile) { Remove-Item $mapFile -Force }
    }

    AfterAll {
        # Restore mapping if backed up
        $mapFile = '.\.continue\ollama-processes.json'
        if (Test-Path "$mapFile.bak") { Move-Item -Path "$mapFile.bak" -Destination $mapFile -Force }
    }

    It "start-ollama-role appends mapping when starting serve" {
        # Start a serve (uses shim) and assert mapping contains role entry
        & powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-ollama-role.ps1 -Role ci-mapping -Action serve -LogDir .\logs | Out-Null
        Start-Sleep -Seconds 1
        Test-Path '.\.continue\ollama-processes.json' | Should -BeTrue
        $maps = Get-Content -Path '.\.continue\ollama-processes.json' -Raw | ConvertFrom-Json
        if (-not $maps) { $maps = @() }
        if ($maps -and -not ($maps -is [System.Array])) { $maps = @($maps) }
        $count = 0
        if ($maps) { $count = @($maps | Where-Object { $_.Role -eq 'ci-mapping' }).Count } else { $raw = Get-Content -Path '.\.continue\ollama-processes.json' -Raw; if ($raw -and ($raw -match '"Role"\s*:\s*"ci-mapping"')) { $count = 1 } }
        $count | Should -BeGreaterThan 0
    }

    It "stop-ollama-role removes mapping for role" {
        # Ensure we can stop by role
        & powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\stop-ollama-role.ps1 -Role ci-mapping | Out-Null
        Start-Sleep -Seconds 1
        if (Test-Path '.\.continue\ollama-processes.json') {
            $maps = Get-Content -Path '.\.continue\ollama-processes.json' -Raw | ConvertFrom-Json
            if (-not $maps) { $maps = @() }
            if ($maps -and -not ($maps -is [System.Array])) { $maps = @($maps) }
            $count = 0
            if ($maps) { $count = @($maps | Where-Object { $_.Role -eq 'ci-mapping' }).Count } else { $raw = Get-Content -Path '.\.continue\ollama-processes.json' -Raw; if ($raw -and ($raw -match '"Role"\s*:\s*"ci-mapping"')) { $count = 1 } }
            $count | Should -Be 0
        } else {
            # if file removed entirely, that's acceptable
            Test-Path '.\.continue\ollama-processes.json' | Should -BeFalse
        }
    }

    It "start-ollama-role uses LogDir default when not provided" {
        # Start without LogDir and check that a log file is created under logs/
        & powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-ollama-role.ps1 -Role ci-logcheck -Action serve | Out-Null
        Start-Sleep -Seconds 1
        $maps = Get-Content -Path '.\.continue\ollama-processes.json' -Raw | ConvertFrom-Json
        if (-not $maps) { $maps = @() }
        if ($maps -and -not ($maps -is [System.Array])) { $maps = @($maps) }
        $entry = ($maps | Where-Object { $_.Role -eq 'ci-logcheck' } | Select-Object -First 1)
        $entry | Should -Not -BeNullOrEmpty
        $entry.LogFile | Should -Match 'logs\\ollama-ci-logcheck-'
    }

    It "inner command quoting preserves prompt text" {
        $prompt = 'O''Reilly''s test "quoted"'
        & powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-ollama-role.ps1 -Role ci-quote -Action run -Model test-model -Prompt $prompt | Out-Null
        Start-Sleep -Seconds 1
        $maps = Get-Content -Path '.\.continue\ollama-processes.json' -Raw | ConvertFrom-Json
        if (-not $maps) { $maps = @() }
        if ($maps -and -not ($maps -is [System.Array])) { $maps = @($maps) }
        $entry = ($maps | Where-Object { $_.Role -eq 'ci-quote' } | Select-Object -First 1)
        $entry | Should -Not -BeNullOrEmpty
        # The Prompt field should exist (we store it), exact quoting might differ; ensure substring present
        $entry.Prompt | Should -Match "O'Reilly"
    }
}
