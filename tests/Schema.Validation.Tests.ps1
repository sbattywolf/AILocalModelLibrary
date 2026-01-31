Describe 'Schema Validation - skills schema checks' {
    BeforeAll {
        $repoRoot = Split-Path -Path $PSScriptRoot -Parent
        . (Join-Path $repoRoot 'tests\TestHelpers.psm1')
        $schemaPath = Join-Path $repoRoot 'schemas\skills.schema.fixed.json'
        if (-not (Test-Path $schemaPath)) { Throw "Missing schema: $schemaPath" }
        $schema = Get-Content -Raw -Path $schemaPath | ConvertFrom-Json
        $skillPattern = $schema.properties.skills.items.pattern
        $minLen = $schema.properties.skills.items.minLength
        $maxLen = $schema.properties.skills.items.maxLength
    }

    It 'validates skills in .continue\agent-roles.json when present' {
        $rolesPath = Join-Path $repoRoot '.continue\agent-roles.json'
        if (-not (Test-Path $rolesPath)) { Should -BeNullOrEmpty $null; return }

        $roles = Test-LoadJson -Path $rolesPath
        $roles.agents | ForEach-Object {
            $a = $_
            if ($null -ne $a.skills) {
                ($a.skills -is [System.Array]) | Should -BeTrue
                # unique items
                ($a.skills | Select-Object -Unique).Count | Should -Be $a.skills.Count
                foreach ($s in $a.skills) {
                    ($s.Length -ge $minLen) | Should -BeTrue
                    ($s.Length -le $maxLen) | Should -BeTrue
                    $s | Should -Match $skillPattern
                }
            }
        }
    }

    It 'validates presets in .continue\team-presets.json when present' {
        $presetsPath = Join-Path $repoRoot '.continue\team-presets.json'
        if (-not (Test-Path $presetsPath)) { Should -BeNullOrEmpty $null; return }

        $presets = Test-LoadJson -Path $presetsPath
        foreach ($k in $presets.psobject.Properties.Name) {
            $arr = $presets.$k
            ($arr -is [System.Array]) | Should -BeTrue
            ($arr | Select-Object -Unique).Count | Should -Be $arr.Count
            foreach ($s in $arr) {
                ($s.Length -ge $minLen) | Should -BeTrue
                ($s.Length -le $maxLen) | Should -BeTrue
                $s | Should -Match $skillPattern
            }
        }
    }
}
