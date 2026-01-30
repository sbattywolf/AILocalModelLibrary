# Minimal local-llama runner
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$configPath = Join-Path $scriptDir 'config.json'
if (-not (Test-Path $configPath)) { Write-Error "Missing config.json at $configPath"; exit 2 }
$config = Get-Content $configPath -Raw | ConvertFrom-Json
# If a per-machine session file exists, prefer its model path
$sessionFile = '.private/local-llama-session.json'
if (Test-Path $sessionFile) {
	try {
		$session = Get-Content $sessionFile -Raw | ConvertFrom-Json -ErrorAction Stop
		if ($session.model -and $session.model.path) {
			$config.model_path = $session.model.path
			Write-Host ("Using session model path from {0}:" -f $sessionFile) $session.model.path
		}
	} catch { Write-Host "Warning: failed to read session file: $_" }
}
$cmd = $env:LOCAL_LLM_CMD
if (-not $cmd) { $cmd = 'llama-cli' }

$modelPath = $config.model_path -as [string]
$args = @()
if ($modelPath) { $args += @('--model', $modelPath) }
if ($config.prompt) { $prompt = $config.prompt } else { $prompt = 'You are an assistant.' }

Write-Host "Running local LLM via $cmd"
if ($prompt) { $prompt | & $cmd @args } else { & $cmd @args }
