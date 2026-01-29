<#
.SYNOPSIS
  Workspace cleanup helper (safe, DryRun by default).

.DESCRIPTION
  Removes transient test artifacts under `.continue` and other temp files
  produced during local runs. Runs in DryRun mode unless `-Apply` is supplied.
#>
param(
  [switch]$Apply,
  [switch]$Verbose
)

$targets = @(
  '.\.continue\tempTest',
  '.\.continue\traces.zip',
  '.\.continue\TestRunner-output.txt',
  '.\.continue\install-trace.log'
)

Write-Host "Cleanup helper. Apply=$Apply" -ForegroundColor Cyan

foreach ($t in $targets) {
  if (Test-Path $t) {
    if ($Apply) {
      if (Test-Path $t -PathType Container) { Remove-Item -Recurse -Force -LiteralPath $t ; Write-Host "Removed folder: $t" }
      else { Remove-Item -Force -LiteralPath $t ; Write-Host "Removed file: $t" }
    } else {
      Write-Host "Would remove: $t"
    }
  } else {
    if ($Verbose) { Write-Host "Not found: $t" }
  }
}

Write-Host "Cleanup preview complete. To apply, re-run with -Apply." -ForegroundColor Green
