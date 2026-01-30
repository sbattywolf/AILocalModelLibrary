Describe 'Monitor Background Smoke' {
    It 'runs once and writes skill-suggestions.json' {
        $repoRoot = Split-Path -Path $PSScriptRoot -Parent
        $monitor = Join-Path $repoRoot 'scripts\monitor-background.ps1'
        $suggestions = Join-Path $repoRoot '.continue\skill-suggestions.json'

        if (Test-Path $suggestions) { Remove-Item -Force -Path $suggestions }

        # Run the monitor script in DryRun Once mode
        & $monitor -DryRun -Once | Out-Null

        # Assert suggestions file exists and dashboard produced
        Test-Path $suggestions | Should -BeTrue
        $dashboard = Join-Path $repoRoot '.continue\monitor-dashboard.md'
        Test-Path $dashboard | Should -BeTrue

        # Load via helper to validate JSON
        Import-Module (Join-Path $repoRoot 'tests\TestHelpers.psm1') -Force | Out-Null
        $obj = Test-LoadJson -Path $suggestions
        $obj | Should -Not -BeNullOrEmpty
        $obj.PSObject.Properties.Name | Should -Contain 'timestamp'

        # Dashboard contains Top Skills section
        $content = Get-Content -Raw -Path $dashboard
        $content | Should -Match 'Top Skills'
    }
}
