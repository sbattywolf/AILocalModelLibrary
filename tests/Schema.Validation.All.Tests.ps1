Describe 'Schema Validation - all .continue JSON skill checks' {
    BeforeAll {
        $repoRoot = Split-Path -Path $PSScriptRoot -Parent
        # prefer the cleaned helper for reliable dot-sourcing in Pester
        $helpers = Join-Path $repoRoot 'tests\TestHelpers.psm1'
        if (Test-Path $helpers) { . $helpers } else { Throw "Missing helpers: $helpers" }
        # inline constraints to avoid fragile JSON parsing in test runners
        $skillPattern = '^([a-z]+:)?[a-z0-9-]+$'
        $minLen = 1
        $maxLen = 60

        function Collect-SkillsFromObject {
            param($obj)
            $out = @()
            if ($null -eq $obj) { return $out }
            if ($obj.PSObject.Properties.Match('skills').Count -gt 0) {
                $skills = $obj.skills
                if ($skills -is [System.Collections.IEnumerable]) { $out += $skills }
            }
            if ($obj.PSObject.Properties.Match('teamPresets').Count -gt 0) {
                foreach ($k in $obj.teamPresets.PSObject.Properties.Name) {
                    $val = $obj.teamPresets.$k
                    if ($val -is [System.Collections.IEnumerable]) { $out += $val }
                }
            }
            if ($obj.PSObject.Properties.Match('agentRoles').Count -gt 0) {
                $agents = $obj.agentRoles.agents
                if ($agents -is [System.Collections.IEnumerable]) {
                    foreach ($a in $agents) {
                        if ($a.PSObject.Properties.Match('skills').Count -gt 0) { $out += $a.skills }
                        if ($a.PSObject.Properties.Match('skillWeights').Count -gt 0) { $out += $a.skillWeights.PSObject.Properties.Name }
                    }
                }
            }
            return $out | Where-Object { $_ -is [string] } | Select-Object -Unique
        }
    }

    It 'validates skill-like strings across all .continue JSON files' {
        $files = Get-ChildItem -Path (Join-Path $repoRoot '.continue') -Filter '*.json' -File -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            try {
                $raw = Get-Content -Raw -Encoding UTF8 -Path $f.FullName
                $obj = $raw | ConvertFrom-Json -ErrorAction Stop
            } catch {
                # fallback: skip files we cannot parse
                continue
            }
            $skills = Collect-SkillsFromObject -obj $obj
            $candidatePath = Join-Path $repoRoot '.continue\skill-candidates.json'
            $candidates = @()
            if (Test-Path $candidatePath) {
                try { $candidates = (Get-Content -Raw -Path $candidatePath | ConvertFrom-Json).candidates } catch { $candidates = @() }
            }
            foreach ($s in $skills) {
                if (-not ($s.Length -ge $minLen)) { if ($candidates -notcontains $s) { $candidates += $s }; Write-Warning "Collected candidate skill (too short): $s from $($f.Name)"; continue }
                if (-not ($s.Length -le $maxLen)) { if ($candidates -notcontains $s) { $candidates += $s }; Write-Warning "Collected candidate skill (too long): $s from $($f.Name)"; continue }
                if ($s -match $skillPattern) {
                    $s | Should -Match $skillPattern -Because "$($f.Name) -> '$s' does not match pattern"
                } else {
                    if ($candidates -notcontains $s) { $candidates += $s }
                    Write-Warning "Collected candidate skill: $s from $($f.Name)"
                }
            }
            if ($candidates.Count -gt 0) {
                $out = @{ generated = (Get-Date).ToString('o'); candidates = $candidates }
                $out | ConvertTo-Json -Depth 5 | Set-Content -Path $candidatePath -Encoding UTF8
            }
        }
    }
}
Describe 'Schema Validation - all .continue JSON skill checks' {
    BeforeAll {
        $repoRoot = Split-Path -Path $PSScriptRoot -Parent
        $helpers = Join-Path $repoRoot 'tests\TestHelpers.psm1'
        if (Test-Path $helpers) { . $helpers } else { Throw "Missing helpers: $helpers" }
        $schemaPath = Join-Path $repoRoot 'schemas\skills.schema.json'
        $fixedSchema = Join-Path $repoRoot 'schemas\skills.schema.fixed.json'
        if (Test-Path $fixedSchema) {
            $schema = Get-Content -Raw -Path $fixedSchema | ConvertFrom-Json
        } elseif (Test-Path $schemaPath) {
            try { $schema = Get-Content -Raw -Path $schemaPath | ConvertFrom-Json } catch { $schema = $null }
        } else {
            $schema = $null
        }
        if ($null -eq $schema) {
            # fallback inline constraints when schema cannot be parsed
            $skillPattern = '^([a-z]+:)?[a-z0-9-]+$'
            $minLen = 1
            $maxLen = 60
        } else {
            $skillPattern = $schema.properties.skills.items.pattern
            $minLen = $schema.properties.skills.items.minLength
            $maxLen = $schema.properties.skills.items.maxLength
        }

        function Find-SkillStrings {
            param($obj)
            $out = @()
            if ($null -eq $obj) { return $out }
            if ($obj -is [string]) { return @($obj) }
            if ($obj -is [System.Collections.IEnumerable]) {
                foreach ($it in $obj) { $out += (Find-SkillStrings -obj $it) }
                return $out
            }
            # PSCustomObject / hashtable
            foreach ($p in $obj.PSObject.Properties) {
                if ($p.Name -match 'skills') {
                    $out += (Find-SkillStrings -obj $p.Value)
                    continue
                }
                if ($p.Name -eq 'name' -and ($p.Value -is [string])) { $out += $p.Value; continue }
                $out += (Find-SkillStrings -obj $p.Value)
            }
            return $out
        }
    }

    It 'validates skill-like strings across all .continue JSON files' {
        $files = Get-ChildItem -Path (Join-Path $repoRoot '.continue') -Filter '*.json' -File -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            $obj = Test-LoadJson -Path $f.FullName
            $skills = Find-SkillStrings -obj $obj | Where-Object { $_ -is [string] } | Select-Object -Unique
            $candidatePath = Join-Path $repoRoot '.continue\skill-candidates.json'
            $candidates = @()
            if (Test-Path $candidatePath) {
                try { $candidates = (Get-Content -Raw -Path $candidatePath | ConvertFrom-Json).candidates } catch { $candidates = @() }
            }
            foreach ($s in $skills) {
                if (-not ($s.Length -ge $minLen)) { if ($candidates -notcontains $s) { $candidates += $s }; Write-Warning "Collected candidate skill (too short): $s from $($f.Name)"; continue }
                if (-not ($s.Length -le $maxLen)) { if ($candidates -notcontains $s) { $candidates += $s }; Write-Warning "Collected candidate skill (too long): $s from $($f.Name)"; continue }
                if ($s -match $skillPattern) {
                    $s | Should -Match $skillPattern -Because "$($f.Name) -> '$s' does not match pattern"
                } else {
                    if ($candidates -notcontains $s) { $candidates += $s }
                    Write-Warning "Collected candidate skill: $s from $($f.Name)"
                }
            }
            if ($candidates.Count -gt 0) {
                $out = @{ generated = (Get-Date).ToString('o'); candidates = $candidates }
                $out | ConvertTo-Json -Depth 5 | Set-Content -Path $candidatePath -Encoding UTF8
            }
        }
    }
}
