<#
.SYNOPSIS
  Install 7-Zip via winget with a safe DryRun mode and logging.

.PARAMETER Apply
  If supplied, actually run the install. Otherwise only preview steps.

.PARAMETER TracePath
  File path to append logs to.
#>
param(
  [switch]$Apply,
  [string]$TracePath = '.continue/install-trace.log'
)

function Write-Trace { param([string]$m) $line = "[$((Get-Date).ToString('o'))] $m"; try { Add-Content -Path $TracePath -Value $line -Encoding utf8 -ErrorAction SilentlyContinue } catch {}; Write-Host $m -ForegroundColor Cyan }

Write-Trace "install-7zip-winget: starting (Apply=$Apply)"

# Check winget
$winget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $winget) { Write-Trace "winget not found on PATH. Please install App Installer / winget or use Chocolatey. Aborting."; exit 2 }
Write-Trace "winget found: $($winget.Path)"

# Check existing 7z
$seven = Get-Command 7z -ErrorAction SilentlyContinue
if ($seven) { Write-Trace "7z already available: $($seven.Path). Nothing to do."; exit 0 }

# Preview install command
$pkgId = '7zip.7zip'
$cmd = "winget install --id $pkgId -e --accept-source-agreements --accept-package-agreements"
Write-Trace "Planned install command: $cmd"

if (-not $Apply) { Write-Trace "DryRun: not executing. Re-run with -Apply to install."; exit 0 }

# Execute install
try {
  Write-Trace "Running: $cmd"
  $proc = Start-Process -FilePath winget -ArgumentList @('install','--id',$pkgId,'-e','--accept-source-agreements','--accept-package-agreements') -NoNewWindow -Wait -PassThru
  if ($proc.ExitCode -ne 0) { Write-Trace "winget install failed (exit $($proc.ExitCode))"; exit 3 }
  Write-Trace "winget install succeeded"
} catch {
  Write-Trace "Exception during winget install: $($_.Exception.Message)"; exit 4
}

# Verify
$seven = Get-Command 7z -ErrorAction SilentlyContinue
if ($seven) { Write-Trace "7z installed at $($seven.Path)"; exit 0 } else { Write-Trace "7z not found after install." ; exit 5 }
