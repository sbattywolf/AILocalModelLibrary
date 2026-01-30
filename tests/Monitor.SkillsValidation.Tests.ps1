Describe 'Skill monitor validation' {
    It 'generates warnings and enforces limits' {
        $tmp = Join-Path $env:TEMP "skills-test-$(New-Guid)"
        New-Item -Path $tmp -ItemType Directory | Out-Null
        $rolesFile = Join-Path $tmp 'agent-roles.json'

        $roles = @(
            @{ name = 'agent-A'; skills = @('one','two','three','four','five','six') },
            @{ name = 'agent-B'; skills = @() },
            @{ name = 'agent-C'; skills = @('a very long skill name that exceeds the ten words limit because it is verbose and silly') }
        )

        $roles | ConvertTo-Json -Depth 6 | Out-File -FilePath $rolesFile -Encoding UTF8

        & powershell -NoProfile -ExecutionPolicy Bypass -File scripts/skill-monitor.ps1 -RolesFile $rolesFile -OutputDir $tmp | Out-Null

        $warn = Join-Path $tmp 'skills-warnings.json'
        Test-Path $warn | Should -Be $true
        $j = Get-Content $warn -Raw | ConvertFrom-Json
        $j.totalSkills | Should -BeGreaterThan 0
        @( $j.warnings | Where-Object { $_.issue -eq 'NoSkills' } ).Count | Should -Be 1
        @( $j.warnings | Where-Object { $_.issue -eq 'SkillTooLong' } ).Count | Should -Be 1

        Remove-Item -Path $tmp -Recurse -Force
    }
}
