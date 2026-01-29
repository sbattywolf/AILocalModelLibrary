# Minimal local-llama runner
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$configPath = Join-Path $scriptDir 'config.json'
if (-not (Test-Path $configPath)) { Write-Error "Missing config.json at $configPath"; exit 2 }
$config = Get-Content $configPath -Raw | ConvertFrom-Json
$cmd = $env:LOCAL_LLM_CMD
if (-not $cmd) { $cmd = 'llama-cli' }

$modelPath = $config.model_path -as [string]
$args = @()
if ($modelPath) { $args += @('--model', $modelPath) }
if ($config.prompt) { $prompt = $config.prompt } else { $prompt = 'You are an assistant.' }

Write-Host "Running local LLM via $cmd"
if ($prompt) { $prompt | & $cmd @args } else { & $cmd @args }
