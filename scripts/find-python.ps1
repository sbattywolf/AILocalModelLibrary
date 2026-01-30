# Search common locations for python.exe on Windows
$roots = @(
    "C:\\",
    "C:\\Program Files\\",
    "C:\\Program Files (x86)\\",
    "$env:LOCALAPPDATA\\Programs\\",
    "$env:USERPROFILE\\AppData\\Local\\Programs\\",
    "$env:USERPROFILE\\AppData\\Local\\Microsoft\\WindowsApps\\"
)

$found = @()
foreach ($r in $roots) {
    if (-not (Test-Path $r)) { continue }
    try {
        $matches = Get-ChildItem -Path $r -Recurse -Filter python.exe -ErrorAction SilentlyContinue -Force -File -Depth 3
        foreach ($m in $matches) {
            $found += $m.FullName
        }
    } catch { }
}

# also check where.exe
try { $where = (where.exe python 2>$null) } catch { $where = $null }
if ($where) { $found += $where }

$found = $found | Select-Object -Unique
Write-Host "--- python.exe locations found ---"
if ($found.Count -eq 0) { Write-Host "No python.exe found in standard locations or on PATH." } else { $found | ForEach-Object { Write-Host $_ } }

# write JSON report
$report = [ordered]@{}
$report.timestamp = (Get-Date).ToString('o')
$report.found = $found
$json = $report | ConvertTo-Json -Depth 3
$outFile = Join-Path (Join-Path (Get-Location) 'logs') ("find-python.$((Get-Date).ToString('yyyyMMddHHmmss')).json")
$json | Out-File -FilePath $outFile -Encoding utf8
Write-Host "Saved JSON to $outFile"
