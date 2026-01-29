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
  [switch]$Confirm,
  [string]$TracePath = '.continue/install-trace.log',
  [switch]$ApplyPath,
  [string]$RuntimePath
)

function Test-CommandExists { param([string]$cmd) return (Get-Command $cmd -ErrorAction SilentlyContinue) -ne $null }

function Write-Trace {
  param([string]$msg)
  $line = "[$((Get-Date).ToString('o'))] $msg"
  try { Add-Content -Path $TracePath -Value $line -Encoding utf8 -ErrorAction SilentlyContinue } catch {}
  Write-Host $msg -ForegroundColor Cyan
}

Write-Trace "Install helper: checking environment..."

$checks = [ordered]@{
    ollama = Test-CommandExists 'ollama'
    choco  = Test-CommandExists 'choco'
    winget = Test-CommandExists 'winget'
    docker = Test-CommandExists 'docker'
    git    = Test-CommandExists 'git'
    '7z'   = Test-CommandExists '7z'
}

Write-Trace "Environment results:"
foreach ($k in $checks.Keys) { $s = ("  {0} : {1}" -f $k, (if ($checks[$k]) { 'OK' } else { 'MISSING' })); Write-Trace $s }

if ($DryRun) { Write-Trace "Dry-run: no changes will be made." }

# Recommended install commands (non-destructive guidance)
Write-Trace "`nRecommended commands (copy & run locally):"
Write-Trace "  - Install Ollama: https://ollama.com/docs/installation"
Write-Trace "    Example (Windows): download installer from Ollama website and run it as admin."
Write-Trace "  - Install Chocolatey (optional): Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
Write-Trace "  - Install 7-Zip: choco install 7zip -y"
Write-Trace "  - Install Git: choco install git -y  OR use https://git-scm.com/download/win"
Write-Trace "  - Install Docker (optional): https://docs.docker.com/desktop/windows/install/"

if ($PullModel) {
  if (-not $checks[$Runtime]) {
    Write-Trace "Runtime '$Runtime' not found. Cannot pull model. Install $Runtime first." 
    exit 2
  }

  $pullCmd = "$Runtime pull $Model"
  if ($DryRun) { Write-Trace "Dry-run: would run: $pullCmd" ; exit 0 }

  if (-not $Confirm) {
    $answer = Read-Host "About to run: $pullCmd  — proceed? (Y/N)"
    if ($answer -notin @('Y','y')) { Write-Trace 'Aborting model pull.' ; exit 3 }
  }

  try {
    Write-Trace "Running: $pullCmd"
    $proc = Start-Process -FilePath $Runtime -ArgumentList @('pull',$Model) -NoNewWindow -PassThru -Wait
    if ($proc.ExitCode -ne 0) { Write-Trace "Model pull failed (exit $($proc.ExitCode))" ; exit 4 }
    Write-Trace "Model pulled: $Model"

    # Optionally apply PATH for runtime if requested
    if ($ApplyPath -and $RuntimePath) {
      Write-Trace "ApplyPath requested. RuntimePath=$RuntimePath"
      if ($DryRun) { Write-Trace "Dry-run: would add $RuntimePath to user PATH" }
      else {
        if (-not $Confirm) {
          $ans = Read-Host "About to add '$RuntimePath' to user PATH via setx (requires new session to take effect). Proceed? (Y/N)"
          if ($ans -notin @('Y','y')) { Write-Trace 'Skipping PATH update.' }
        }
        try {
          $current = [Environment]::GetEnvironmentVariable('Path',[EnvironmentVariableTarget]::User)
          if ($current -notlike "*${RuntimePath}*") {
            $new = "$current;${RuntimePath}"
            setx PATH "$new" | Out-Null
            Write-Trace "User PATH updated with $RuntimePath (setx applied)."
          } else { Write-Trace "RuntimePath already in user PATH." }
        } catch { Write-Trace "Failed to update PATH: $($_.Exception.Message)" }
      }
    }

    exit 0
  } catch {
    Write-Trace "Model pull exception: $($_.Exception.Message)"
    exit 5
  }
}

Write-Trace "Done. Run with -PullModel to pull the default model using Ollama if installed." 
exit 0
