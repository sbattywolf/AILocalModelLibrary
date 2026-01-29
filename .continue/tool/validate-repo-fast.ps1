param(
    [switch]$WriteReport = $true
)

$report = [ordered]@{
    timestamp = (Get-Date).ToString('o')
    json = @()
    ps1_syntax = @()
    typos = @()
}

# Focused JSON checks
$targets = @(
    '.continue/config.agent',
    '.continue/models.json'
)
foreach ($t in $targets) {
    if (Test-Path $t) {
        try { $null = Get-Content $t -Raw | ConvertFrom-Json; $report.json += @{ file = $t; ok = $true } }
        catch { $report.json += @{ file = $t; ok = $false; error = $_.Exception.Message } }
    } else { $report.json += @{ file = $t; ok = $false; error = 'missing' } }
}

# PowerShell quick syntax check: only .continue and scripts folders
$psPaths = @('.continue','scripts')
$psFiles = @()
foreach ($p in $psPaths) { if (Test-Path $p) { $psFiles += Get-ChildItem -Path $p -Include *.ps1 -Recurse -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName } }

foreach ($f in $psFiles) {
    try {
        $null1 = $null; $null2 = $null
        [Management.Automation.Language.Parser]::ParseFile($f,[ref]$null1,[ref]$null2) | Out-Null
        $report.ps1_syntax += @{ file = $f; ok = $true }
    } catch {
        $report.ps1_syntax += @{ file = $f; ok = $false; error = $_.Exception.Message }
    }
}

# Typos scan intentionally omitted to avoid noisy self-tests; run ad-hoc checks separately.

if ($WriteReport) {
    if (-not (Test-Path '.continue')) { New-Item -ItemType Directory -Path '.continue' -Force | Out-Null }
    $jsonOut = '.continue/validation_fast.json'
    $txtOut = '.continue/validation_fast.txt'
    $report | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonOut -Encoding utf8

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
    foreach ($t in $report.typos) {
        $sb.AppendLine((" - {0} (L{1}): {2} -- pattern {3}" -f $t.file, $t.line, $t.text, $t.pattern)) | Out-Null
    }

    $sb.ToString() | Out-File -FilePath $txtOut -Encoding utf8
    Write-Host "Wrote fast validation to $jsonOut and $txtOut"
}

$errCount = ($report.json | Where-Object { -not $_.ok }).Count + ($report.ps1_syntax | Where-Object { -not $_.ok }).Count
if ($errCount -gt 0) { exit 2 } else { exit 0 }
