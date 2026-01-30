param(
    [string]$Prompt,
    [string]$Agent
)

# Minimal local agent runner with agent selection
# Usage:
#   ./.continue/agent-runner.ps1 -Agent CustomAgent -Prompt "Hello"
#   echo "Hello" | ./.continue/agent-runner.ps1 -Agent TurboAgent

if (-not $Prompt) {
    try { $stdin = [Console]::In.ReadToEnd(); if ($stdin) { $Prompt = $stdin.Trim() } } catch { }
}

if (-not $Prompt) { Write-Error 'No prompt provided.'; exit 2 }

# Load agent configs
$cfgPath = Join-Path (Get-Location) '.continue\config.agent'
if (-not (Test-Path $cfgPath)) { Write-Warning "Missing config.agent at $cfgPath; using echo response." }
else {
    try { $cfg = Get-Content -Path $cfgPath -Raw | ConvertFrom-Json } catch { $cfg = $null }
}

if (-not $Agent) {
    # Prefer selected_agent.txt if present, otherwise default from config
    $selPath = Join-Path (Get-Location) '.continue\selected_agent.txt'
    if (Test-Path $selPath) { $Agent = (Get-Content $selPath -ErrorAction SilentlyContinue).Trim() }
    if (-not $Agent) { $Agent = if ($cfg -and $cfg.default) { $cfg.default } else { 'CustomAgent' } }
}

# Resolve selected agent
$selected = $null
if ($cfg -and $cfg.agents) { $selected = $cfg.agents | Where-Object { $_.name -eq $Agent } | Select-Object -First 1 }

if (-not $selected) {
    $selected = [PSCustomObject]@{ name = 'echo'; options = @{ model = 'none'; mode = 'echo' } }
}

# If a model is configured and ollama is available, try to run the model
 $model = $null
 if ($selected.options -and $selected.options.model) { $model = $selected.options.model }
 $llmOutput = $null
 $ollamaAvailable = $false
 if ($env:OLLAMA_DISABLED -ne '1') { if (Get-Command ollama -ErrorAction SilentlyContinue) { $ollamaAvailable = $true } }
 if ($model -and $model -ne 'none' -and $ollamaAvailable) {
    try {
        # Helper to strip ANSI/TTY control sequences
        function Remove-Ansi {
            param([string]$s)
            if (-not $s) { return $s }
            try {
                $clean = [regex]::Replace($s, '\x1b\[[0-9;?]*[ -/]*[@-~]', '')
                $clean = $clean -replace "\r", ''
                return $clean.Trim()
            } catch { return $s }
        }

        # Non-interactive terminal to reduce spinner/TTY sequences
        $oldTerm = $env:TERM
        $env:TERM = 'dumb'

        $cmd = @('run', $model, $Prompt)
        # Use Start-Process with redirected files and read with UTF8 to avoid codepage/encoding mojibake
        $tmpOut = [System.IO.Path]::GetTempFileName()
        $tmpErr = [System.IO.Path]::GetTempFileName()
        try {
            $proc = Start-Process -FilePath 'ollama' -ArgumentList $cmd -NoNewWindow -RedirectStandardOutput $tmpOut -RedirectStandardError $tmpErr -Wait -PassThru
            $outRaw = Get-Content -Raw -Encoding UTF8 -Path $tmpOut -ErrorAction SilentlyContinue
            $errRaw = Get-Content -Raw -Encoding UTF8 -Path $tmpErr -ErrorAction SilentlyContinue
            $raw = ($outRaw + "`r`n" + $errRaw).Trim()
            $exitCode = $proc.ExitCode
        } finally {
            Remove-Item $tmpOut,$tmpErr -ErrorAction SilentlyContinue
        }

        # restore TERM
        if ($null -ne $oldTerm) { $env:TERM = $oldTerm } else { Remove-Item Env:TERM -ErrorAction SilentlyContinue }

        $clean = Remove-Ansi $raw
        # Remove braille/spinner glyphs and other stray non-printables introduced by interactive spinners
        $clean = $clean -replace '[\u2800-\u28FF]', ''
        $clean = $clean -replace '[\p{C}]', ''
        if ($clean) { $llmOutput = $clean } else { $llmOutput = $raw }

        $llmResult = [PSCustomObject]@{
            raw = ($raw -join "")
            cleaned = $llmOutput
            exitCode = $exitCode
        }
    } catch {
        $llmOutput = $null
        $llmResult = [PSCustomObject]@{ raw = $_.ToString(); cleaned = ''; exitCode = 1 }
    }
}

if (-not $llmOutput) {
    $llmOutput = "[$($selected.name)] Echo: $Prompt"
    $llmResult = [PSCustomObject]@{ raw = $llmOutput; cleaned = $llmOutput; exitCode = 0 }
}

$resp = [PSCustomObject]@{
    agent = $selected.name
    options = $selected.options
    prompt = $Prompt
    response = $llmResult.cleaned
    rawResponse = $llmResult.raw
    ok = ($llmResult.exitCode -eq 0)
    exitCode = $llmResult.exitCode
    timestamp = (Get-Date).ToString('o')
}

$resp | ConvertTo-Json -Depth 6
