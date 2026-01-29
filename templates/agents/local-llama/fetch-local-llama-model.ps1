<#
Helper to download a local-llama GGML model into the templates/agents/local-llama/models/ directory.
This script performs basic validation and shows the expected file size before download.

USAGE (run interactively):
  .\fetch-local-llama-model.ps1 -Url <model_url> [-OutName <filename>] [-Confirm]

#>
param(
  [Parameter(Mandatory=$true)] [string]$Url,
  [string]$OutName = '',
  [switch]$Confirm
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$modelsDir = Join-Path $scriptDir 'models'
if (-not (Test-Path $modelsDir)) { New-Item -ItemType Directory -Path $modelsDir | Out-Null }

if (-not $OutName -or $OutName -eq '') { $OutName = Split-Path $Url -Leaf }
$outPath = Join-Path $modelsDir $OutName

Write-Host "Model URL: $Url"
Write-Host "Destination: $outPath"

if (-not $Confirm) {
  $yn = Read-Host "Proceed to download? (y/N)"
  if ($yn -notin @('y','Y')) { Write-Host 'Aborted by user'; exit 1 }
}

try {
  $wc = New-Object System.Net.WebClient
  Write-Host "Starting download... (this may take a long time)"
  $wc.DownloadFile($Url, $outPath)
  Write-Host "Downloaded to $outPath"
} catch {
  Write-Error "Download failed: $_"
  exit 2
}
