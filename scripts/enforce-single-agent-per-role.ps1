
[CmdletBinding()]
param(
  [Parameter(Mandatory=$false)]
  [string]
  $MappingFile = '.\.continue\agents-epic.json',

  [switch]
  $DryRun,

  # Set this switch to skip enforcement for the 'coordinator' role.
  # Default behavior enforces coordinators (tests expect enforcement).
  [switch]
  $SkipCoordinator
)

function Read-Mapping {
  param([string]$path)
  if (-not (Test-Path $path)) { return @() }
  try {
    $raw = Get-Content -Path $path -Raw -ErrorAction Stop
    $parsed = $raw | ConvertFrom-Json
    if ($parsed -is [System.Collections.IEnumerable]) { return $parsed } else { return @($parsed) }
  } catch { return @() }
}

function Is-ProcessAlive {
  param([int]$checkPid)
  if (-not $checkPid) { return $false }
  try { Get-Process -Id $checkPid -ErrorAction Stop | Out-Null; return $true } catch { return $false }
}

try {
  $agents = Read-Mapping -path $MappingFile
  if (-not $agents -or $agents.Count -eq 0) { exit 0 }

  $groups = $agents | Group-Object -Property primaryRole
  foreach ($g in $groups) {
    $role = $g.Name
    if (-not $role) { continue }
    if ($role -eq 'coordinator' -and $SkipCoordinator) { continue }

    $alive = @()
    foreach ($entry in $g.Group) { if ($entry.pid -and (Is-ProcessAlive -checkPid $entry.pid)) { $alive += $entry } }
    if ($alive.Count -gt 1) {
      Write-Output ("[Enforcer] Multiple instances for role {0} detected: {1}. Enforcing single instance." -f $role, $alive.Count)
      # prefer lowest priority from mapping if present, else earliest startedAt
      # build a modifiable copy of alive entries with an explicit priority field
      $meta = @()
      foreach ($e in $alive) {
        $h = @{}
        foreach ($prop in $e.PSObject.Properties) { $h[$prop.Name] = $prop.Value }
        $p = 99
        try { if ($h.priority) { $p = ($h.priority -as [int]) } } catch { }
        $h.priority = $p
        $meta += (New-Object PSObject -Property $h)
      }
      $keep = $meta | Sort-Object -Property priority, startedAt | Select-Object -First 1
      foreach ($a in $alive) {
        $keepPid = $keep.pid
        if ($a.pid -ne $keepPid) {
          Write-Output ("[Enforcer] Stopping extra {0} (role {1}) pid {2}" -f $a.name, $role, $a.pid)
          if (-not $DryRun) { Try { Stop-Process -Id $a.pid -Force -ErrorAction Stop } Catch { Write-Output ("[Enforcer] Failed to stop {0}: {1}" -f $a.name, $_.Exception.Message) } }
          try {
            $nm = Read-Mapping -path $MappingFile
            # Build a fresh, plain-hashtable array for atomic rewrite (avoids mutating read-only PSObjects)
            $out = @()
            foreach ($na in $nm) {
              $h = [ordered]@{}
              foreach ($prop in $na.PSObject.Properties) { $h[$prop.Name] = $prop.Value }
              # Prefer matching by PID when available to avoid name collisions during concurrent tests
              $matchByPid = $false
              try { if ($na.pid -and $a.pid -and ($na.pid -eq $a.pid)) { $matchByPid = $true } } catch { }
              if ($matchByPid -or ($na.name -eq $a.name)) {
                $h.pid = $null
                $h.status = 'stopped'
              }
              $out += $h
            }

            $rp = Resolve-Path -Path $MappingFile -ErrorAction SilentlyContinue
            if ($rp) { $mappingPath = $rp.Path } else { $mappingPath = Join-Path (Get-Location) $MappingFile }
            $mappingDir = Split-Path -Parent $mappingPath
            if (-not (Test-Path $mappingDir)) { New-Item -ItemType Directory -Path $mappingDir -Force | Out-Null }
            $tmp = Join-Path $mappingDir ([System.IO.Path]::GetRandomFileName() + '.json')

            $json = $out | ConvertTo-Json -Depth 10
            $maxAttempts = 5
            $attempt = 0
            $written = $false
            while (-not $written -and $attempt -lt $maxAttempts) {
              try {
                $attempt++
                $json | Set-Content -Path $tmp -Encoding UTF8 -Force
                Move-Item -Path $tmp -Destination $mappingPath -Force
                Start-Sleep -Milliseconds 50
                $written = $true
                # maintain pid->agent sidecar files for easier test/process lookup
                try {
                  $pids = @()
                  foreach ($it in $out) { if ($it.pid) { $pids += [string]$it.pid } }
                  $sideFiles = Get-ChildItem -Path $mappingDir -Filter 'pid-*.agent' -File -ErrorAction SilentlyContinue
                  foreach ($f in $sideFiles) {
                    $base = $f.BaseName -replace '^pid-',''
                    if ($pids -notcontains $base) { Remove-Item -Path $f.FullName -Force -ErrorAction SilentlyContinue }
                  }
                  foreach ($it in $out) {
                    if ($it.pid) {
                      $fn = Join-Path $mappingDir (('pid-{0}.agent' -f $it.pid))
                      $it.name | Out-File -FilePath $fn -Encoding UTF8 -Force
                    }
                  }
                } catch { }
              } catch {
                Write-Output (("[Enforcer] Mapping write attempt {0} failed: {1}" -f $attempt, $_.Exception.Message))
                Start-Sleep -Milliseconds (200 * $attempt)
              }
            }
            if (-not $written) { Write-Output (("[Enforcer] Failed to update mapping after stopping {0} after {1} attempts." -f $a.name, $maxAttempts)) }
          } catch { Write-Output ("[Enforcer] Failed to update mapping after stopping {0}: {1}" -f $a.name, $_) }
        }
      }
    }
  }
} catch { Write-Output ("[Enforcer] Exception: {0}" -f $_) }
