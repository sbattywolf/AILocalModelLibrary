<#
Search for python.exe in common locations and attempt to install git-filter-repo via pip for each candidate.
Exits 0 on success, non-zero otherwise. Prints diagnostics.
#>
Write-Host 'Collecting python.exe candidates...'
$candidates = @()
# where.exe
try { $where = & where.exe python 2>$null } catch { $where = $null }
if ($where) { $candidates += $where }
# Common program files roots
$roots = @('C:\Program Files','C:\Program Files (x86)', "$env:USERPROFILE\AppData\Local\Programs\Python")
foreach ($r in $roots) {
  try {
    $found = Get-ChildItem -Path $r -Filter python.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName -First 20
    if ($found) { $candidates += $found }
  } catch {}
}
# Also search top-level Python directories
try {
  $top = Get-ChildItem 'C:\' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'Python*' } | ForEach-Object { Get-ChildItem -Path $_.FullName -Filter python.exe -Recurse -ErrorAction SilentlyContinue } | Select-Object -ExpandProperty FullName
  if ($top) { $candidates += $top }
} catch {}

$candidates = $candidates | Where-Object { $_ } | Sort-Object -Unique
if (-not $candidates) { Write-Error 'No python.exe candidates found.'; exit 2 }

Write-Host "Found candidates:`n$($candidates -join "`n")"

foreach ($py in $candidates) {
  Write-Host "\nTrying candidate: $py"
  # If path looks like venv inner path, try to prefer parent python.exe if exists
  if ($py -match '\\Lib\\venv\\scripts\\nt\\python.exe') {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $py)))
    $alt = Join-Path $root 'python.exe'
    if (Test-Path $alt) { Write-Host "Found parent python.exe at $alt; will try that too."; $py = $alt }
  }
  try {
    Write-Host "Running: $py -m pip install --user --upgrade git-filter-repo"
    & $py -m pip install --user --upgrade git-filter-repo | Out-Host
    $rc = $LASTEXITCODE
  } catch {
    Write-Host "Command failed: $_"
    $rc = 1
  }
  if ($rc -eq 0) { Write-Host 'git-filter-repo installed successfully.'; exit 0 }
  else { Write-Host "Candidate failed with exit code $rc" }
}
Write-Error 'All candidates failed to install git-filter-repo.'
exit 3
