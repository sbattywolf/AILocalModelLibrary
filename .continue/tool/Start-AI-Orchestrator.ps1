<#
Start-AI-Orchestrator.ps1
Canonical, single-copy orchestrator: starts Ollama (best-effort) and optionally
runs an optional telemetry loop. This file is intended to be a small,
well-formed, PowerShell 5.1 compatible orchestrator.
#>

param(
    [switch]$NoDaemon,
    [string]$Role = 'default'
)

Set-StrictMode -Off

if (-not $PSScriptRoot) { $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition }

$Script:RepoRoot = (Get-Location).Path
$Script:MarkerFile = Join-Path -Path $Script:RepoRoot -ChildPath '.continue\Start-AI-Orchestrator.marker'

function Write-Log {
    param([string]$Message)
    $ts = (Get-Date).ToString('o')
    "$ts`t$Message" | Out-File -FilePath ".\.continue\Start-AI-Orchestrator.log" -Append -Encoding utf8
}

Write-Log "Starting orchestrator for role='$Role' NoDaemon=$NoDaemon"

if (-not $NoDaemon) {
    # Launch detached background instance
    $psArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\Start-AI-Orchestrator.ps1`" -NoDaemon:`$true -Role:`"$Role`""
    Start-Process -FilePath powershell -ArgumentList $psArgs -WindowStyle Hidden | Out-Null
    Write-Log "Launched detached process"
    return
}

# Daemon main
try {
    New-Item -Path $Script:MarkerFile -ItemType File -Force | Out-Null
    Write-Log "Daemon running (role=$Role)"
    while ($true) {
        Write-Log "tick: role=$Role"
        Start-Sleep -Seconds 10
    }
}
catch {
    Write-Log "Orchestrator error: $($_.ToString())"
    exit 1
}
finally {
    if (Test-Path $Script:MarkerFile) { Remove-Item $Script:MarkerFile -Force -ErrorAction SilentlyContinue }
}
