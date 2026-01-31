Param(
    [Parameter(Mandatory=$true)][string]$SuggestionFile
)

Set-StrictMode -Version Latest

if (-not (Test-Path $SuggestionFile)) { Write-Error "Suggestion file not found: $SuggestionFile"; exit 2 }

$json = Get-Content -Path $SuggestionFile -Raw | ConvertFrom-Json

# Expecting fields: suggestion (text), diff (unified diff optional)
$diff = $json.diff

if (-not $diff) {
    Write-Output "No diff field in suggestion. Writing suggestion text to .continue/analysis/suggestion.txt"
    $outText = Join-Path (Split-Path $SuggestionFile) 'suggestion.txt'
    $json.suggestion | Out-File -FilePath $outText -Encoding UTF8
    Write-Output "Wrote suggestion text to: $outText"
    exit 0
}

# Apply unified diff safely: write to temp patch and validate
$patchPath = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString() + '.patch')
$diff | Out-File -FilePath $patchPath -Encoding UTF8

Write-Output "Checking patch applicability"
try {
    git apply --check $patchPath 2>&1 | Out-Null
} catch {
    Write-Error "Patch failed --check. Aborting. See $patchPath"
    exit 3
}

Write-Output "Applying patch"
try {
    git apply $patchPath
} catch {
    Write-Error "Failed to apply patch"
    exit 4
}

Write-Output "Running tests locally"
Start-Transcript -Path (Join-Path $env:TEMP 'aider-test-output.txt') -Force
Import-Module Pester -ErrorAction Stop
try {
    Invoke-Pester -Script tests -EnableExit
    $testsPassed = $true
} catch {
    $testsPassed = $false
}
Stop-Transcript

if ($testsPassed) {
    Write-Output "Tests passed after applying suggestion. Committing and pushing."
    git add -A
    git commit -m "Apply suggested fix from analysis: $SuggestionFile" || Write-Output "No changes to commit or commit failed."
    git push || Write-Output "Push failed; please push manually."
    exit 0
} else {
    Write-Output "Tests failed after applying suggestion. Reverting patch."
    try { git apply -R $patchPath } catch { Write-Error "Failed to revert patch; you may need to reset manually." }
    exit 5
}
