Describe 'Monitor PreferSkill Agents Proposal' {
    It 'creates proposal with expected structure (DryRun)' {
        $tmp = Join-Path $env:TEMP "prefer-skill-mon-$(New-Guid)"
        New-Item -Path $tmp -ItemType Directory | Out-Null
        $exceptionFile = Join-Path (Join-Path $PSScriptRoot '..') '.continue\sched-exception.txt'
        if (-not (Test-Path (Split-Path $exceptionFile -Parent))) { New-Item -ItemType Directory -Path (Split-Path $exceptionFile -Parent) -Force | Out-Null }
        try {
        $rolesFile = Join-Path $tmp "agent-roles.json"
        $backlogFile = Join-Path $tmp "backlog.json"
        $outFile = Join-Path $tmp "agents-proposal.json"

        $roles = @(
            @{ name = 'agent-A'; role = 'role-A'; vramGB = 16; memoryGB = 8; skills = @('nlp') },
            @{ name = 'agent-B'; role = 'role-B'; vramGB = 8; memoryGB = 4; skills = @('nlp','other') }
        )
        $roles | ConvertTo-Json -Depth 5 | Set-Content -Path $rolesFile -Encoding UTF8

        $backlog = @(
            @{ id = 'T1'; title = 'Task 1'; points = 2; skills = @('nlp') },
            @{ id = 'T2'; title = 'Task 2'; points = 4; skills = @('other') }
        )
        $backlog | ConvertTo-Json -Depth 5 | Set-Content -Path $backlogFile -Encoding UTF8

        # Import the scheduler module and call the function directly to avoid parameter-binding issues
        $modulePath = (Join-Path $PSScriptRoot '..\scripts\scheduler-prefer-skill.psm1')
        try {
            Import-Module $modulePath -Force
            # Dump the resolved command info for debugging parameter binding
            Get-Command Invoke-PreferSkillScheduler | Out-File -FilePath (Join-Path $tmp 'cmd-info.txt') -Encoding UTF8
            # Run scheduler in a fresh PowerShell process to avoid Pester runspace binding issues
            $psExe = (Get-Command powershell).Source
            $invokeCmd = "Import-Module '$modulePath' -Force; scheduler-prefer-skill\Invoke-PreferSkillScheduler '$rolesFile' '$backlogFile' '$outFile' -DryRun"
            & $psExe -NoProfile -ExecutionPolicy Bypass -Command $invokeCmd
            if ($LASTEXITCODE -ne 0) {
                "Scheduler child-process exit code: $LASTEXITCODE" | Out-File -FilePath (Join-Path $tmp 'sched-error.txt') -Encoding UTF8
                throw "Scheduler child-process failed with exit code $LASTEXITCODE"
            }
        } catch {
            $_ | Out-File -FilePath (Join-Path $tmp 'sched-error.txt') -Encoding UTF8
            throw
        }

        # Dump directory listing for debugging when run under Pester
        Get-ChildItem -Path $tmp -Recurse | Out-File -FilePath (Join-Path $tmp 'debug-listing.txt') -Encoding UTF8

        Test-Path $outFile | Should -BeTrue
        $proposal = Get-Content $outFile -Raw | ConvertFrom-Json

        $proposal.Generated | Should -Not -BeNullOrEmpty
        $parsedOk = $false
        try { $dt = [datetime]$proposal.Generated; $parsedOk = $true } catch { $parsedOk = $false }
        $parsedOk | Should -BeTrue
        $proposal.Agents | Should -Not -BeNullOrEmpty

        foreach ($a in $proposal.Agents) {
            ($a.Name -is [string]) | Should -BeTrue
            (([int]$a.CapacityPoints) -ge 0) | Should -BeTrue
            (([int]$a.AssignedPoints) -ge 0) | Should -BeTrue
            $assigns = @($a.Assignments)
            ($assigns -is [System.Array]) | Should -BeTrue
        }

        Remove-Item -Path $tmp -Recurse -Force
        } catch {
            $err = $_
            $sb = [System.Text.StringBuilder]::new()
            $sb.AppendLine("Exception Time: $(Get-Date -Format o)") | Out-Null
            $sb.AppendLine('--- Exception.ToString() ---') | Out-Null
            $sb.AppendLine($err.ToString()) | Out-Null
            $sb.AppendLine('--- ErrorRecord ---') | Out-Null
            $sb.AppendLine(($err.ErrorRecord | Format-List * -Force | Out-String)) | Out-Null
            $sb.AppendLine('--- Exception Details ---') | Out-Null
            $sb.AppendLine(($err.Exception | Format-List * -Force | Out-String)) | Out-Null
            $sb.AppendLine('--- Recent $error array ---') | Out-Null
            $sb.AppendLine(($error | Select-Object -First 10 | Format-List * | Out-String)) | Out-Null
            $sb.ToString() | Out-File -FilePath $exceptionFile -Encoding UTF8
            throw
        }
    }
}
