<#
Usage: .\export-todos-dashboard.ps1 -TodoJsonPath .continue/backlog.json -OutPath docs/TODO_DASHBOARD.md

The script reads a JSON array of todo items with optional fields: id, title, description, status, team, role.
It groups by `team` then `role` and emits a Markdown dashboard.
#>
param(
    [string]$TodoJsonPath = ".continue/backlog.json",
    [string]$OutPath = "docs/TODO_DASHBOARD.md"
)

Set-StrictMode -Version Latest

function Load-TodosFromPath {
    param([string]$p)
    if (-not (Test-Path $p)) { throw "Todo JSON not found: $p" }
    $raw = Get-Content $p -Raw
    return ConvertFrom-Json $raw
}

try {
    $todos = Load-TodosFromPath -p $TodoJsonPath
} catch {
    Write-Error $_.Exception.Message
    exit 2
}

# Normalize: ensure array
if ($null -eq $todos) { $todos = @() }
if ($todos -isnot [System.Array]) { $todos = @($todos) }

$grouped = $todos | Group-Object -Property { if ($_.team) { $_.team } else { 'Unassigned' } }

$md = @()
$md += "# Todo Dashboard"
$md += "Generated: $(Get-Date -Format o)"

foreach ($g in $grouped) {
    $team = $g.Name
    $md += "`n## Team: $team`n"

    $byRole = $g.Group | Group-Object -Property { if ($_.role) { $_.role } else { 'any' } }
    foreach ($r in $byRole) {
        $role = $r.Name
        $md += "`n### Role: $role`n"
        $md += "| ID | Title | Status | Description |"
        $md += "|---|---|---|---|"
        foreach ($t in $r.Group) {
            $id = if ($t.id) { $t.id } else { '' }
            $title = ($t.title -replace '\r|\n',' ') -replace '\|','\|' 
            $status = if ($t.status) { $t.status } else { '' }
            $desc = if ($t.description) { ($t.description -replace '\r|\n',' ') -replace '\|','\|' } else { '' }
            $md += "| $id | $title | $status | $desc |"
        }
    }
}

[IO.Directory]::CreateDirectory((Split-Path $OutPath -Parent)) | Out-Null
$md -join "`n" | Out-File -FilePath $OutPath -Encoding UTF8
Write-Output "Wrote dashboard to: $OutPath"

exit 0
