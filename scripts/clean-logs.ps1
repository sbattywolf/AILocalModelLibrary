<#
.SYNOPSIS
  Cleanup transient log files in the repository.
.DESCRIPTION
  Lists .log files under the repository and optionally deletes older files.
.PARAMETER Days
  Only target files older than this many days. Default: 7
.PARAMETER WhatIf
  Pass-through to Remove-Item's -WhatIf (useful for dry-run).
.PARAMETER Force
  Delete without prompting.
#>
param(
    [int]$Days = 7,
    [switch]$Force
)

$repoRoot = (Get-Location).Path
Write-Host "Repository root: $repoRoot"

$cutoff = (Get-Date).AddDays(-$Days)
$logFiles = Get-ChildItem -Path $repoRoot -Include *.log -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { -not ($_.FullName -match '\.git\\') }

if (-not $logFiles) {
    Write-Host "No log files found."
    exit 0
}

Write-Host "Found $($logFiles.Count) log file(s):"
$logFiles | ForEach-Object { Write-Host (" - {0} ({1} KB) - LastWrite: {2}" -f $_.FullName, [math]::Round($_.Length/1KB,2), $_.LastWriteTime) }

$toDelete = $logFiles | Where-Object { $_.LastWriteTime -lt $cutoff }

if (-not $toDelete) {
    Write-Host "No log files older than $Days day(s). Use -Days 0 to target all logs."
    exit 0
}

Write-Host "Deleting $($toDelete.Count) file(s) older than $Days day(s)."
foreach ($f in $toDelete) {
    if ($Force) {
        Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
        Write-Host "Deleted: $($f.FullName)"
    } else {
        Remove-Item -LiteralPath $f.FullName -WhatIf
    }
}

Write-Host "Done. Use -Force to perform deletions."