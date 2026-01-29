<#
Check presence of required tools for LLM agents on Windows (PS5.1-safe).
Exits 0 if all checks pass; exits 2 if any required tool is missing.
#>
$required = [ordered]@{
  'git' = 'git'
  'powershell' = 'powershell.exe'
  'python' = 'python'
  'node' = 'node'
  'ollama' = 'ollama'
  'git-filter-repo' = 'git-filter-repo'
}

$missing = @()
Write-Host 'Checking required tools in PATH...'
foreach ($k in $required.Keys) {
  $cmd = $required[$k]
  $found = $false
  try { if (Get-Command $cmd -ErrorAction SilentlyContinue) { $found = $true } } catch {}
  if ($found) { Write-Host ("- {0}: FOUND" -f $k) } else { Write-Host ("- {0}: MISSING" -f $k); $missing += $k }
}

# Special check: Pester module v4
Write-Host 'Checking Pester module (v4)...'
$pester = Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1
if ($pester) { Write-Host ("- Pester: FOUND (v{0})" -f $pester.Version) } else { Write-Host '- Pester: MISSING'; $missing += 'Pester' }

# Env checks
Write-Host 'Checking environment variables...'
if ($env:OPENAI_API_KEY) { Write-Host '- OPENAI_API_KEY: SET' } else { Write-Host '- OPENAI_API_KEY: NOT SET' }
if ($env:OLLAMA_HOME) { Write-Host "- OLLAMA_HOME: $env:OLLAMA_HOME" } else { Write-Host '- OLLAMA_HOME: NOT SET' }

if ($missing.Count -gt 0) {
  Write-Host ''
  Write-Host 'Some required tools are missing:'
  $missing | ForEach-Object { Write-Host " - $_" }
  Write-Host ''
  Write-Host 'Suggested install commands (Windows):'
  Write-Host ' - Install Chocolatey: https://chocolatey.org/install'
  Write-Host ' - Install git: choco install git -y'
  Write-Host ' - Install Python: choco install python -y'
  Write-Host ' - Install Node.js: choco install nodejs -y'
  Write-Host ' - Install Ollama: see https://ollama.com/docs/install'
  Write-Host ' - Install git-filter-repo: pip install git-filter-repo (or use package manager)'
  Write-Host ' - Install Pester v4: Install-Module Pester -RequiredVersion 4.10.0 -Scope CurrentUser'
  exit 2
} else {
  Write-Host ''
  Write-Host 'All required tools found.'
  exit 0
}
