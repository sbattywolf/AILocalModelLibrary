<#
Relocate Ollama models directory to a new location and create a junction.
Usage: .\relocate-ollama-models.ps1
Requires: PowerShell run from an account that can stop processes and create junctions (admin or Developer Mode).
#>

try {
    $src = Join-Path $env:USERPROFILE '.ollama\models'
} catch {
    Write-Error "Failed to compute source path: $_"
    exit 2
}

if (-not (Test-Path $src)) {
    Write-Host "Source path not found: $src"; exit 3
}

$dstRoot = 'E:\llm-models\.ollama'
$dst = Join-Path $dstRoot 'models'

Write-Host "Relocate Ollama models: src=$src dst=$dst"

if (Test-Path $dst) {
    $bak = $dst + '-backup-' + (Get-Date -Format yyyyMMddHHmmss)
    Write-Host "Destination exists; moving existing to: $bak"
    try { Move-Item -LiteralPath $dst -Destination $bak -Force } catch { Write-Warning "Failed to move existing dest: $_"; exit 4 }
}

Write-Host "Stopping Ollama processes (if running)..."
Stop-Process -Name ollama -ErrorAction SilentlyContinue

try {
    New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null
} catch {
    Write-Error "Failed to create destination parent dir: $_"; exit 5
}

Write-Host "Moving $src -> $dst"
try {
    Move-Item -LiteralPath $src -Destination $dst -Force
} catch {
    Write-Error "Move failed: $_"; exit 6
}

Write-Host "Creating junction at original location pointing to new location"
try {
    $cmd = "cmd /c mklink /J `"$src`" `"$dst`""
    $proc = Start-Process -FilePath cmd -ArgumentList "/c mklink /J `"$src`" `"$dst`"" -NoNewWindow -Wait -PassThru -WindowStyle Hidden
    if ($proc.ExitCode -ne 0) { Write-Warning "mklink returned exit code $($proc.ExitCode). You may need elevation to create junctions."; exit 7 }
} catch {
    Write-Warning "Failed to create junction: $_"; exit 7
}

Write-Host "Verifying junction target contents (first 8 items):"
Get-ChildItem -Path $src -Force -ErrorAction SilentlyContinue | Select-Object -First 8 | Format-List

Write-Host "Relocation complete. If Ollama was running, restart it now."
exit 0
