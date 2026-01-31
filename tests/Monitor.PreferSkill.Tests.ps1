Describe "PreferSkill scheduler" {
    BeforeAll {
        $tmp = Join-Path $env:TEMP "prefer-skill-test-$(New-Guid)"
        New-Item -Path $tmp -ItemType Directory | Out-Null
        $Script:TmpDir = $tmp
        $Script:RolesFile = Join-Path $Script:TmpDir "agent-roles.json"
        $Script:OutFile = Join-Path $Script:TmpDir "proposal.json"

        $roles = @(
            @{ name = 'agent-A'; vramGB = 16; memoryGB = 8; skills = @('nlp','embedding') },
            @{ name = 'agent-B'; vramGB = 8; memoryGB = 4; skills = @('nlp') },
            @{ name = 'agent-C'; vramGB = 24; memoryGB = 12; skills = @('vision') }
        )

        $roles | ConvertTo-Json -Depth 5 | Out-File -FilePath $Script:RolesFile -Encoding UTF8
    }

    AfterAll {
        if (Test-Path $Script:TmpDir) { Remove-Item -Path $Script:TmpDir -Recurse -Force }
    }

    It "selects agents matching the skill ordered by vram desc" {
        & powershell -NoProfile -ExecutionPolicy Bypass -File scripts/scheduler-prefer-skill.ps1 -Skill nlp -RolesFile $Script:RolesFile -DryRun -OutputFile $Script:OutFile | Out-Null
        Test-Path $Script:OutFile | Should -Be $true
        Import-Module (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.psm1')).Path -Force
        $json = Load-JsonDefensive $Script:OutFile
        $json.skill | Should -Be 'nlp'
        $json.selectedCount | Should -Be 2
        $names = $json.selected | ForEach-Object { $_.name }
        # Expect agent-A (16) before agent-B (8)
        $names[0] | Should -Be 'agent-A'
        $names[1] | Should -Be 'agent-B'
    }

    It "respects MaxVramGB cumulative limit" {
        & powershell -NoProfile -ExecutionPolicy Bypass -File scripts/scheduler-prefer-skill.ps1 -Skill nlp -RolesFile $Script:RolesFile -DryRun -MaxVramGB 10 -OutputFile $Script:OutFile | Out-Null
        Import-Module (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.psm1')).Path -Force
        $json = Load-JsonDefensive $Script:OutFile
        # With MaxVramGB=10, only agent-B (8) fits
        $json.selectedCount | Should -Be 1
        $json.selected[0].name | Should -Be 'agent-B'
    }
}
 
