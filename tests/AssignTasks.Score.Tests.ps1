Import-Module -Name Pester -MinimumVersion "5.0" -ErrorAction Stop

Describe 'assign_tasks_by_skill scoring' {
    BeforeAll {
        $assignerPath = Resolve-Path (Join-Path $PSScriptRoot '..\scripts\assign_tasks_by_skill.ps1') -ErrorAction Stop
        . $assignerPath.Path
    }

    It 'prefers agent with matching skill (API) for an API bug' {
        $tmpBacklog = [System.IO.Path]::GetTempFileName()
        $tmpAgents = [System.IO.Path]::GetTempFileName()
        $tmpOutJson = [System.IO.Path]::GetTempFileName()
        $tmpOutTxt = [System.IO.Path]::GetTempFileName()

        $backlog = @{ items = @( @{ id = 1; title = 'Fix API bug'; description = 'API returns 500 on POST'; priority = 'high'; estimate_points = 2 } ) }
        $agents = @(
            @{ name = 'api-pro'; capacity = 10; skills = @{ 'API' = 5 } },
            @{ name = 'generalist'; capacity = 10; skills = @{ 'Assignment' = 4 } }
        )
        $backlog | ConvertTo-Json | Out-File $tmpBacklog -Encoding UTF8
        $agents | ConvertTo-Json | Out-File $tmpAgents -Encoding UTF8

        $res = Invoke-AssignTasks -BacklogPathParam $tmpBacklog -AgentsConfigPathParam $tmpAgents -OutJsonParam $tmpOutJson -OutTxtParam $tmpOutTxt
        $res.assignments[0].assignedTo | Should -Be 'api-pro'
    }

    It 'breaks ties reproducibly by remaining capacity then name' {
        $tmpBacklog = [System.IO.Path]::GetTempFileName()
        $tmpAgents = [System.IO.Path]::GetTempFileName()
        $tmpOutJson = [System.IO.Path]::GetTempFileName()
        $tmpOutTxt = [System.IO.Path]::GetTempFileName()

        # create situation where both agents score equally but different remaining capacity
        $backlog = @{ items = @( @{ id = 1; title = 'Write report'; description = 'generate report'; priority = 'medium'; estimate_points = 2 } ) }
        $agents = @(
            @{ name = 'alice'; capacity = 5; skills = @{ 'Reporting' = 3 } },
            @{ name = 'bob'; capacity = 10; skills = @{ 'Reporting' = 3 } }
        )
        $backlog | ConvertTo-Json | Out-File $tmpBacklog -Encoding UTF8
        $agents | ConvertTo-Json | Out-File $tmpAgents -Encoding UTF8

        $res = Invoke-AssignTasks -BacklogPathParam $tmpBacklog -AgentsConfigPathParam $tmpAgents -OutJsonParam $tmpOutJson -OutTxtParam $tmpOutTxt
        # bob has more capacity -> should be chosen
        $res.assignments[0].assignedTo | Should -Be 'bob'
    }
}
