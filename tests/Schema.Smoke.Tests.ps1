Describe 'Schema Smoke - load .continue JSON' {
    It 'loads all json files under .continue without error' {
        $repoRoot = Split-Path -Path $PSScriptRoot -Parent
        $continueDir = Join-Path $repoRoot '.continue'
        if (-not (Test-Path $continueDir)) { New-Item -ItemType Directory -Path $continueDir | Out-Null }

        $files = Get-ChildItem -Path $continueDir -Filter '*.json' -File -ErrorAction SilentlyContinue
        $nonEmpty = $files | Where-Object { $_.Length -gt 0 }
        $nonEmpty | Should -Not -BeNullOrEmpty

        $parsed = 0
        foreach ($f in $nonEmpty) {
            $obj = Test-LoadJson -Path $f.FullName
            if ($null -ne $obj -and $obj -ne '') { $parsed++ }
        }

        $parsed | Should -BeGreaterThan 0
    }
}
