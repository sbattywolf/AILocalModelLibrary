Describe 'LocalLlama Start/Stop' {
    It 'start-local-llama-role appends mapping when starting run (DryRun stub)' {
        # Use the sandbox stub
        $env:LOCAL_LLM_CMD = (Resolve-Path .\sandbox\local-llama-test\llama-cli.ps1)
        $mapFile = '.\.continue\local-llama-processes.json'
        if (Test-Path $mapFile) { Remove-Item $mapFile -Force }

        # Start agent
        .\scripts\start-local-llama-role.ps1 -Role test-unit -Action run -Model unit-model -LocalCmd $env:LOCAL_LLM_CMD
        Start-Sleep -Milliseconds 200
        $raw = Get-Content -Path $mapFile -Raw
        $map = $raw | ConvertFrom-Json
        $map.Role | Should -Contain 'test-unit'

        # Stop agent
        .\scripts\stop-local-llama-role.ps1 -Role test-unit
        Start-Sleep -Milliseconds 200
        $raw2 = Get-Content -Path $mapFile -Raw
        $new = $raw2 | ConvertFrom-Json
        # ensure removed
        ($new | Where-Object { $_.Role -eq 'test-unit' }) | Should -Be $null
    }
}
