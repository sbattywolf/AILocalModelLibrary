<#
.continue/tool/export-continue.ps1

Package the `.continue` folder for reuse in another repository or publish
it to a remote git repo. The script is conservative by default (DryRun).

Usage examples:
  # Create a zip of .continue (dry-run prints actions):
  .\export-continue.ps1 -DryRun

  # Create zip file (overwrite) and save as .continue-package.zip
  .\export-continue.ps1 -OutZip ..\my-continue-package.zip -Force

  # Clone remote repo and push contents (requires git credentials):
  .\export-continue.ps1 -RepoUrl https://github.com/you/continue-lib.git -Push -DryRun:$false

Notes:
 - This script excludes runtime artifacts: *.pid, *.marker, selected_agent.txt, and model caches.
 - Pushing to a remote requires git on PATH and valid credentials.
#>

param(
    [string]$OutZip = '.continue-package.zip',
    [string]$RepoUrl = '',
    [switch]$Push,
    [switch]$Force,
    [switch]$DryRun = $true
)

function Write-Action([string]$msg) { Write-Host $msg }

$root = Get-Location
$src = Join-Path $root '.continue'
if (-not (Test-Path $src)) { Write-Error "No .continue folder found at $src"; exit 2 }

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetFileNameWithoutExtension([System.IO.Path]::GetTempFileName()))
New-Item -Path $tmp -ItemType Directory -Force | Out-Null

$excludes = @('*.pid','*.marker','selected_agent.txt','**/model-cache/**','**/cache/**')

Write-Action "Preparing export from $src -> $OutZip (DryRun=$DryRun)"

if ($DryRun) {
    Write-Action "Would copy .continue to temp: $tmp"
    Write-Action "Excluding: $($excludes -join ', ')"
} else {
    Copy-Item -Path $src -Destination $tmp -Recurse -Force
    foreach ($pat in $excludes) {
        Get-ChildItem -Path (Join-Path $tmp '.continue') -Recurse -Include $pat -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $OutZip -and -not $Force) { Write-Error "Out file exists. Use -Force to overwrite."; Remove-Item -Path $tmp -Recurse -Force; exit 3 }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory((Join-Path $tmp '.continue'), (Resolve-Path $OutZip).Path)
    Write-Action "Created zip: $OutZip"
}

if ($RepoUrl) {
    if ($DryRun) {
        Write-Action "Would clone remote repo $RepoUrl into temp and copy files."
    } else {
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Error "git not found on PATH"; Remove-Item -Path $tmp -Recurse -Force; exit 4 }
        $repoTmp = Join-Path ([System.IO.Path]::GetTempPath()) ((New-Guid).Guid)
        git clone $RepoUrl $repoTmp
        Copy-Item -Path (Join-Path $tmp '.continue') -Destination $repoTmp -Recurse -Force
        Push-Location $repoTmp
        try {
            git add .
            git commit -m "Import .continue from $($env:COMPUTERNAME) - $(Get-Date -Format o)" 2>$null
            if ($LASTEXITCODE -ne 0) { Write-Host "Nothing to commit" }
            if ($Push) { git push }
        } finally { Pop-Location }
        Write-Action "Pushed to $RepoUrl"
    }
}

if (-not $DryRun) { Remove-Item -Path $tmp -Recurse -Force }

Write-Action "Export complete."
