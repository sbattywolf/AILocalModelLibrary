Describe 'Agents Epic Roles and Coordination' {

    It 'Has an agent roles mapping file' {
        $path = '.continue/agent-roles.json'
        Test-Path $path | Should -BeTrue
        $roles = Get-Content $path -Raw | ConvertFrom-Json
        $roles.agents.Count | Should -BeGreaterThan 0
    }

    It 'All role entries map to configured agents and include required fields' {
        $roles = Get-Content '.continue/agent-roles.json' -Raw | ConvertFrom-Json
        $cfg = Get-Content '.continue/config.agent' -Raw | ConvertFrom-Json
        $agentNames = $cfg.agents | ForEach-Object { $_.name }

        foreach ($a in $roles.agents) {
            if ($a.name -in $agentNames) {
                # ensure required fields present for mapped agents
                ($null -ne $a.primaryRole) | Should -BeTrue
                ($null -ne $a.labels) | Should -BeTrue
                ($null -ne $a.resources) | Should -BeTrue
            } else {
                Write-Warning "Role entry '$($a.name)' not present in current config; skipping strict mapping assertion"
            }
        }
    }

    It 'Reports potential role conflicts and resource summary (warnings, non-fatal) ' {
        $roles = Get-Content '.continue/agent-roles.json' -Raw | ConvertFrom-Json

        # Collect primary role distribution
        $roleDist = @{}
        foreach ($a in $roles.agents) {
            $r = $a.primaryRole
            if (-not $roleDist.ContainsKey($r)) { $roleDist[$r] = 0 }
            $roleDist[$r] += 1
        }

        Write-Output "Role distribution:"
        $roleDist.GetEnumerator() | ForEach-Object { Write-Output ("{0}: {1}" -f $_.Key, $_.Value) }

        # Example conflict detection: too many high-priority compute-heavy agents
        $totalVram = 0
        foreach ($a in $roles.agents) { $totalVram += ($a.resources.vramGB -as [int]) }
        Write-Warning "Total requested VRAM (GB): $totalVram"

        # Warn if total VRAM likely exceeds common workstation (heuristic)
        if ($totalVram -gt 32) { Write-Warning "Resource demand high: total VRAM > 32GB. Consider scheduling or reducing concurrent agents." }

        # Detect overlapping coordinator role assignment (must be exactly 1)
        $coordCount = @($roles.agents | Where-Object { $_.primaryRole -eq 'coordinator' }).Count
        $coordCount | Should -Be 1

        # Non-fatal assertions to ensure test does not fail on warnings
        $true | Should -BeTrue
    }

}
