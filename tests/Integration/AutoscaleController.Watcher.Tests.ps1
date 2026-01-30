Describe 'Autoscale controller watch/once behavior' {
    It 'runs once and writes suggestion file when --apply used' {
        $py = (Get-Command python -ErrorAction SilentlyContinue).Path
        if (-not $py) { $py = (Get-Command py -ErrorAction SilentlyContinue).Path }
        if (-not $py) { $py = (Get-Command python3 -ErrorAction SilentlyContinue).Path }
        if (-not $py) { Throw 'No Python executable found on PATH for autoscale test' }

        $suggestion = '.continue\autoscale-suggestion.json'
        if (Test-Path $suggestion) { Remove-Item $suggestion -Force }

        $script = 'scripts\\autoscale_controller.py'
        $out = & $py $script --available-vram 24 --apply
        # expect file written
        Test-Path $suggestion | Should -BeTrue

        $json = Get-Content $suggestion -Raw | ConvertFrom-Json
        $json.recommendation | Should -Not -BeNullOrEmpty
        $json.available_vram_gb | Should -Be 24

        # cleanup
        Remove-Item $suggestion -Force
    }
}
