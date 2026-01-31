Describe 'Agent-Roles Schema - basic validation' {
    It 'validates .continue\agent-roles.json conforms to schema constraints' {
        $repoRoot = Split-Path -Path $PSScriptRoot -Parent
        Import-Module (Join-Path $repoRoot 'tests\TestHelpers.psm1') -Force | Out-Null

        $path = Join-Path $repoRoot '.continue\agent-roles.json'
        if (-not (Test-Path $path)) { Skip "No agent-roles.json found at $path" }

        $roles = Test-LoadJson -Path $path
        $roles | Should -Not -BeNullOrEmpty

        # agents must be an array
        $agents = $roles.agents
        ($agents -is [System.Array]) | Should -BeTrue

        $skillPattern = '^([a-z]+:)?[a-z0-9\-]+$'

        foreach ($a in $agents) {
            $a.name | Should -BeOfType [string]
            if ($null -ne $a.skills) {
                ($a.skills -is [System.Array]) | Should -BeTrue
                ($a.skills.Count -le 10) | Should -BeTrue
                ($a.skills | Select-Object -Unique).Count | Should -Be $a.skills.Count
                foreach ($s in $a.skills) { $s | Should -Match $skillPattern }
            }

            if ($null -ne $a.skillWeights) {
                ($a.skillWeights -is [System.Object]) | Should -BeTrue
                foreach ($p in $a.skillWeights.psobject.Properties.Name) {
                    $val = $a.skillWeights.$p
                    ($val -is [int]) | Should -BeTrue
                    ($val -ge 1) | Should -BeTrue
                    ($val -le 5) | Should -BeTrue
                }
            }
        }

        if ($null -ne $roles.teamPresets) {
            foreach ($k in $roles.teamPresets.psobject.Properties.Name) {
                $arr = $roles.teamPresets.$k
                ($arr -is [System.Array]) | Should -BeTrue
                ($arr | Select-Object -Unique).Count | Should -Be $arr.Count
                foreach ($s in $arr) { $s | Should -Match $skillPattern }
            }
        }
    }

    It 'validates all .continue JSON files against schema-derived rules' {
        $repoRoot = Split-Path -Path $PSScriptRoot -Parent
        Import-Module (Join-Path $repoRoot 'tests\TestHelpers.psm1') -Force | Out-Null

        $continueDir = Join-Path $repoRoot '.continue'
        if (-not (Test-Path $continueDir)) { Write-Verbose "No .continue dir found; skipping"; return }

        $files = Get-ChildItem -Path $continueDir -Filter '*.json' -File -ErrorAction SilentlyContinue
        $candidates = @()
        foreach ($f in $files) {
            $obj = Test-LoadJson -Path $f.FullName
            if ($null -eq $obj) { Continue }

            # validate global skills shape when present (accept array or object mapping)
            if ($obj.PSObject.Properties.Name -contains 'skills') {
                if ($obj.skills -is [System.Array]) {
                    ($obj.skills.Count -le 200) | Should -BeTrue -Because "$($f.Name): skills maxItems exceeded"
                    ($obj.skills | Select-Object -Unique).Count | Should -Be $obj.skills.Count -Because "$($f.Name): skills must be unique"
                    foreach ($s in $obj.skills) {
                        ($s -is [string]) | Should -BeTrue -Because "$($f.Name): skill must be string"
                        ($s.Length -ge 1) | Should -BeTrue
                        ($s.Length -le 60) | Should -BeTrue
                        $s | Should -Match '^([a-z]+:)?[a-z0-9\-]+$' -Because "$($f.Name): skill pattern"
                    }
                } elseif ($obj.skills -is [System.Object]) {
                    foreach ($k in $obj.skills.psobject.Properties.Name) {
                        ($k -is [string]) | Should -BeTrue -Because "$($f.Name): skill key must be string"
                        $k | Should -Match '^([a-z]+:)?[a-z0-9\-]+$' -Because "$($f.Name): skill key pattern"
                    }
                } else {
                    ($false) | Should -BeTrue -Because "$($f.Name): skills must be array or object mapping"
                }
            }

            # validate teamPresets when present
            if ($obj.PSObject.Properties.Name -contains 'teamPresets') {
                ($obj.teamPresets -is [System.Object]) | Should -BeTrue -Because "$($f.Name): teamPresets must be an object"
                foreach ($k in $obj.teamPresets.psobject.Properties.Name) {
                    $arr = $obj.teamPresets.$k
                    ($arr -is [System.Array]) | Should -BeTrue -Because "$($f.Name): teamPresets.$k must be array"
                    ($arr.Count -le 50) | Should -BeTrue -Because "$($f.Name): teamPresets.$k maxItems exceeded"
                    ($arr | Select-Object -Unique).Count | Should -Be $arr.Count -Because "$($f.Name): teamPresets.$k items must be unique"
                    foreach ($s in $arr) {
                        ($s -is [string]) | Should -BeTrue
                        ($s.Length -ge 1) | Should -BeTrue
                        ($s.Length -le 60) | Should -BeTrue
                        $s | Should -Match '^([a-z]+:)?[a-z0-9\-]+$'
                    }
                }
            }

            # validate agents shape when present
            if ($obj.PSObject.Properties.Name -contains 'agents') {
                ($obj.agents -is [System.Array]) | Should -BeTrue -Because "$($f.Name): agents must be array"
                foreach ($a in $obj.agents) {
                    $a.name | Should -BeOfType [string]
                    if ($a.PSObject.Properties.Name -contains 'skills') {
                        ($a.skills -is [System.Array]) | Should -BeTrue
                        ($a.skills.Count -le 10) | Should -BeTrue -Because "$($f.Name): agent skills maxItems exceeded"
                        ($a.skills | Select-Object -Unique).Count | Should -Be $a.skills.Count
                        foreach ($s in $a.skills) { $s | Should -Match '^([a-z]+:)?[a-z0-9\-]+$' }
                    }
                    if ($a.PSObject.Properties.Name -contains 'skillWeights') {
                        ($a.skillWeights -is [System.Object]) | Should -BeTrue
                        foreach ($p in $a.skillWeights.psobject.Properties.Name) {
                            $val = $a.skillWeights.$p
                            ($val -is [int]) | Should -BeTrue
                            ($val -ge 1) | Should -BeTrue
                            ($val -le 5) | Should -BeTrue
                        }
                    }
                    # collect unknown per-agent properties as candidates/warnings
                    $knownAgentKeys = @('name','role','skills','skillWeights')
                    foreach ($prop in $a.PSObject.Properties.Name) {
                        if ($knownAgentKeys -notcontains $prop) {
                            Write-Warning "$($f.Name): agent '$($a.name)' has unknown property '$prop'"
                            $candidates += [PSCustomObject]@{ file = $f.Name; type = 'agent-unknown-prop'; agent = $a.name; property = $prop; value = $a.$prop }
                        }
                    }
                }
            }

            # collect unknown top-level properties as candidates
            $knownTop = @('skills','teamPresets','agents','agentRoles')
            foreach ($top in $obj.PSObject.Properties.Name) {
                if ($knownTop -notcontains $top) {
                    Write-Warning "$($f.Name): has unexpected top-level property '$top'"
                    $candidates += [PSCustomObject]@{ file = $f.Name; type = 'top-unknown-prop'; property = $top; value = $obj.$top }
                }
            }
        }

        if ($candidates.Count -gt 0) {
            $outPath = Join-Path $repoRoot '.continue\skill-candidates.json'
            try {
                Test-WriteJsonAtomic -Path $outPath -Object @{ generated = (Get-Date).ToString('o'); candidates = $candidates }
                Write-Warning "Wrote candidate list to $outPath"
            } catch {
                Write-Warning "Failed to write candidate list: $($_.Exception.Message)"
            }
        }
    }
}
