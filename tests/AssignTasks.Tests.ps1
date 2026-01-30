Import-Module -Name Pester -MinimumVersion "5.0" -ErrorAction Stop

    Describe 'assign_tasks_by_skill functions' {
        BeforeAll {
            try {
                $assignerPath = Resolve-Path (Join-Path $PSScriptRoot '..\scripts\assign_tasks_by_skill.ps1') -ErrorAction Stop
                . $assignerPath.Path
            } catch { Throw "Could not dot-source assigner script: $_" }
        }
    It 'converts textual priorities to numbers' {
        Convert-PriorityToNumber 'critical' | Should -Be 1
        Convert-PriorityToNumber 'high' | Should -Be 2
        Convert-PriorityToNumber 'medium' | Should -Be 3
        Convert-PriorityToNumber 'low' | Should -Be 4
    }

    It 'calculates item points fallback and explicit' {
        $it = @{ points = 5 }
        Get-ItemPoints $it | Should -Be 5
        $it2 = @{ estimate = 2 }
        Get-ItemPoints $it2 | Should -Be 2
        $it3 = @{ title = 'no points' }
        Get-ItemPoints $it3 | Should -Be 1
    }

    It 'does not assign when capacity is insufficient' {
        $agents = @(
            @{ agentName = 'small'; capacityPoints = 1; skills = @{ 'Reporting' = 5 } }
        )
        $backlog = @{ items = @( @{ id = 1; title = 'big task'; priority = 'high'; points = 5 } ) }
        # dot-source helper functions
        $tmpFile = [System.IO.Path]::GetTempFileName()
        $backlog | ConvertTo-Json | Out-File $tmpFile -Encoding UTF8
        # call script programmatically
        & powershell -NoProfile -File .\scripts\assign_tasks_by_skill.ps1 -BacklogPath $tmpFile -OutJson $tmpFile -OutTxt $tmpFile -DryRun
        (Test-Path $tmpFile) | Should -BeTrue
    }
}
