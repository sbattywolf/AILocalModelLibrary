<#
.SYNOPSIS
  Non-destructive Windows installer helper and model pull helper.

.DESCRIPTION
  Checks for required tools (ollama, git, 7z, choco, docker, winget) and
  prints recommended install commands. Optionally performs a model pull using
  the specified runtime when -PullModel is supplied and the runtime is present.

.PARAMETER DryRun
  Show actions without executing destructive commands.

.PARAMETER PullModel
  Attempt to pull the specified model using the runtime (e.g. ollama).

.PARAMETER Model
  Model identifier to pull. Default: codellama/7b-instruct

.PARAMETER Runtime
  Runtime to use for pulling the model. Default: ollama

.PARAMETER Confirm
  Bypass interactive confirmation when performing actions.
#>

param(
    [switch]$DryRun,
    [switch]$PullModel,
    [string]$Model = 'codellama/7b-instruct',
    [string]$Runtime = 'ollama',
    [switch]$Confirm
)

function Test-CommandExists { param([string]$cmd) return (Get-Command $cmd -ErrorAction SilentlyContinue) -ne $null }

Write-Host "Install helper: checking environment..." -ForegroundColor Cyan

$checks = [ordered]@{
    ollama = Test-CommandExists 'ollama'
    choco  = Test-CommandExists 'choco'
    winget = Test-CommandExists 'winget'
    docker = Test-CommandExists 'docker'
    git    = Test-CommandExists 'git'
    '7z'   = Test-CommandExists '7z'
}

Write-Host "Environment results:" -ForegroundColor Gray
foreach ($k in $checks.Keys) { Write-Host ("  {0} : {1}" -f $k, (if ($checks[$k]) { 'OK' } else { 'MISSING' })) }

if ($DryRun) {
    Write-Host "Dry-run: no changes will be made." -ForegroundColor Yellow
}

# Recommended install commands (non-destructive guidance)
Write-Host "`nRecommended commands (copy & run locally):" -ForegroundColor Gray
Write-Host "  - Install Ollama: https://ollama.com/docs/installation" -ForegroundColor Gray
Write-Host "    Example (Windows): download installer from Ollama website and run it as admin." -ForegroundColor Gray
Write-Host "  - Install Chocolatey (optional): Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" -ForegroundColor Gray
Write-Host "  - Install 7-Zip: choco install 7zip -y" -ForegroundColor Gray
Write-Host "  - Install Git: choco install git -y  OR use https://git-scm.com/download/win" -ForegroundColor Gray
Write-Host "  - Install Docker (optional): https://docs.docker.com/desktop/windows/install/" -ForegroundColor Gray

if ($PullModel) {
    if (-not $checks[$Runtime]) {
        Write-Host "Runtime '$Runtime' not found. Cannot pull model. Install $Runtime first." -ForegroundColor Red
        exit 2
    }

    $pullCmd = "$Runtime pull $Model"
    if ($DryRun) {
        Write-Host "Dry-run: would run: $pullCmd" -ForegroundColor Yellow
        exit 0
    }

    if (-not $Confirm) {
        $answer = Read-Host "About to run: $pullCmd  — proceed? (Y/N)"
        if ($answer -notin @('Y','y')) { Write-Host 'Aborting model pull.' -ForegroundColor Yellow; exit 3 }
    }

    try {
        Write-Host "Running: $pullCmd" -ForegroundColor Cyan
        & $Runtime pull $Model
        if ($LASTEXITCODE -ne 0) { Write-Host "Model pull failed (exit $LASTEXITCODE)" -ForegroundColor Red ; exit 4 }
        Write-Host "Model pulled: $Model" -ForegroundColor Green
        exit 0
    } catch {
        Write-Host "Model pull exception: $($_.Exception.Message)" -ForegroundColor Red
        exit 5
    }
}

Write-Host "Done. Run with -PullModel to pull the default model using Ollama if installed." -ForegroundColor Green
exit 0
