<#
.SYNOPSIS
  Stop local-llama processes recorded in .continue/local-llama-processes.json by Role or PID.
#>
param(
  [string]$Role,
  [int]$PidArg,
  [switch]$RemoveOnly
)

function Write-Log { param($m) $t=(Get-Date).ToString('s'); $line="$t`t$m"; Add-Content -Path '.\.continue\local-llama-trace.log' -Value $line -ErrorAction SilentlyContinue }

$mapFile = '.\.continue\local-llama-processes.json'
if (-not (Test-Path $mapFile)) { Write-Host 'No mapping file present'; exit 0 }

try {
  $raw = Get-Content -Path $mapFile -Raw -ErrorAction Stop
  if ($raw -and $raw.Trim() -ne '') { $maps = $raw | ConvertFrom-Json -ErrorAction Stop } else { $maps = @() }
} catch { Write-Log "Failed reading mapping: $_"; $maps = @() }

$stopped = @()
$remaining = @()
foreach ($m in $maps) {
  $match = $false
  if ($Role -and ($m.Role -eq $Role)) { $match = $true }
  if ($PidArg -and ($m.PID -eq $PidArg)) { $match = $true }
  if (-not $Role -and -not $PidArg) { $match = $true }

  if ($match) {
    if (-not $RemoveOnly) {
      try {
        if (Get-Process -Id $m.PID -ErrorAction SilentlyContinue) {
          Stop-Process -Id $m.PID -Force -ErrorAction SilentlyContinue
          Write-Log "Stopping PID $($m.PID) role=$($m.Role)"
        } else {
          Write-Log "PID $($m.PID) not running"
        }
      } catch { Write-Log "Failed stopping PID $($m.PID): $($_.Exception.Message)" }
    } else {
      Write-Log "RemoveOnly: removing mapping for PID $($m.PID) role=$($m.Role)"
    }
    $stopped += [PSCustomObject]@{ PID = $m.PID; Role = $m.Role; Action = 'removed' }
  } else {
    $remaining += $m
  }
}

try {
  $tmp = [System.IO.Path]::GetTempFileName()
  $remaining | ConvertTo-Json -Depth 6 | Out-File -FilePath $tmp -Encoding utf8
  Move-Item -Path $tmp -Destination $mapFile -Force
} catch { Write-Log "Failed updating mapping file: $($_ | Out-String)" }

if ($stopped.Count -gt 0) { $stopped | Format-Table PID,Role,Action }
Write-Host "Updated mapping saved to: $mapFile"
exit 0
