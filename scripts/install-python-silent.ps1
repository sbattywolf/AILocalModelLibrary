<#
install-python-silent.ps1

Downloads the official Python Windows installer from python.org and runs it
silently with common silent flags. Designed for PS5.1. Use -Version to select
installer (default 3.11.5). Will retry on failure up to -RetryCount.

USAGE (run from repo root):
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-python-silent.ps1

NOTE: Running the installer requires elevation to install for all users. The
script will attempt to elevate when needed and will exit with non-zero on failure.
#>
param(
  [string]$Version = '3.11.5',
  [int]$RetryCount = 2,
  [switch]$InstallAllUsers = $true,
  [switch]$PrependPath = $true
)

function Join-Args {
  param([string[]]$Parts)
  return ($Parts -join ' ')
}

$arch = if ([Environment]::Is64BitOperatingSystem) { 'amd64' } else { 'win32' }
$installerName = "python-$Version-$arch.exe"
$installerUrl = "https://www.python.org/ftp/python/$Version/$installerName"
$tempDir = [System.IO.Path]::GetTempPath()
$installerPath = Join-Path $tempDir $installerName

Write-Host "Installer URL: $installerUrl"
Write-Host "Downloading to: $installerPath"

$attempt = 0
$lastExit = 1
while ($attempt -le $RetryCount) {
  try {
    $attempt++
    Write-Host "Attempt $attempt of $($RetryCount + 1): downloading..."
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing -ErrorAction Stop
    Write-Host 'Download complete.'

    # Build installer args
    $args = @()
    if ($InstallAllUsers) { $args += 'InstallAllUsers=1' }
    if ($PrependPath) { $args += 'PrependPath=1' }
    $args += 'Include_pip=1'

    $argString = '/quiet ' + (Join-Args -Parts $args)

    Write-Host "Running installer: $installerPath $argString (requires elevation)"

    $proc = Start-Process -FilePath $installerPath -ArgumentList $argString -Verb RunAs -Wait -PassThru
    $lastExit = $proc.ExitCode
    Write-Host "Installer exit code: $lastExit"

    if ($lastExit -eq 0) {
      Write-Host 'Installer reported success. Verifying python is on PATH...'
      Start-Sleep -Seconds 2
      $py = Get-Command python -ErrorAction SilentlyContinue
      if ($py) {
        Write-Host "Python found: $($py.Source)"
        exit 0
      } else {
        Write-Host 'Python binary not found in PATH after install. You may need to restart your shell.'
        exit 0
      }
    } else {
      Write-Host "Installer returned non-zero: $lastExit"
    }
  } catch {
    Write-Host "Installer attempt failed: $_"
  }

  if ($attempt -le $RetryCount) {
    Write-Host 'Retrying after 3 seconds...'
    Start-Sleep -Seconds 3
  }
}

Write-Error "All installer attempts failed (last exit $lastExit)."
exit 1
