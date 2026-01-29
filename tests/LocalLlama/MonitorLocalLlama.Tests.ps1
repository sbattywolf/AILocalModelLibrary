Describe 'LocalLlama Monitor' {
    It 'monitor-local-llama captures samples for a running PID (using stub)' {
        $env:LOCAL_LLM_CMD = (Resolve-Path .\sandbox\local-llama-test\llama-cli.ps1)
        $mapFile = '.\.continue\local-llama-processes.json'
        if (Test-Path $mapFile) { Remove-Item $mapFile -Force }

        # start a short stub process
        .\scripts\start-local-llama-role.ps1 -Role monitor-unit -Action run -Model unit-model -LocalCmd $env:LOCAL_LLM_CMD
        Start-Sleep -Milliseconds 200

        # run monitor for 2 samples
        .\scripts\monitor-local-llama.ps1 -SampleIntervalSeconds 1 -SampleCount 2

        $outJson = '.\.continue\local-llama-monitor.json'
        $exists = Test-Path $outJson
        $exists | Should -Be $true

        # cleanup
        .\scripts\stop-local-llama-role.ps1 -Role monitor-unit
    }
}
