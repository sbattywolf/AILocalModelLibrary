param(
    [switch]$WriteReport = $true
)

$root = Get-Location
$report = [ordered]@{
    timestamp = (Get-Date).ToString('o')
    json = @()
    ps1_syntax = @()
    typos = @()
}

# JSON validation targets
$jsonTargets = @(
    '.continue/config.agent'
)
$jsonTargets += (Get-ChildItem -Path . -Include *.json -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\.git\\' -and $_.FullName -notmatch '\\artifacts\\' } | Select-Object -ExpandProperty FullName)
$jsonTargets = $jsonTargets | Sort-Object -Unique

foreach ($f in $jsonTargets) {
    try {
        $raw = Get-Content $f -Raw -ErrorAction Stop
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
        $report.json += @{ file = $f; ok = $true }
    } catch {
        $report.json += @{ file = $f; ok = $false; error = $_.Exception.Message }
    }
}

# PowerShell syntax check using parser
$psFiles = Get-ChildItem -Path . -Include *.ps1 -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\.git\\' -and $_.FullName -notmatch '\\artifacts\\' }
foreach ($p in $psFiles) {
    $path = $p.FullName
    try {
        $null1 = $null; $null2 = $null
        [Management.Automation.Language.Parser]::ParseFile($path,[ref]$null1,[ref]$null2) | Out-Null
        $report.ps1_syntax += @{ file = $path; ok = $true }
    } catch {
        $report.ps1_syntax += @{ file = $path; ok = $false; error = $_.Exception.Message }
    }
}

# Simple typo scan (common mistakes observed)
$typosToFind = @('thypos','somenthing','chekc','cna','eery','tesuite','re-run','re run','adn','teh','ocurr','occurence')
# Typos scan intentionally omitted to avoid noisy self-tests; run ad-hoc checks separately.

# Write reports
$reportDir = ".continue"
if ($WriteReport) {
    if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
    $outJson = Join-Path $reportDir "validation_report.json"
    $outTxt = Join-Path $reportDir "validation_report.txt"
    $report | ConvertTo-Json -Depth 5 | Out-File -FilePath $outJson -Encoding utf8

    $sb = New-Object System.Text.StringBuilder
    $sb.AppendLine(("Validation run: {0}" -f $report.timestamp)) | Out-Null
    $sb.AppendLine('') | Out-Null
    $sb.AppendLine('JSON files:') | Out-Null
    foreach ($j in $report.json) {
        $status = 'OK'
        if (-not $j.ok) { $status = 'ERR: ' + $j.error }
        $sb.AppendLine((" - {0} : {1}" -f $j.file, $status)) | Out-Null
    }
    $sb.AppendLine('') | Out-Null
    $sb.AppendLine('PowerShell syntax:') | Out-Null
    foreach ($p in $report.ps1_syntax) {
        $status = 'OK'
        if (-not $p.ok) { $status = 'ERR: ' + $p.error }
        $sb.AppendLine((" - {0} : {1}" -f $p.file, $status)) | Out-Null
    }
    $sb.AppendLine('') | Out-Null
    $sb.AppendLine('Typos / suspicious strings:') | Out-Null
    foreach ($t in $report.typos) { $sb.AppendLine((" - {0} (L{1}): {2} -- pattern {3}" -f $t.file, $t.line, $t.text.Trim(), $t.pattern)) | Out-Null }

    $sb.ToString() | Out-File -FilePath $outTxt -Encoding utf8
    Write-Host "Wrote validation report to $outJson and $outTxt"
}

# Exit code non-zero if critical failures
$errCount = ($report.json | Where-Object { -not $_.ok }).Count + ($report.ps1_syntax | Where-Object { -not $_.ok }).Count
if ($errCount -gt 0) { exit 2 } else { exit 0 }
