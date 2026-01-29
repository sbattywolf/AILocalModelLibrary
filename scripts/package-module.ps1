<#
.SYNOPSIS
  Package a PowerShell module directory into a ZIP suitable for distribution.

.DESCRIPTION
  Attempts to use `git archive` (respects .gitattributes export-ignore) when
  available. Falls back to a filesystem-based packaging which reads .gitattributes
  to exclude patterns marked `export-ignore`.

.PARAMETER ModulePath
  Path to module directory (relative to repo root). Default: templates/agent/SimRacingAgent

.PARAMETER OutFile
  Path to output zip file. Default: dist/SimRacingAgent.zip

.PARAMETER UseGitArchive
  Force using git archive. If not present, will fall back automatically.
#>

param(
    [string]$ModulePath = 'templates/agent/TemplateAgent',
    [string]$OutFile = 'dist/TemplateAgent.zip',
    [switch]$UseGitArchive
)

function Get-RepoRoot {
    # Prefer PSScriptRoot when available, fall back to MyInvocation, then current dir
    $start = $null
    if ($PSCommandPath) { $start = Split-Path -Parent $PSCommandPath }
    elseif ($PSScriptRoot) { $start = $PSScriptRoot }
    elseif ($MyInvocation -and $MyInvocation.MyCommand.Definition) { $start = Split-Path -Parent $MyInvocation.MyCommand.Definition }
    else { $start = (Get-Location).Path }

    $p = $start
    while ($p) {
        if (Test-Path (Join-Path $p '.git')) { return $p }
        $parent = Split-Path -Parent $p
        if (-not $parent -or $parent -eq $p) { break }
        $p = $parent
    }
    return $null
}

function Parse-GitAttributesExportIgnore {
    param([string]$repoRoot)
    $file = Join-Path $repoRoot '.gitattributes'
    $patterns = @()
    if (Test-Path $file) {
        foreach ($line in Get-Content $file) {
            $l = $line.Trim()
            if ($l -and -not $l.StartsWith('#')) {
                $parts = $l -split '\s+'
                if ($parts.Length -ge 2 -and $parts[-1] -eq 'export-ignore') {
                    $patterns += $parts[0]
                }
            }
        }
    }
    return $patterns
}

function Convert-AttrPatternToGlob {
    param([string]$pattern)
    # Simple conversion: gitattr patterns are similar to globs. Normalize leading slash.
    $p = $pattern.Trim()
    if ($p.StartsWith('/')) { $p = $p.Substring(1) }
    return $p
}

$repo = Get-RepoRoot
if (-not $repo) { Write-Error "Could not locate .git repository root; run from inside repo." ; exit 2 }

$absModule = Join-Path $repo $ModulePath
if (-not (Test-Path $absModule)) { Write-Error "Module path not found: $absModule" ; exit 3 }

New-Item -Path (Split-Path $OutFile -Parent) -ItemType Directory -Force | Out-Null

if ($UseGitArchive -or (Get-Command git -ErrorAction SilentlyContinue)) {
    try {
        Write-Host "Packaging via git archive..." -ForegroundColor Cyan
        $prefix = (Split-Path $ModulePath -Leaf) + '/'
        $outFull = [System.IO.Path]::GetFullPath($OutFile)
        git -C $repo archive --format=zip --prefix=$prefix -o $outFull HEAD $ModulePath
        Write-Host "Wrote $OutFile" -ForegroundColor Green
        exit 0
    } catch {
        Write-Warning "git archive failed or unavailable, falling back: $($_.Exception.Message)"
        if ($repo) { Pop-Location } 2>$null
    }
}

# Fallback: build include file list respecting .gitattributes export-ignore
$patterns = Parse-GitAttributesExportIgnore -repoRoot $repo
$excludeGlobs = @()
foreach ($pat in $patterns) { $excludeGlobs += Convert-AttrPatternToGlob -pattern $pat }

# Gather files under module folder
$files = Get-ChildItem -Path $absModule -Recurse -File | ForEach-Object { $_.FullName }

function IsExcluded { param($fullPath)
    $rel = Resolve-Path -LiteralPath $fullPath | ForEach-Object { $_.Path.Substring($repo.Length + 1) }
    foreach ($g in $excludeGlobs) {
        if ($rel -like $g) { return $true }
    }
    return $false
}

$includeFiles = @()
foreach ($f in $files) { if (-not (IsExcluded $f)) { $includeFiles += $f } }

if ($includeFiles.Count -eq 0) { Write-Error "No files to include for packaging." ; exit 4 }

Write-Host "Packaging via filesystem fallback; including $($includeFiles.Count) files." -ForegroundColor Cyan
Compress-Archive -Path $includeFiles -DestinationPath $OutFile -Force
Write-Host "Wrote $OutFile" -ForegroundColor Green
exit 0
