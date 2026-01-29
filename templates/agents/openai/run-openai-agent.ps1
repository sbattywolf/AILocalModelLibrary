<#
Minimal OpenAI API runner (PS5.1)
#>
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$configPath = Join-Path $scriptDir 'config.json'
if (-not (Test-Path $configPath)) { Write-Error "Missing config.json at $configPath"; exit 2 }
$config = Get-Content $configPath -Raw | ConvertFrom-Json
$model = $config.model -as [string]
$prompt = $config.prompt -as [string]
if (-not $model) { Write-Error 'No model specified in config.json'; exit 2 }

$apiKey = $env:OPENAI_API_KEY
if (-not $apiKey) { Write-Error 'OPENAI_API_KEY is not set in environment'; exit 2 }

$body = @{model=$model; prompt=$prompt; max_tokens=256} | ConvertTo-Json
$headers = @{ Authorization = "Bearer $apiKey"; 'Content-Type' = 'application/json' }

$response = Invoke-RestMethod -Uri 'https://api.openai.com/v1/completions' -Method Post -Headers $headers -Body $body -ErrorAction Stop
Write-Host ($response.choices[0].text -join "`n")
