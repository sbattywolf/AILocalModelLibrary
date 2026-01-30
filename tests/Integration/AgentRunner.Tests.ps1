Describe 'Agent Runner integration (CI-friendly)' {

    It 'returns ok and echoes prompt in CI/no runtime mode' {
        $script = '.\\.continue\\python\\agent_runner.py'
        $prompt = 'CI probe test'

        # Ensure isolation: force echo path
        $env:OLLAMA_DISABLED = '1'

        # find a python executable on PATH (try python, py, python3)
        $py = (Get-Command python -ErrorAction SilentlyContinue).Path
        if (-not $py) { $py = (Get-Command py -ErrorAction SilentlyContinue).Path }
        if (-not $py) { $py = (Get-Command python3 -ErrorAction SilentlyContinue).Path }
        if (-not $py) { Throw 'No Python executable found on PATH for test' }

        $cmd = "& '$py' $script --agent Low-1 --prompt '$prompt'"
        $out = Invoke-Expression $cmd
        try {
            $json = $out | Out-String | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Throw "Failed to parse JSON from agent_runner output: $out"
        }

        $json.ok | Should -BeTrue
        # agent may be 'Low-1' or fallback 'echo' depending on environment; accept either
        ($json.agent -in @('Low-1','echo')) | Should -BeTrue
        $json.response | Should -Match $prompt
    }
}
