<#
Validate local-llama model presence and report size / memory estimate.
Usage: .\scripts\validate-local-llama-model.ps1 [-ModelPath <path>]
#>
param(
  [string]$ModelPath = 'templates/agents/local-llama/models/llama-13b-q4_0.ggml'
)

function BytesToGB($b) { return [math]::Round($b / 1GB, 2) }

if (-not (Test-Path $ModelPath)) {
  Write-Host "Model not found at: $ModelPath"
  Write-Host "Use templates/agents/local-llama/fetch-local-llama-model.ps1 to download into templates/agents/local-llama/models/"
  Write-Host "Example: .\templates\agents\local-llama\fetch-local-llama-model.ps1 -Url '<model-URL>' -Confirm"
  exit 1
}

$fi = Get-Item $ModelPath
$size = $fi.Length
Write-Host "Model file: $ModelPath" -ForegroundColor Green
Write-Host "Size: $($size) bytes ($([math]::Round($size/1GB,2)) GB)"

# Approximate memory footprint guidance by quantization family (heuristic)
$estimates = @{
  'q4_0' = 20..30
  'q4_K_M' = 18..28
  'q8' = 30..40
}

$name = Split-Path $ModelPath -Leaf
$matched = $null
foreach ($k in $estimates.Keys) { if ($name -match $k) { $matched = $k; break } }
if ($matched) {
  $range = $estimates[$matched]
  Write-Host "Estimated RAM for running (quantization=$matched): ~${($range[0])}GB to ${($range[1])}GB depending on batch/context" -ForegroundColor Yellow
} else {
  Write-Host "No quantization tag matched; estimate RAM roughly = model size * 2 (approx)." -ForegroundColor Yellow
  $approx = [math]::Round($size * 2 / 1GB,2)
  Write-Host "Approx RAM estimate: ${approx}GB"
}

Write-Host "If you want Ollama to host models, use -UseOllama and optionally run 'ollama pull <model>' or set -PullToOllama when starting the agent." -ForegroundColor Cyan
exit 0
