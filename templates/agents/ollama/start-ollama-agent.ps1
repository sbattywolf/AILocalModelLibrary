<#
Simple Ollama agent runner (PS5.1-safe)
Reads `config.json` for model name and prompt, then calls `ollama run`.
#>

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$configPath = Join-Path $scriptDir 'config.json'
if (-not (Test-Path $configPath)) { Write-Error "Missing config.json at $configPath"; exit 2 }

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$model = $config.model -as [string]
$prompt = $config.prompt -as [string]
if (-not $model) { Write-Error 'No model specified in config.json'; exit 2 }

Write-Host "Running Ollama model: $model"
$ollamaExe = 'ollama'
# Allow override via env
if ($env:OLLAMA_CMD) { $ollamaExe = $env:OLLAMA_CMD }

# Build arguments
$cliArgs = @('run', $model, '--interactive')

# If prompt provided, pass as stdin
if ($prompt) {
  $prompt | & $ollamaExe @cliArgs
} else {
  & $ollamaExe @cliArgs
}
