<#
Define minimal Test-LoadJson/Test-WriteJsonAtomic helpers in this session
then invoke monitor-background.ps1 in DryRun Once mode.
#>

Set-StrictMode -Version Latest
$repoRoot = Split-Path -Path $PSScriptRoot -Parent

function Test-WriteJsonAtomic {
    param($Path, $Object)
    $dir = Split-Path -Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $tmp = [System.IO.Path]::Combine($dir, ([System.IO.Path]::GetRandomFileName() + '.tmp'))
    $json = $Object | ConvertTo-Json -Depth 10
    Set-Content -Path $tmp -Value $json -Encoding UTF8
    Move-Item -Force -Path $tmp -Destination $Path
    return $Path
}

function Test-LoadJson {
    param([string]$Path)
    if (-not (Test-Path $Path)) { throw "File not found: $Path" }
    $text = Get-Content -Raw -Encoding UTF8 -Path $Path
    if ($text -is [object[]]) { $text = $text -join "`n" }
    if ($null -eq $text -or $text -eq '') { return $null }
    $text = $text -replace "^\s*```(?:json)?\s*",""
    $text = $text -replace "\s*```\s*$",""
    $lastBrace = $text.LastIndexOf('}')
    $lastBracket = $text.LastIndexOf(']')
    $endPos = [Math]::Max($lastBrace, $lastBracket)
    if ($endPos -ge 0 -and $endPos -lt $text.Length - 1) { $text = $text.Substring(0, $endPos + 1) }
    return $text | ConvertFrom-Json -ErrorAction Stop
}

Write-Host "Helpers defined. Invoking monitor-background.ps1 -DryRun -Once"
& (Join-Path $repoRoot 'scripts\monitor-background.ps1') -DryRun -Once
