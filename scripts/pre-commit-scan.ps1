# Wrapper that runs the repo secret scanner and exits non-zero on findings
$scanner = Join-Path (Get-Location) 'scripts\scan-secrets.ps1'
if (-not (Test-Path $scanner)) {
  Write-Host "No scan script found at $scanner — skipping pre-commit scan.";
  exit 0
}

# Run the scanner in a separate PowerShell process for consistent output
$proc = Start-Process -FilePath powershell.exe -ArgumentList ('-NoProfile','-ExecutionPolicy','Bypass','-File',"$scanner") -NoNewWindow -Wait -PassThru -RedirectStandardOutput -RedirectStandardError
# If redirected streams not supported, fall back
if ($proc -and $null -ne $proc.ExitCode) {
  $rc = $proc.ExitCode
} else {
  # fallback: run inline
  & powershell -NoProfile -ExecutionPolicy Bypass -File $scanner
  $rc = $LASTEXITCODE
}

if ($rc -ne 0) {
  Write-Error "Pre-commit secret scan failed (exit $rc). Commit aborted."
  exit $rc
}
Write-Host 'Pre-commit secret scan passed.'
exit 0
#!/usr/bin/env powershell
# Wrapper that runs the repo secret scanner and exits non-zero on findings
$scanner = Join-Path (Get-Location) 'scripts\scan-secrets.ps1'
if (-not (Test-Path $scanner)) {
  Write-Host "No scan script found at $scanner — skipping pre-commit scan."
  exit 0
}

# Run the scanner inline (PS5.1-safe) and check the exit code
& powershell -NoProfile -ExecutionPolicy Bypass -File $scanner
$rc = $LASTEXITCODE

if ($rc -ne 0) {
  Write-Error "Pre-commit secret scan failed (exit $rc). Commit aborted."
  exit $rc
}
Write-Host 'Pre-commit secret scan passed.'
exit 0
