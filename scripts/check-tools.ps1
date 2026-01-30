# Check common tools and write JSON report
$report = [ordered]@{}
$report.timestamp = (Get-Date).ToString("o")
$report.cwd = (Get-Location).Path
$tools = @('python','pip','ollama','docker','git','nvidia-smi')
$report.tools = @{}

foreach ($t in $tools) {
    $info = [ordered]@{exe=$t; found=$false; path=$null; version=$null}
    $cmd = Get-Command $t -ErrorAction SilentlyContinue
    if ($null -ne $cmd) {
        $info.found = $true
        $info.path = $cmd.Source
        # try several version flags
        $ver = $null
        try { $ver = & $t --version 2>&1 } catch { }
        if (-not $ver) {
            try { $ver = & $t -V 2>&1 } catch { }
        }
        if (-not $ver) {
            try { $ver = & $t version 2>&1 } catch { }
        }
        if (-not $ver) { $ver = "(version unknown)" }
        $info.version = ($ver -join "\n")
    } else {
        # try where.exe
        try { $where = (where.exe $t 2>$null) } catch { $where = $null }
        if ($where) { $info.path = ($where -join ';') }
    }
    $report.tools[$t] = $info
}

# Additional checks
# PATH
$report.path = $env:PATH -split ';' | Where-Object { $_ -ne '' }
# Ollama default locations guess
$defaultOllama = @("C:\Program Files\Ollama\ollama.exe","C:\Program Files\Ollama\bin\ollama.exe","C:\Users\$env:USERNAME\AppData\Local\Programs\Ollama\ollama.exe")
$report.ollama_default_exists = @{}
foreach ($p in $defaultOllama) { $report.ollama_default_exists[$p] = Test-Path $p }

# Write output
Write-Host "--- Tool Check Report ---"
$report.tools.GetEnumerator() | ForEach-Object { $k=$_.Key; $v=$_.Value; Write-Host "Tool: $k Found: $($v.found) Path: $($v.path) Version: $($v.version)" }

$json = $report | ConvertTo-Json -Depth 6
$outFile = Join-Path (Join-Path (Get-Location) 'logs') ("check-tools.$((Get-Date).ToString('yyyyMMddHHmmss')).json")
$json | Out-File -FilePath $outFile -Encoding utf8
Write-Host "Saved JSON to $outFile"
