Describe 'Autoscale controller prototype' {
    It 'returns a JSON recommendation' {
        $py = (Get-Command python -ErrorAction SilentlyContinue).Path
        if (-not $py) { $py = (Get-Command py -ErrorAction SilentlyContinue).Path }
        if (-not $py) { $py = (Get-Command python3 -ErrorAction SilentlyContinue).Path }
        if (-not $py) { Throw 'No Python executable found on PATH for autoscale test' }

        $script = 'scripts\\autoscale_controller.py'
        $out = & $py $script --available-vram 24
        try { $json = $out | Out-String | ConvertFrom-Json -ErrorAction Stop } catch { Throw "Failed to parse JSON: $out" }

        $json.recommendation | Should -Not -BeNullOrEmpty
        ($json.recommendation.MaxParallel -ge 1) | Should -BeTrue
        $json.recommendation.MaxVramGB | Should -Be 24
    }
}
