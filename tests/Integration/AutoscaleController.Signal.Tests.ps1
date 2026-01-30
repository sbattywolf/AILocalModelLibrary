Describe 'Autoscale controller signaling' {
    It 'writes suggestion and apply request when --apply --signal used and change forced' {
        $py = (Get-Command python -ErrorAction SilentlyContinue).Path
        if (-not $py) { $py = (Get-Command py -ErrorAction SilentlyContinue).Path }
        if (-not $py) { $py = (Get-Command python3 -ErrorAction SilentlyContinue).Path }
        if (-not $py) { Throw 'No Python executable found on PATH for autoscale test' }

        $suggestion = '.continue\autoscale-suggestion.json'
        $request = '.continue\autoscale-apply.request'
        if (Test-Path $suggestion) { Remove-Item $suggestion -Force }
        if (Test-Path $request) { Remove-Item $request -Force }

        $script = 'scripts\\autoscale_controller.py'
        # force change detection by setting AUTOSCALE_CHANGE_PCT=0
        $env:AUTOSCALE_CHANGE_PCT = '0'
        $out = & $py $script --available-vram 24 --apply --signal

        Test-Path $suggestion | Should -BeTrue
        Test-Path $request | Should -BeTrue

        $s = Get-Content $suggestion -Raw | ConvertFrom-Json
        $r = Get-Content $request -Raw | ConvertFrom-Json
        $s.recommendation | Should -Not -BeNullOrEmpty
        $r.action | Should -Be 'apply_suggestion'

        Remove-Item $suggestion -Force
        Remove-Item $request -Force
    }
}
