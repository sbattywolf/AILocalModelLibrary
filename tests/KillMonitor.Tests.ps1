Import-Module Pester -ErrorAction SilentlyContinue

Describe "Kill script behavior" {
    BeforeAll {
        # Setup repo paths and test dirs
        if (-not (Test-Path '.\.continue')) { New-Item -ItemType Directory -Path '.\.continue' | Out-Null }
        if (-not (Test-Path '.\\logs')) { New-Item -ItemType Directory -Path '.\\logs' | Out-Null }
        if (-not (Test-Path '.\.continue\tempTest\bin')) { New-Item -ItemType Directory -Path '.\.continue\tempTest\bin' -Force | Out-Null }
        $env:PATH = (Join-Path (Get-Location) '.\.continue\tempTest\bin') + ";" + $env:PATH

        $mapFile = '.\.continue\ollama-processes.json'
        if (Test-Path $mapFile) { Copy-Item -Path $mapFile -Destination "$mapFile.bak" -Force }
        if (Test-Path $mapFile) { Remove-Item $mapFile -Force }
    }

    AfterAll {
        $mapFile = '.\.continue\ollama-processes.json'
        if (Test-Path "$mapFile.bak") { Move-Item -Path "$mapFile.bak" -Destination $mapFile -Force }
    }

    It "kill DryRun does not remove mapping" {
        # start a role
        & powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-ollama-role.ps1 -Role ci-kill -Action serve -LogDir .\logs | Out-Null
        Start-Sleep -Seconds 1
        Test-Path '.\.continue\ollama-processes.json' | Should -BeTrue
        $maps = Get-Content -Path '.\.continue\ollama-processes.json' -Raw | ConvertFrom-Json
        if (-not $maps) { $maps = @() }
        if ($maps -and -not ($maps -is [System.Array])) { $maps = @($maps) }
        $initial = @($maps | Where-Object { $_.Role -eq 'ci-kill' }).Count
        $initial | Should -BeGreaterThan 0

        # DryRun
        & powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\kill-ollama-role.ps1 -Role ci-kill -DryRun | Out-Null
        Start-Sleep -Seconds 1
        $maps2 = Get-Content -Path '.\.continue\ollama-processes.json' -Raw | ConvertFrom-Json
        if (-not $maps2) { $maps2 = @() }
        if ($maps2 -and -not ($maps2 -is [System.Array])) { $maps2 = @($maps2) }
        $afterDry = @($maps2 | Where-Object { $_.Role -eq 'ci-kill' }).Count
        $afterDry | Should -Be $initial
    }

    It "kill actually removes mapping entries" {
        # perform actual kill (short grace)
        & powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\kill-ollama-role.ps1 -Role ci-kill -GraceSeconds 1 | Out-Null
        Start-Sleep -Seconds 1
        if (Test-Path '.\.continue\ollama-processes.json') {
            $maps = Get-Content -Path '.\.continue\ollama-processes.json' -Raw | ConvertFrom-Json
            if (-not $maps) { $maps = @() }
            if ($maps -and -not ($maps -is [System.Array])) { $maps = @($maps) }
            $count = @($maps | Where-Object { $_.Role -eq 'ci-kill' }).Count
            $count | Should -Be 0
        } else {
            Test-Path '.\.continue\ollama-processes.json' | Should -BeFalse
        }
    }
}
