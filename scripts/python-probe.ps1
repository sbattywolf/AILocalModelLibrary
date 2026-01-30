$py = 'C:\Program Files\Python311\python.exe'
Write-Host "Using Python: $py"
try {
    & $py --version
} catch {
    Write-Host "Error running python: $_"
    exit 1
}

$pipExists = $false
try {
    & $py -m pip --version > $null 2>&1
    if ($LASTEXITCODE -eq 0) { $pipExists = $true }
} catch { }

if (-not $pipExists) {
    Write-Host "pip not found; attempting ensurepip"
    try { & $py -m ensurepip --default-pip } catch { Write-Host "ensurepip failed: $_" }
}

Write-Host "Installing requests and psutil for current user"
& $py -m pip install --user requests psutil

Write-Host "Verifying imports"
& $py -c "import requests, psutil; print('IMPORTS_OK')"
