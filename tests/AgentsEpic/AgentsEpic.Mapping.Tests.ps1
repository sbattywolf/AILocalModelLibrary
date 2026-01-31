Describe 'Agents Epic Mapping' {

    It 'Has a mapping file with agents' {
        Import-Module (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.psm1')).Path -Force
        $path = '.continue/agents-epic.json'
        Test-Path $path | Should -BeTrue
        $agents = Load-JsonDefensive $path
        $agents.Count | Should -BeGreaterThan 0
    }

    It 'Selects candidate agents for a random probe question' {
        Import-Module (Resolve-Path (Join-Path $PSScriptRoot '..\TestHelpers.psm1')).Path -Force
        $mapping = Load-JsonDefensive '.continue/agents-epic.json'
        $questions = @(
            'Write a unit test for a sorting function',
            'Optimize a function for lower memory',
            'Generate a code example for OAuth flow',
            'Explain how to containerize a Python app'
        )
        $probe = Get-Random $questions

        # Heuristic: prefer agents whose model name hints at code/coder/codellama/starcoder
        $candidates = $mapping | Where-Object { $_.model -match 'code|coder|codellama|starcoder|qwen' }
        if (-not $candidates -or $candidates.Count -eq 0) { $candidates = $mapping }

        # Assert we found at least one candidate
        $candidates.Count | Should -BeGreaterThan 0

        # Output selection for debugging/inspection
        $selection = $candidates | ForEach-Object { "{0}:{1}" -f $_.name, $_.model }
        Write-Output "Probe: $probe"
        Write-Output "Selected candidates:`n$($selection -join "`n")"
    }

    It 'Probes running agent entries in isolated environment (no ollama)' {
        $mapping = Get-Content '.continue/agents-epic.json' -Raw | ConvertFrom-Json
        # detect ollama dir to remove from PATH for isolation
        $ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
        $origPath = $env:PATH
        $removeDir = $null
        if ($ollamaCmd) { $removeDir = Split-Path $ollamaCmd.Path -Parent }

        $pythonExe = (Get-Command python -ErrorAction SilentlyContinue).Path
        if (-not $pythonExe) { $pythonExe = (Get-Command py -ErrorAction SilentlyContinue).Path }
        if (-not $pythonExe) { $pythonExe = (Get-Command python3 -ErrorAction SilentlyContinue).Path }
        foreach ($a in $mapping) {
            $entry = $a.entry
            $name = $a.name
            $probe = "Test probe for $name"

            if (-not $entry) { Write-Warning "No entry for $name; skipping probe"; continue }

            if ($removeDir) {
                # build PATH without ollama dir
                $parts = $origPath -split ';' | Where-Object { $_ -and ($_ -ne $removeDir) }
                $newPath = ($parts -join ';')
            } else {
                $newPath = $origPath
            }


            if ($entry -match '\.py$') {
                if (-not $pythonExe) { Write-Warning "Skipping python agent $name - python not found"; continue }
                $cmd = "& { `$env:OLLAMA_DISABLED = '1'; & '$pythonExe' '$entry' --prompt '$probe' --agent '$name' }"
            } else {
                $cmd = "& { `$env:OLLAMA_DISABLED = '1'; & '$entry' -Prompt '$probe' -Agent '$name' }"
            }

            $out = & powershell -NoProfile -ExecutionPolicy Bypass -Command $cmd
            # normalize output and parse JSON
            try {
                $json = $out | Out-String | ConvertFrom-Json -ErrorAction Stop
            } catch {
                Throw "Failed to parse JSON from agent $name. Raw output:`n$out"
            }

            # basic assertions
            $json.ok | Should -BeTrue

            # Agent name in response is ideal but not fatal; warn if mismatch
            if ($json.PSObject.Properties.Name -contains 'agent') {
                if ($json.agent -ne $name) { Write-Warning "Agent name mismatch: expected $name but agent returned $($json.agent)" }
            } else { Write-Warning "No 'agent' property in response from $name; raw output:`n$out" }

            # Prompt should echo back; warn if missing
            if (-not ($json.prompt -match 'Test probe for')) { Write-Warning "Prompt not reflected for $name" }
        }
    }

    It 'Measures agent latency under isolated conditions' {
        $mapping = Get-Content '.continue/agents-epic.json' -Raw | ConvertFrom-Json
        $maxLatencySeconds = 5

        $pythonExe = (Get-Command python -ErrorAction SilentlyContinue).Path
        if (-not $pythonExe) { $pythonExe = (Get-Command py -ErrorAction SilentlyContinue).Path }
        if (-not $pythonExe) { $pythonExe = (Get-Command python3 -ErrorAction SilentlyContinue).Path }

        foreach ($a in $mapping) {
            $entry = $a.entry
            $name = $a.name
            $probe = "Latency probe for $name"

            if (-not $entry) { Write-Warning "No entry for $name; skipping latency probe"; continue }

            if ($entry -match '\.py$') {
                if (-not $pythonExe) { Write-Warning "Skipping python agent $name - python not found"; continue }
                $cmd = "& { `$env:OLLAMA_DISABLED = '1'; & '$pythonExe' '$entry' --prompt '$probe' --agent '$name' }"
            } else {
                $cmd = "& { `$env:OLLAMA_DISABLED = '1'; & '$entry' -Prompt '$probe' -Agent '$name' }"
            }

            $sw = [Diagnostics.Stopwatch]::StartNew()
            $out = & powershell -NoProfile -ExecutionPolicy Bypass -Command $cmd
            $sw.Stop()
            $elapsed = $sw.Elapsed.TotalSeconds

            $elapsed | Should -BeLessThan ($maxLatencySeconds + 0.001)

            try { $json = $out | Out-String | ConvertFrom-Json -ErrorAction Stop } catch { Throw "Failed to parse JSON from agent $name. Raw output:`n$out" }
            $json.ok | Should -BeTrue
        }
    }

    It 'Ollama integration test for one agent (gated by RUN_OLLAMA_INTEGRATION=1)' {
        if ($env:RUN_OLLAMA_INTEGRATION -ne '1') { Write-Warning "RUN_OLLAMA_INTEGRATION not set; skipping integration test."; return }
        if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) { Write-Warning "ollama not available; skipping integration test."; return }

        $agentName = 'CustomAgent'
        $probe = 'Integration probe for Ollama'
        $entry = (Get-Content '.continue/agents-epic.json' -Raw | ConvertFrom-Json | Where-Object { $_.name -eq $agentName }).entry
        if (-not $entry) { Throw "Agent entry for $agentName not found in mapping" }

        $cmd = "& { & '$entry' -Prompt '$probe' -Agent '$agentName' }"
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -Command $cmd
        try { $json = $out | Out-String | ConvertFrom-Json -ErrorAction Stop } catch { Throw "Failed to parse JSON from agent $agentName. Raw output:`n$out" }

        $json.ok | Should -BeTrue
        $json.agent | Should -Be $agentName
        $json.response | Should -Not -BeNullOrEmpty
    }
}
