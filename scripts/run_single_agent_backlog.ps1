Param(
    [int]$Capacity = 8
)

# PowerShell fallback for single-agent backlog prototype
$root = Get-Location
$exclude = @('.git','.tmp','node_modules','__pycache__','.venv')

function Is-TextFile($path) {
    try {
        Get-Content -Path $path -TotalCount 1 -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

$items = @()
Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
    $rel = $_.FullName.Substring($root.Path.Length).TrimStart('\')
    if ($exclude -contains $_.Name) { return }
    if ($_.FullName -match '\\(node_modules|\.git|__pycache__|\.venv|\.tmp)\\') { return }
    if (-not (Is-TextFile $_.FullName)) { return }
    try {
        $text = Get-Content -Raw -Encoding UTF8 -ErrorAction Stop -Path $_.FullName
    } catch { return }
    $lines = $text -split '\r?\n'
    for ($i=0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '\b(TODO|FIXME)\b') {
            $items += [pscustomobject]@{ source = $rel; line = $i+1; text = $lines[$i].Trim(); type='todo' }
        }
    }
    if ($text -match '(?m)^#{1,3}\s+') {
        $items += [pscustomobject]@{ source = $rel; type='doc'; text='Contains headings/documentation' }
    }
    if ($text -match '(?m)^\s*(def |class )') {
        $items += [pscustomobject]@{ source = $rel; type='code'; text='Contains code definitions' }
    }
}

function Estimate-Points($item) {
    $path = Join-Path $root $item.source
    $size = 0
    try { $size = (Get-Item $path).Length } catch { $size = 0 }
    switch ($item.type) {
        'todo' { $base = 2 }
        'doc' { $base = 1 }
        default { $base = 3 }
    }
    $extra = [int]($size / 50000)
    return [math]::Max(1, $base + $extra)
}

$backlog = @()
$id = 1
$seen = @{ }
foreach ($it in $items) {
    $key = "$($it.source)|$($it.line)|$($it.text)"
    if ($seen.ContainsKey($key)) { continue }
    $seen[$key] = $true
    $points = Estimate-Points $it
    $title = "Review $([System.IO.Path]::GetFileName($it.source)): $($it.text)"
    $desc = "Source: $($it.source)"
    if ($it.line) { $desc += " (line $($it.line))" }
    $priority = if ($it.type -eq 'todo') { 'high' } else { 'medium' }
    $backlog += [pscustomobject]@{
        id = $id; title = $title; description = $desc; source = $it.source; type = $it.type; estimate_points = $points; priority = $priority
    }
    $id++
}

# sort backlog
$backlog = $backlog | Sort-Object @{Expression = { if ($_.priority -eq 'high') {0} else {1}}}, estimate_points

# select first sprint
$sprint = @(); $total = 0
foreach ($b in $backlog) {
    if ($total + $b.estimate_points -le $Capacity) { $sprint += $b; $total += $b.estimate_points }
}

$outdir = Join-Path $root '.continue'
if (-not (Test-Path $outdir)) { New-Item -ItemType Directory -Path $outdir | Out-Null }

$bp = Join-Path $outdir 'backlog_proposal.json'
$fs = Join-Path $outdir 'first_sprint.json'
$summary = @{ backlog_count = $backlog.Count; sprint_selected = $sprint.Count; sprint_total_points = $total; sprint_capacity = $Capacity }

@{ backlog = $backlog; summary = $summary } | ConvertTo-Json -Depth 5 | Out-File -FilePath $bp -Encoding utf8
@{ first_sprint = $sprint; summary = $summary } | ConvertTo-Json -Depth 5 | Out-File -FilePath $fs -Encoding utf8

$txt = @()
$txt += 'Backlog Proposal'
$txt += '================'
foreach ($b in $backlog) { $txt += "$($b.id). [$($b.priority)] ($($b.estimate_points)pt) $($b.title) -- $($b.source)" }
$txt += "`nFirst sprint (capacity $Capacity):"
$txt += '-------------------------'
foreach ($s in $sprint) { $txt += "- $($s.id). $($s.title) ($($s.estimate_points)pt)" }
$txt += "Total points: $total/$Capacity"

$txt | Out-File -FilePath (Join-Path $outdir 'first_sprint.txt') -Encoding utf8

Write-Host "Wrote $bp, $fs, and first_sprint.txt"
