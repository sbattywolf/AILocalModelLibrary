param(
    [object]$DryRun = $true,
    [int]$TimeoutSeconds = 0,
    [switch]$NoTelemetry,
    [switch]$AutoDisableOnHighLoad,
    [int]$VramThresholdMB = 12000,
    [int]$TempThresholdC = 85
)

function Normalize-Bool($v) {
    if ($v -is [System.Management.Automation.SwitchParameter]) { return [bool]$v.IsPresent }
    return [bool]$v
}

$DryRun = Normalize-Bool $DryRun

Write-Host "Starting hybrid AI orchestrator (DryRun=$DryRun)" -ForegroundColor Cyan

try {
    $repoRootCandidate = Join-Path $PSScriptRoot '..\..'
    try { $RepoRoot = (Resolve-Path -Path $repoRootCandidate -ErrorAction SilentlyContinue).Path } catch { $RepoRoot = (Get-Location).Path }
    $toolDir = Join-Path $RepoRoot '.continue\tool'
    if (-not (Test-Path $toolDir)) { New-Item -ItemType Directory -Path $toolDir -Force | Out-Null }
    $pidFile = Join-Path $toolDir 'ai_env.pid'
    $markerFile = Join-Path $toolDir 'ai_env.marker'
} catch { Write-Host "Warning: could not resolve repo paths: $($_.Exception.Message)" -ForegroundColor DarkYellow }

if (Test-Path $pidFile) {
    try {
        $oldPid = Get-Content $pidFile -ErrorAction SilentlyContinue
        if ($oldPid -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
            Write-Host "AI environment already appears running (PID=$oldPid). Use stop-ai-env or remove $pidFile to force." -ForegroundColor Yellow
            return
        } else {
            Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
        }
    } catch { }
}

if ($DryRun) { Write-Host "Dry-run: would start Ollama and VS Code, and telemetry (if enabled)." -ForegroundColor Yellow; return }

# Start Ollama if needed
if (-not (Get-Process -Name 'ollama' -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath 'ollama' -ArgumentList 'app' -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

# Start VS Code
try { Start-Process -FilePath 'code' -ErrorAction SilentlyContinue } catch { }

# record our PID and marker
try { Set-Content -Path $pidFile -Value $PID -Encoding ASCII -Force } catch { }
try { "$((Get-Date).ToString('o')) STARTED" | Out-File -FilePath $markerFile -Encoding UTF8 -Append } catch { }

if ($NoTelemetry) { Write-Host 'Telemetry disabled for this run.' -ForegroundColor Cyan; return }

Write-Host "Telemetry loop active (Ctrl+C to exit)" -ForegroundColor Yellow
$start = Get-Date
while ($true) {
    if ($TimeoutSeconds -gt 0) {
        $elapsed = (Get-Date) - $start
        if ($elapsed.TotalSeconds -ge $TimeoutSeconds) { Write-Host "Telemetry timeout reached; exiting." -ForegroundColor Cyan; break }
    }
    $vramRaw = (nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits) 2>$null
    $tempRaw = (nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits) 2>$null
    $vram = if ($vramRaw) { [int]$vramRaw } else { 0 }
    $temp = if ($tempRaw) { [int]$tempRaw } else { 0 }

    if ($AutoDisableOnHighLoad -and -not $NoTelemetry) {
        if ($vram -ge $VramThresholdMB -or $temp -ge $TempThresholdC) {
            $reason = "Auto-disabled telemetry: vram=${vram}MB temp=${temp}C"
            Write-Host $reason -ForegroundColor Yellow
            try { "$((Get-Date).ToString('o')) TELEMETRY_DISABLED $reason" | Out-File -FilePath $markerFile -Encoding UTF8 -Append } catch { }
            break
        }
    }

    Write-Host "`rVRAM: $vram MB | Temp: $temp C " -NoNewline
    Start-Sleep -Seconds 10
}
param(
    [object]$DryRun = $true,
    [int]$TimeoutSeconds = 0,
    [switch]$NoTelemetry,
    [switch]$AutoDisableOnHighLoad,
    [int]$VramThresholdMB = 12000,
    [int]$TempThresholdC = 85
)

function Normalize-Bool($v) {
    if ($v -is [System.Management.Automation.SwitchParameter]) { return [bool]$v.IsPresent }
    return [bool]$v
}

$DryRun = Normalize-Bool $DryRun

Write-Host "Starting hybrid AI orchestrator (DryRun=$DryRun)" -ForegroundColor Cyan

try {
    $repoRootCandidate = Join-Path $PSScriptRoot '..\..'
    try { $RepoRoot = (Resolve-Path -Path $repoRootCandidate -ErrorAction SilentlyContinue).Path } catch { $RepoRoot = (Get-Location).Path }
    $toolDir = Join-Path $RepoRoot '.continue\tool'
    if (-not (Test-Path $toolDir)) { New-Item -ItemType Directory -Path $toolDir -Force | Out-Null }
    $pidFile = Join-Path $toolDir 'ai_env.pid'
    $markerFile = Join-Path $toolDir 'ai_env.marker'
} catch { Write-Host "Warning: could not resolve repo paths: $($_.Exception.Message)" -ForegroundColor DarkYellow }

if (Test-Path $pidFile) {
    try {
        $oldPid = Get-Content $pidFile -ErrorAction SilentlyContinue
        if ($oldPid -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
            Write-Host "AI environment already appears running (PID=$oldPid). Use stop-ai-env or remove $pidFile to force." -ForegroundColor Yellow
            return
        } else {
            Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
        }
    } catch { }
}

if ($DryRun) { Write-Host "Dry-run: would start Ollama and VS Code, and telemetry (if enabled)." -ForegroundColor Yellow; return }

# Start Ollama if needed
if (-not (Get-Process -Name 'ollama' -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath 'ollama' -ArgumentList 'app' -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

# Start VS Code
try { Start-Process -FilePath 'code' -ErrorAction SilentlyContinue } catch { }

# record our PID and marker
try { Set-Content -Path $pidFile -Value $PID -Encoding ASCII -Force } catch { }
try { "$((Get-Date).ToString('o')) STARTED" | Out-File -FilePath $markerFile -Encoding UTF8 -Append } catch { }

if ($NoTelemetry) { Write-Host 'Telemetry disabled for this run.' -ForegroundColor Cyan; return }

Write-Host "Telemetry loop active (Ctrl+C to exit)" -ForegroundColor Yellow
$start = Get-Date
while ($true) {
    if ($TimeoutSeconds -gt 0) {
        $elapsed = (Get-Date) - $start
        if ($elapsed.TotalSeconds -ge $TimeoutSeconds) { Write-Host "Telemetry timeout reached; exiting." -ForegroundColor Cyan; break }
    }
    $vramRaw = (nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits) 2>$null
    $tempRaw = (nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits) 2>$null
    $vram = if ($vramRaw) { [int]$vramRaw } else { 0 }
    $temp = if ($tempRaw) { [int]$tempRaw } else { 0 }

    if ($AutoDisableOnHighLoad -and -not $NoTelemetry) {
        if ($vram -ge $VramThresholdMB -or $temp -ge $TempThresholdC) {
            $reason = "Auto-disabled telemetry: vram=${vram}MB temp=${temp}C"
            Write-Host $reason -ForegroundColor Yellow
            try { "$((Get-Date).ToString('o')) TELEMETRY_DISABLED $reason" | Out-File -FilePath $markerFile -Encoding UTF8 -Append } catch { }
            break
        }
    }

    $payload = @{
        gpu_vram_used = $vram
        gpu_temp = $temp
        status = "Coding"
    } | ConvertTo-Json -Compress

    Write-Host "`rVRAM: $vram MB | Temp: $temp C " -NoNewline
    Start-Sleep -Seconds 10
}
param(
    [object]$DryRun = $true,
    [int]$TimeoutSeconds = 0,
    [switch]$NoTelemetry,
    [switch]$AutoDisableOnHighLoad,
    [int]$VramThresholdMB = 12000,
    [int]$TempThresholdC = 85
)

function Normalize-Bool($v) {
    if ($v -is [System.Management.Automation.SwitchParameter]) { return [bool]$v.IsPresent }
    return [bool]$v
}

$DryRun = Normalize-Bool $DryRun

Write-Host "Starting hybrid AI orchestrator (DryRun=$DryRun)" -ForegroundColor Cyan

try {
    $repoRootCandidate = Join-Path $PSScriptRoot '..\..'
    try { $RepoRoot = (Resolve-Path -Path $repoRootCandidate -ErrorAction SilentlyContinue).Path } catch { $RepoRoot = (Get-Location).Path }
    $toolDir = Join-Path $RepoRoot '.continue\tool'
    if (-not (Test-Path $toolDir)) { New-Item -ItemType Directory -Path $toolDir -Force | Out-Null }
    $pidFile = Join-Path $toolDir 'ai_env.pid'
    $markerFile = Join-Path $toolDir 'ai_env.marker'
} catch { Write-Host "Warning: could not resolve repo paths: $($_.Exception.Message)" -ForegroundColor DarkYellow }

if (Test-Path $pidFile) {
    try {
        $oldPid = Get-Content $pidFile -ErrorAction SilentlyContinue
        if ($oldPid -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
            Write-Host "AI environment already appears running (PID=$oldPid). Use stop-ai-env or remove $pidFile to force." -ForegroundColor Yellow
            return
        } else {
            Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
        }
    } catch { }
}

if ($DryRun) { Write-Host "Dry-run: would start Ollama and VS Code, and telemetry (if enabled)." -ForegroundColor Yellow; return }

# Start Ollama if needed
if (-not (Get-Process -Name 'ollama' -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath 'ollama' -ArgumentList 'app' -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

# Start VS Code
try { Start-Process -FilePath 'code' -ErrorAction SilentlyContinue } catch { }

# record our PID and marker
try { Set-Content -Path $pidFile -Value $PID -Encoding ASCII -Force } catch { }
try { "$((Get-Date).ToString('o')) STARTED" | Out-File -FilePath $markerFile -Encoding UTF8 -Append } catch { }

if ($NoTelemetry) { Write-Host 'Telemetry disabled for this run.' -ForegroundColor Cyan; return }

Write-Host "Telemetry loop active (Ctrl+C to exit)" -ForegroundColor Yellow
$start = Get-Date
while ($true) {
    if ($TimeoutSeconds -gt 0) {
        $elapsed = (Get-Date) - $start
        if ($elapsed.TotalSeconds -ge $TimeoutSeconds) { Write-Host "Telemetry timeout reached; exiting." -ForegroundColor Cyan; break }
    }
    $vramRaw = (nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits) 2>$null
    $tempRaw = (nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits) 2>$null
    $vram = if ($vramRaw) { [int]$vramRaw } else { 0 }
    $temp = if ($tempRaw) { [int]$tempRaw } else { 0 }

    if ($AutoDisableOnHighLoad -and -not $NoTelemetry) {
        if ($vram -ge $VramThresholdMB -or $temp -ge $TempThresholdC) {
            $reason = "Auto-disabled telemetry: vram=${vram}MB temp=${temp}C"
            Write-Host $reason -ForegroundColor Yellow
            try { "$((Get-Date).ToString('o')) TELEMETRY_DISABLED $reason" | Out-File -FilePath $markerFile -Encoding UTF8 -Append } catch { }
            break
        }
    }

    $payload = @{
        gpu_vram_used = $vram
        gpu_temp = $temp
        status = "Coding"
    } | ConvertTo-Json -Compress

    Write-Host "`rVRAM: $vram MB | Temp: $temp C " -NoNewline
    Start-Sleep -Seconds 10
}
param(
    [switch]$DryRun,
    [int]$TimeoutSeconds = 0,
    [switch]$NoTelemetry,
    [switch]$AutoDisableOnHighLoad,
    [int]$VramThresholdMB = 12000,
    [int]$TempThresholdC = 85
)

Write-Host "--- Avvio Ambiente AI Ibrido (3090 + HA) ---" -ForegroundColor Cyan

# Safety: PID/marker management
$toolDir = Join-Path -Path (Get-Location) -ChildPath '.continue\tool'
$pidFile = Join-Path $toolDir 'ai_env.pid'
$markerFile = Join-Path $toolDir 'ai_env.marker'
if (Test-Path $pidFile) {
    try {
        $oldPid = Get-Content $pidFile -ErrorAction SilentlyContinue
        if ($oldPid -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
            Write-Host "AI environment already appears running (PID=$oldPid). Use Stop-AI-Env or remove $pidFile to force." -ForegroundColor Yellow
            return
        } else {
            Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
        }
    } catch { }
}

if ($DryRun) { Write-Host "Dry-run: would start Ollama and VS Code, and telemetry (if enabled)." -ForegroundColor Yellow; return }

# 1. Avvia Ollama se non attivo
if (!(Get-Process "ollama" -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath "ollama" -ArgumentList "app"
    Start-Sleep -Seconds 2
}

# 2. Avvia VS Code
Start-Process -FilePath "code"

# record our PID and marker
try { Set-Content -Path $pidFile -Value $PID -Encoding ASCII -Force } catch { }
try { "$((Get-Date).ToString('o')) STARTED" | Out-File -FilePath $markerFile -Encoding UTF8 -Append } catch { }

if ($NoTelemetry) { Write-Host 'Telemetry disabled for this run.' -ForegroundColor Cyan; return }

# 3. Loop di Monitoraggio Telemetria (MQTT per Home Assistant)
Write-Host "Invio dati a Home Assistant attivo... (Ctrl+C per uscire)" -ForegroundColor Yellow
$start = Get-Date
while ($true) {
    if ($TimeoutSeconds -gt 0) {
        $elapsed = (Get-Date) - $start
        if ($elapsed.TotalSeconds -ge $TimeoutSeconds) { Write-Host "Telemetry timeout reached; exiting." -ForegroundColor Cyan; break }
    }
    $vramRaw = (nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits) 2>$null
    $tempRaw = (nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits) 2>$null
    $vram = if ($vramRaw) { [int]$vramRaw } else { 0 }
    $temp = if ($tempRaw) { [int]$tempRaw } else { 0 }

    # Auto-disable telemetry if enabled and we've been asked to monitor for high load
    if ($AutoDisableOnHighLoad -and -not $NoTelemetry) {
        if ($vram -ge $VramThresholdMB -or $temp -ge $TempThresholdC) {
            $reason = "Auto-disabled telemetry: vram=${vram}MB temp=${temp}C (thresholds vram=${VramThresholdMB}MB temp=${TempThresholdC}C)"
            Write-Host $reason -ForegroundColor Yellow
            try { "$((Get-Date).ToString('o')) TELEMETRY_DISABLED $reason" | Out-File -FilePath $markerFile -Encoding UTF8 -Append } catch { }
            break
        }
    }

    $payload = @{
        gpu_vram_used = $vram
        gpu_temp = $temp
        status = "Coding"
    } | ConvertTo-Json -Compress

    # Optionally publish to MQTT if configured (commented by default)
    # & "C:\Program Files\mosquitto\mosquitto_pub.exe" -h INDIRIZZO_IP_HA -t "pc/ai/telemetry" -m $payload

    Write-Host "`rVRAM: $vram MB | Temp: $temp C " -NoNewline
    Start-Sleep -Seconds 10
}
param(
    [switch]$DryRun,
    [int]$TimeoutSeconds = 0,
    [switch]$NoTelemetry,
    [switch]$AutoDisableOnHighLoad,
    [int]$VramThresholdMB = 12000,
    [int]$TempThresholdC = 85
)

Write-Host "--- Avvio Ambiente AI Ibrido (3090 + HA) ---" -ForegroundColor Cyan

# Safety: PID/marker management
$toolDir = Join-Path -Path (Get-Location) -ChildPath '.continue\tool'
$pidFile = Join-Path $toolDir 'ai_env.pid'
$markerFile = Join-Path $toolDir 'ai_env.marker'
if (Test-Path $pidFile) {
    try {
        $oldPid = Get-Content $pidFile -ErrorAction SilentlyContinue
        if ($oldPid -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
            Write-Host "AI environment already appears running (PID=$oldPid). Use Stop-AI-Env or remove $pidFile to force." -ForegroundColor Yellow
            return
        } else {
            Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
        }
    } catch { }
}

if ($DryRun) { Write-Host "Dry-run: would start Ollama and VS Code, and telemetry (if enabled)." -ForegroundColor Yellow; return }

# 1. Avvia Ollama se non attivo
if (!(Get-Process "ollama" -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath "ollama" -ArgumentList "app"
    Start-Sleep -Seconds 2
}

# 2. Avvia VS Code
Start-Process -FilePath "code"

# record our PID and marker
try { Set-Content -Path $pidFile -Value $PID -Encoding ASCII -Force } catch { }
try { "$((Get-Date).ToString('o')) STARTED" | Out-File -FilePath $markerFile -Encoding UTF8 -Append } catch { }

if ($NoTelemetry) { Write-Host 'Telemetry disabled for this run.' -ForegroundColor Cyan; return }

# 3. Loop di Monitoraggio Telemetria (MQTT per Home Assistant)
Write-Host "Invio dati a Home Assistant attivo... (Ctrl+C per uscire)" -ForegroundColor Yellow
$start = Get-Date
while ($true) {
    if ($TimeoutSeconds -gt 0) {
        $elapsed = (Get-Date) - $start
        if ($elapsed.TotalSeconds -ge $TimeoutSeconds) { Write-Host "Telemetry timeout reached; exiting." -ForegroundColor Cyan; break }
    }
    $vramRaw = (nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits) 2>$null
    $tempRaw = (nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits) 2>$null
    $vram = if ($vramRaw) { [int]$vramRaw } else { 0 }
    $temp = if ($tempRaw) { [int]$tempRaw } else { 0 }

    # Auto-disable telemetry if enabled and we've been asked to monitor for high load
    if ($AutoDisableOnHighLoad -and -not $NoTelemetry) {
        if ($vram -ge $VramThresholdMB -or $temp -ge $TempThresholdC) {
            $reason = "Auto-disabled telemetry: vram=${vram}MB temp=${temp}C (thresholds vram=${VramThresholdMB}MB temp=${TempThresholdC}C)"
            Write-Host $reason -ForegroundColor Yellow
            try { "$((Get-Date).ToString('o')) TELEMETRY_DISABLED $reason" | Out-File -FilePath $markerFile -Encoding UTF8 -Append } catch { }
            break
        }
    }

    $payload = @{
        gpu_vram_used = $vram
        gpu_temp = $temp
        status = "Coding"
    } | ConvertTo-Json -Compress

    # Optionally publish to MQTT if configured (commented by default)
    # & "C:\Program Files\mosquitto\mosquitto_pub.exe" -h INDIRIZZO_IP_HA -t "pc/ai/telemetry" -m $payload

    Write-Host "`rVRAM: $vram MB | Temp: $temp C " -NoNewline
    Start-Sleep -Seconds 10
}
