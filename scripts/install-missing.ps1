# Installs missing Python and git-filter-repo on Windows
# May prompt for elevation when installing system packages (winget/choco).

Write-Host 'Detecting existing tools...'
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
$wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
$chocoCmd = Get-Command choco -ErrorAction SilentlyContinue

$needsPython = -not $pythonCmd

if (-not $needsPython) { Write-Host "Python found at: $($pythonCmd.Source)" }
else { Write-Host 'Python not found.' }

if ($needsPython) {
  if ($wingetCmd) {
    Write-Host 'Installing Python via winget (may prompt for approval)...'
    try {
      Start-Process -FilePath 'winget' -ArgumentList 'install','--id','Python.Python','-e' -Verb RunAs -Wait
    } catch {
      Write-Host "winget install failed: $_"
      exit 3
    }
  } elseif ($chocoCmd) {
    Write-Host 'Installing Python via choco (may prompt for approval)...'
    try {
      Start-Process -FilePath 'choco' -ArgumentList 'install','python','-y' -Verb RunAs -Wait
    } catch {
      Write-Host "choco install failed: $_"
      exit 3
    }
  } else {
    Write-Host 'No winget or choco detected. Please install Python manually from https://www.python.org/downloads/ and re-run this script.'
    exit 2
  }
}

# Refresh python detection
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
  Write-Host 'Python still not found after attempted install. Stopping.'
  exit 4
}

Write-Host 'Installing git-filter-repo via pip (user scope)...'
try {
  & $pythonCmd.Source -m pip install --user git-filter-repo | Out-Host
} catch {
  Write-Host "pip install failed: $_"
  exit 5
}

Write-Host 'Installation complete. You may need to restart terminals for PATH changes to take effect.'
exit 0
