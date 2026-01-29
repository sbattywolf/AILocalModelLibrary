<#
Locate a Python executable and install git-filter-repo via pip (--user).
Attempts common install locations and falls back to `where.exe python`.
Exits 0 on success, non-zero on failure.
#>
Write-Host 'Locating python executable...'
$searchPaths = @(
  "$env:LOCALAPPDATA\Programs\Python",
  "C:\\Program Files\\Python*",
  "C:\\Program Files (x86)\\Python*",
  "$env:ProgramFiles\\Python*",
  "$env:USERPROFILE\\AppData\\Local\\Programs\\Python"
)
$pythonExe = $null
foreach ($p in $searchPaths) {
  try {
    $found = Get-ChildItem -Path $p -Filter python.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $pythonExe = $found.FullName; break }
  } catch {}
}

if (-not $pythonExe) {
  Write-Host 'Falling back to where.exe for python...'
  try { $where = & where.exe python 2>$null | Select-Object -First 1 } catch { $where = $null }
  if ($where) { $pythonExe = $where.Trim() }
}

if (-not $pythonExe) {
  Write-Error 'Python executable not found. Ensure you restarted the shell after install or provide path via -PythonPath.'
  exit 2
}

Write-Host "Using python at: $pythonExe"
Write-Host 'Installing git-filter-repo via pip (user scope)...'
try {
  & $pythonExe -m pip install --user --upgrade git-filter-repo | Out-Host
  $rc = $LASTEXITCODE
} catch {
  Write-Error "pip install failed: $_"
  exit 3
}

if ($rc -ne 0) {
  Write-Error "pip exited with $rc"
  exit $rc
}

Write-Host 'git-filter-repo installed (user scope). You may need to add the user Scripts folder to PATH.'
# Common user scripts path
$pyver = & $pythonExe -c "import sys; print('{}.{}'.format(sys.version_info.major, sys.version_info.minor))" 2>$null
$pythonUserScripts = Join-Path $env:USERPROFILE "AppData\Roaming\Python\$pyver\Scripts"
Write-Host "Suggested PATH addition: $pythonUserScripts"
exit 0
