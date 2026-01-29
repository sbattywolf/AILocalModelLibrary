param(
    [object]$DryRun = $true,
    [object]$Yes = $false
)

function Normalize-Bool($v) {
    if ($v -is [System.Management.Automation.SwitchParameter]) { return [bool]$v.IsPresent }
    return [bool]$v
}

$DryRun = Normalize-Bool $DryRun
$Yes = Normalize-Bool $Yes

Write-Host "Preparing to pull recommended models (DryRun=$DryRun)" -ForegroundColor Cyan

# Check free disk space on repo drive
try {
    $root = (Get-Location).Path
    $driveRoot = [System.IO.Path]::GetPathRoot($root).TrimEnd('\')
    $drive = Get-PSDrive -Name $driveRoot -ErrorAction SilentlyContinue
    $freeBytes = if ($drive) { $drive.Free } else { 0 }
} catch { $freeBytes = 0 }

$minBytes = 20GB
if ($freeBytes -and ($freeBytes -lt $minBytes) -and -not $Yes) {
    Write-Host "Warning: free disk space on drive $driveRoot is low ($([math]::Round($freeBytes/1GB,1)) GB)." -ForegroundColor Yellow
    $response = Read-Host "Proceed with model download? (y/N)"
    if ($response -notin @('y','Y')) { Write-Host 'Aborted by user.' -ForegroundColor Yellow; return }
}

if ($DryRun) {
    Write-Host "Dry-run: would run ollama pull qwen2.5-coder:32b, deepseek-r1:14b, qwen2.5-coder:1.5b" -ForegroundColor Yellow
    return
}

if (-not (Get-Command -Name 'ollama' -ErrorAction SilentlyContinue)) {
    Write-Error 'ollama not found in PATH. Install Ollama and re-run.'; exit 4
}

ollama pull qwen2.5-coder:32b  # flagship
ollama pull deepseek-r1:14b    # coach/ragionamento
ollama pull qwen2.5-coder:1.5b # fast autocomplete
Write-Host "Models pulled." -ForegroundColor Green
Write-Host "Models pulled." -ForegroundColor Green
param(
    [object]$DryRun = $true,
    [object]$Yes = $false
)

function Normalize-Bool($v) {
    if ($v -is [System.Management.Automation.SwitchParameter]) { return [bool]$v.IsPresent }
    return [bool]$v
}

$DryRun = Normalize-Bool $DryRun
$Yes = Normalize-Bool $Yes

Write-Host "Preparing to pull recommended models (DryRun=$DryRun)" -ForegroundColor Cyan

# Check free disk space on repo drive
try {
    $root = (Get-Location).Path
    $driveRoot = [System.IO.Path]::GetPathRoot($root).TrimEnd('\')
    $drive = Get-PSDrive -Name $driveRoot -ErrorAction SilentlyContinue
    $freeBytes = if ($drive) { $drive.Free } else { 0 }
} catch { $freeBytes = 0 }

$minBytes = 20GB
if ($freeBytes -and ($freeBytes -lt $minBytes) -and -not $Yes) {
    Write-Host "Warning: free disk space on drive $driveRoot is low ($([math]::Round($freeBytes/1GB,1)) GB)." -ForegroundColor Yellow
    $response = Read-Host "Proceed with model download? (y/N)"
    if ($response -notin @('y','Y')) { Write-Host 'Aborted by user.' -ForegroundColor Yellow; return }
}

if ($DryRun) {
    Write-Host "Dry-run: would run ollama pull qwen2.5-coder:32b, deepseek-r1:14b, qwen2.5-coder:1.5b" -ForegroundColor Yellow
    return
}

if (-not (Get-Command -Name 'ollama' -ErrorAction SilentlyContinue)) {
    Write-Error 'ollama not found in PATH. Install Ollama and re-run.'; exit 4
}

ollama pull qwen2.5-coder:32b  # flagship
ollama pull deepseek-r1:14b    # coach/ragionamento
ollama pull qwen2.5-coder:1.5b # fast autocomplete
Write-Host "Models pulled." -ForegroundColor Green
param(
	[switch]$Yes,
	[switch]$DryRun
)

Write-Host "Scaricamento modelli ottimizzati per RTX 3090..." -ForegroundColor Cyan

# Check free disk space on repo drive
$root = (Get-Location).Path
$driveRoot = [System.IO.Path]::GetPathRoot($root).TrimEnd('\')
try {
	$drive = Get-PSDrive -Name $driveRoot -ErrorAction SilentlyContinue
	$freeBytes = $drive.Free
} catch {
	$freeBytes = 0
}
$minBytes = 20GB
if ($freeBytes -and ($freeBytes -lt $minBytes) -and -not $Yes) {
	Write-Host "Warning: free disk space on drive $driveRoot is low ($([math]::Round($freeBytes/1GB,1)) GB)." -ForegroundColor Yellow
	$response = Read-Host "Proceed with model download? (y/N)"
	if ($response -notin @('y','Y')) { Write-Host 'Aborted by user.' -ForegroundColor Yellow; return }
}

if ($DryRun) {
	Write-Host "Dry-run: would run ollama pull qwen2.5-coder:32b, deepseek-r1:14b, qwen2.5-coder:1.5b" -ForegroundColor Yellow
	return
}

ollama pull qwen2.5-coder:32b  # Modello di punta per precisione
ollama pull deepseek-r1:14b    # Modello Coach/Ragionamento
ollama pull qwen2.5-coder:1.5b # Modello ultra-veloce per Autocomplete
Write-Host "Modelli pronti." -ForegroundColor Green
