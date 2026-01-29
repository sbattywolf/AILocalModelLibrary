<#
.SYNOPSIS
  Interactive helper to check and test `OLLAMA_HOME` on this machine.

.DESCRIPTION
  Prints current `OLLAMA_HOME`, suggests a default installation path based on
  the current user, lets you test a path interactively, and shows exactly what
  commands to run to set the variable (session or persistent). Designed to be
  PS5.1-compatible and friendly for copy/paste.
#>

param(
    [switch]$VerboseOutput
)

function Info { param($m) Write-Host $m }

$defaultPath = Join-Path $env:USERPROFILE 'AppData\\Local\\Programs\\Ollama'
Info '--- OLLAMA_HOME check ---'
Info "Current OLLAMA_HOME env: '$env:OLLAMA_HOME'"

$testPath = $null
if ($env:OLLAMA_HOME -and ($env:OLLAMA_HOME.Trim() -ne '')) {
    Info 'Using existing OLLAMA_HOME environment variable.'
    $testPath = $env:OLLAMA_HOME
} else {
    Info 'OLLAMA_HOME is not set.'
    Info "Suggested default path based on current user: $defaultPath"
    $prompt = "Press Enter to accept suggested path, or type a different path to test"
    $input = Read-Host $prompt
    if ($input -eq '') { $testPath = $defaultPath } else { $testPath = $input }
}

Info "Testing path: $testPath"
if (Test-Path $testPath) {
    Info "Path exists: $testPath"
    try {
        Get-ChildItem -Path $testPath -Force | Select-Object Name,Length | Format-Table -AutoSize
    } catch {
        Info "(Could not enumerate contents: $($_ | Out-String))"
    }

    Info ''
    Info 'To set OLLAMA_HOME for this PowerShell session (temporary):'
    Info "    `$env:OLLAMA_HOME = '$testPath'"
    Info ''
    Info 'To persist OLLAMA_HOME for your user (uses setx):'
    Info "    setx OLLAMA_HOME \"$testPath\""
    Info ''
    Info 'Notes:'
    Info ' - After running setx, start a new PowerShell session to see the variable.'
    Info ' - If Ollama is not installed at the suggested path, install it from https://ollama.com/docs/installation'
} else {
    Info "Path does not exist: $testPath"
    Info ''
    Info 'Suggested actions:'
    Info " - If Ollama is installed elsewhere, re-run this script and type the correct path when prompted."
    Info " - Install Ollama and then re-run this script."
    Info " - Example to persist the correct path once you know it: setx OLLAMA_HOME \"C:\\path\\to\\ollama\""
}

if ($VerboseOutput) { Info 'check-ollama-home completed.' }
