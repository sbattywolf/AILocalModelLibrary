<#
setup-ollama.ps1

Helper to install and smoke-test Ollama on Windows. By default runs a non-destructive test.
Usage:
  -Test            : Run smoke tests (`ollama --version`, `ollama list`).
  -Install         : Attempt to install Ollama via winget or choco (requires elevation).
#>

param(
    [switch]$Install,
    [switch]$Test
)

function Check-Cmd($name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }

Write-Host "setup-ollama: Install=$($Install.IsPresent) Test=$($Test.IsPresent)"

$hasOllama = Check-Cmd 'ollama'
$hasWinget = Check-Cmd 'winget'
$hasChoco = Check-Cmd 'choco'

if ($Install) {
    if ($hasOllama) { Write-Host "Ollama already installed; skipping install." }
    else {
        if ($hasWinget) {
            Write-Host "Installing Ollama via winget..."
            winget install --id Ollama.Ollama -e --silent
        } elseif ($hasChoco) {
            Write-Host "Installing Ollama via choco..."
            choco install ollama -y
        } else {
            Write-Host "No package manager found. Please install Ollama manually from https://ollama.ai/docs" -ForegroundColor Yellow
            exit 2
        }
        Start-Sleep -Seconds 2
        $hasOllama = Check-Cmd 'ollama'
        if (-not $hasOllama) { Write-Warning "Ollama install reported but command not found. You may need to restart shell or add to PATH." }
    }
}

if ($Test -or -not $Install) {
    if ($hasOllama) {
        Write-Host "Running ollama --version"
        try { & ollama --version } catch { Write-Warning "Failed to run 'ollama --version': $_" }

        Write-Host "Running ollama list"
        try { & ollama list } catch { Write-Warning "Failed to run 'ollama list': $_" }
    } else {
        Write-Host "Ollama not found. Run with -Install to attempt installation, or install manually from https://ollama.ai/docs" -ForegroundColor Yellow
        exit 3
    }
}

Write-Host "setup-ollama: done"
exit 0
