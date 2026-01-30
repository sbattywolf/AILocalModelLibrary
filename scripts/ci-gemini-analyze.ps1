Param(
    [Parameter(Mandatory=$false)][string]$LogFile = 'test-output.txt',
    [Parameter(Mandatory=$false)][string]$OutputDir = '.continue/analysis'
)

Set-StrictMode -Version Latest

if (-not (Test-Path $LogFile)) {
    Write-Error "Log file not found: $LogFile"
    exit 2
}

if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

$commit = $env:GITHUB_SHA
if (-not $commit) { $commit = (Get-Date).ToString('yyyyMMdd-HHmmss') }

$outPath = Join-Path $OutputDir "$commit-analysis.json"

# Placeholder: if GEMINI_API_KEY is set, you can call the Gemini API here.
# Example (pseudo):
# $apiKey = $env:GEMINI_API_KEY
# $payload = @{ prompt = Get-Content $LogFile -Raw }
# Invoke-RestMethod -Uri 'https://api.gemini.example/analyze' -Method Post -Headers @{ 'Authorization' = "Bearer $apiKey" } -Body ($payload | ConvertTo-Json)

# If no API key, produce a safe suggestion stub that includes an excerpt of the log.
$logSnippet = Get-Content -Path $LogFile -Raw -ErrorAction SilentlyContinue
$snippet = if ($logSnippet.Length -gt 2000) { $logSnippet.Substring(0,2000) + '... (truncated)' } else { $logSnippet }

$analysis = [ordered]@{
    commit = $commit
    timestamp = (Get-Date).ToString('o')
    tool = 'gemini-stub'
    suggestion = "Automated suggestion placeholder. Replace with real Gemini API call by setting GEMINI_API_KEY and updating this script."
    log_excerpt = $snippet
    diff = $null
}

$analysis | ConvertTo-Json -Depth 5 | Set-Content -Path $outPath -Encoding UTF8
Write-Output "Wrote analysis stub to: $outPath"
exit 0
