param(
    [object]$DryRun = $true,
    [int]$MonitorSeconds = 0
)

function Normalize-Bool($v) {
    if ($v -is [System.Management.Automation.SwitchParameter]) { return [bool]$v.IsPresent }
    return [bool]$v
}

$DryRun = Normalize-Bool $DryRun

Write-Host "Starting local AI environment (Runtime: Ollama) DryRun=$DryRun" -ForegroundColor Magenta

if ($DryRun) { Write-Host 'Dry-run: would start Ollama, VS Code and GPU monitor.' -ForegroundColor Yellow; return }

# Start Ollama if not running
try {
    if (-not (Get-Process -Name 'ollama' -ErrorAction SilentlyContinue)) {
        Start-Process -FilePath 'ollama' -ArgumentList 'app' -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Write-Host 'Started ollama.' -ForegroundColor Green
    } else {
        Write-Host 'ollama already running.' -ForegroundColor DarkYellow
    }
} catch { Write-Host "Warning: could not start ollama: $($_.Exception.Message)" -ForegroundColor DarkYellow }

# Start VS Code
try { Start-Process -FilePath 'code' -ErrorAction SilentlyContinue; Write-Host 'Launched VS Code.' -ForegroundColor Green } catch { }

# record PID/marker (repo-relative)
try {
    $repoRootCandidate = Join-Path $PSScriptRoot '..\..'
    try { $RepoRoot = (Resolve-Path -Path $repoRootCandidate -ErrorAction SilentlyContinue).Path } catch { $RepoRoot = (Get-Location).Path }
    $toolDir = Join-Path $RepoRoot '.continue\tool'
    if (-not (Test-Path $toolDir)) { New-Item -ItemType Directory -Path $toolDir -Force | Out-Null }
    $pidFile = Join-Path $toolDir 'ai_env.pid'
    $markerFile = Join-Path $toolDir 'ai_env.marker'
    Set-Content -Path $pidFile -Value $PID -Encoding ASCII -Force
    "$((Get-Date).ToString('o')) STARTED Local" | Out-File -FilePath $markerFile -Encoding UTF8 -Append
} catch { Write-Host "Warning: could not write PID/marker: $($_.Exception.Message)" -ForegroundColor DarkYellow }

# Start GPU monitor in a new window
if ($MonitorSeconds -gt 0) {
    Start-Process powershell -ArgumentList '-NoExit','-Command',"Write-Host 'Monitor: RTX 3090 (Ctrl+C to stop)' -ForegroundColor Yellow; nvidia-smi -l 5; Start-Sleep -Seconds $MonitorSeconds"
} else {
    Start-Process powershell -ArgumentList '-NoExit','-Command',"Write-Host 'Monitor: RTX 3090 (Ctrl+C to stop)' -ForegroundColor Yellow; nvidia-smi -l 5"
}

Write-Host "Environment ready." -ForegroundColor Green
Write-Host "Environment ready." -ForegroundColor Green
param(
    [object]$DryRun = $true,
    [int]$MonitorSeconds = 0
)

function Normalize-Bool($v) {
    if ($v -is [System.Management.Automation.SwitchParameter]) { return [bool]$v.IsPresent }
    return [bool]$v
}

$DryRun = Normalize-Bool $DryRun

Write-Host "Starting local AI environment (Runtime: Ollama) DryRun=$DryRun" -ForegroundColor Magenta

if ($DryRun) { Write-Host 'Dry-run: would start Ollama, VS Code and GPU monitor.' -ForegroundColor Yellow; return }

# Start Ollama if not running
try {
    if (-not (Get-Process -Name 'ollama' -ErrorAction SilentlyContinue)) {
        Start-Process -FilePath 'ollama' -ArgumentList 'app' -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Write-Host 'Started ollama.' -ForegroundColor Green
    } else {
        Write-Host 'ollama already running.' -ForegroundColor DarkYellow
    }
} catch { Write-Host "Warning: could not start ollama: $($_.Exception.Message)" -ForegroundColor DarkYellow }

# Start VS Code
try { Start-Process -FilePath 'code' -ErrorAction SilentlyContinue; Write-Host 'Launched VS Code.' -ForegroundColor Green } catch { }

# record PID/marker (repo-relative)
try {
    $repoRootCandidate = Join-Path $PSScriptRoot '..\..'
    try { $RepoRoot = (Resolve-Path -Path $repoRootCandidate -ErrorAction SilentlyContinue).Path } catch { $RepoRoot = (Get-Location).Path }
    $toolDir = Join-Path $RepoRoot '.continue\tool'
    if (-not (Test-Path $toolDir)) { New-Item -ItemType Directory -Path $toolDir -Force | Out-Null }
    $pidFile = Join-Path $toolDir 'ai_env.pid'
    $markerFile = Join-Path $toolDir 'ai_env.marker'
    Set-Content -Path $pidFile -Value $PID -Encoding ASCII -Force
    "$((Get-Date).ToString('o')) STARTED Local" | Out-File -FilePath $markerFile -Encoding UTF8 -Append
} catch { Write-Host "Warning: could not write PID/marker: $($_.Exception.Message)" -ForegroundColor DarkYellow }

# Start GPU monitor in a new window
if ($MonitorSeconds -gt 0) {
    Start-Process powershell -ArgumentList '-NoExit','-Command',"Write-Host 'Monitoraggio RTX 3090 (Ctrl+C per chiudere)' -ForegroundColor Yellow; nvidia-smi -l 5; Start-Sleep -Seconds $MonitorSeconds"
} else {
    Start-Process powershell -ArgumentList '-NoExit','-Command',"Write-Host 'Monitoraggio RTX 3090 (Ctrl+C per chiudere)' -ForegroundColor Yellow; nvidia-smi -l 5"
}

Write-Host "Environment ready." -ForegroundColor Green
param(
    [switch]$DryRun,
    [int]$MonitorSeconds = 0
)

Write-Host "Avvio Ambiente AI Locale..." -ForegroundColor Magenta

if ($DryRun) { Write-Host 'Dry-run: would start Ollama, VS Code and GPU monitor.' -ForegroundColor Yellow; return }

# Avvia Ollama se non è già in esecuzione
if (!(Get-Process "ollama" -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath "ollama" -ArgumentList "app"
    Start-Sleep -Seconds 2
}

# Avvia VS Code
Start-Process -FilePath "code"

# record PID/marker
$toolDir = Join-Path -Path (Get-Location) -ChildPath '.continue\tool'
try { Set-Content -Path (Join-Path $toolDir 'ai_env.pid') -Value $PID -Encoding ASCII -Force } catch { }
try { "$((Get-Date).ToString('o')) STARTED Local" | Out-File -FilePath (Join-Path $toolDir 'ai_env.marker') -Encoding UTF8 -Append } catch { }

# Avvia monitoraggio GPU in una nuova finestra
if ($MonitorSeconds -gt 0) {
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host 'Monitoraggio RTX 3090 (Ctrl+C per chiudere)' -ForegroundColor Yellow; nvidia-smi -l 5; Start-Sleep -Seconds $MonitorSeconds"
} else {
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host 'Monitoraggio RTX 3090 (Ctrl+C per chiudere)' -ForegroundColor Yellow; nvidia-smi -l 5"
}

Write-Host "Ambiente pronto. Buon coding e buon apprendimento!" -ForegroundColor Green
param(
    [switch]$DryRun,
    [int]$MonitorSeconds = 0
)

Write-Host "Avvio Ambiente AI Locale..." -ForegroundColor Magenta

if ($DryRun) { Write-Host 'Dry-run: would start Ollama, VS Code and GPU monitor.' -ForegroundColor Yellow; return }

# Avvia Ollama se non è già in esecuzione
if (!(Get-Process "ollama" -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath "ollama" -ArgumentList "app"
    Start-Sleep -Seconds 2
}

# Avvia VS Code
Start-Process -FilePath "code"

# record PID/marker
$toolDir = Join-Path -Path (Get-Location) -ChildPath '.continue\tool'
try { Set-Content -Path (Join-Path $toolDir 'ai_env.pid') -Value $PID -Encoding ASCII -Force } catch { }
try { "$((Get-Date).ToString('o')) STARTED Local" | Out-File -FilePath (Join-Path $toolDir 'ai_env.marker') -Encoding UTF8 -Append } catch { }

# Avvia monitoraggio GPU in una nuova finestra
if ($MonitorSeconds -gt 0) {
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host 'Monitoraggio RTX 3090 (Ctrl+C per chiudere)' -ForegroundColor Yellow; nvidia-smi -l 5; Start-Sleep -Seconds $MonitorSeconds"
} else {
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host 'Monitoraggio RTX 3090 (Ctrl+C per chiudere)' -ForegroundColor Yellow; nvidia-smi -l 5"
}

Write-Host "Ambiente pronto. Buon coding e buon apprendimento!" -ForegroundColor Green
