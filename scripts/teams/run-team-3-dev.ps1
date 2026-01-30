param(
  [string]$TeamFile = '.continue/teams/team-3-dev.json',
  [int]$MaxParallel = 3,
  [int]$MaxVramGB = 32
)

function Write-Log { param($m) $t=(Get-Date).ToString('s'); "$t`t$m" | Write-Host }

if (-not (Test-Path $TeamFile)) { Write-Log "Team file not found: $TeamFile"; exit 2 }

$repo = Get-Location
$origPath = Join-Path $repo '.continue/config.agent'
$bakPath = Join-Path $repo '.continue/config.agent.bak'

if (Test-Path $origPath) { Copy-Item -Path $origPath -Destination $bakPath -Force; Write-Log "Backed up original config to $bakPath" }

$orig = $null
try { if (Test-Path $origPath) { $orig = Get-Content $origPath -Raw | ConvertFrom-Json } } catch { $orig = $null }

$team = Get-Content $TeamFile -Raw | ConvertFrom-Json

# Build new config: prefer original preference if available
$pref = $null
if ($orig -and $orig.preference) { $pref = $orig.preference } else { $pref = @{ priority = 'accuracy' } }
$newCfg = @{ preference = $pref; agents = @(); default = $team.members[0].agent }

foreach ($m in $team.members) {
  $found = $null
  if ($orig -and $orig.agents) { $found = $orig.agents | Where-Object { $_.name -eq $m.agent } | Select-Object -First 1 }
  if ($found) { $newCfg.agents += $found } else {
    $newCfg.agents += [PSCustomObject]@{
      name = $m.agent
      type = 'local-model'
      entry = '.continue/python/agent_runner.py'
      description = "$($m.role) (auto-generated)"
      options = @{ model = $m.model; mode = 'local' }
      quality = 'medium'
    }
  }
}

$teamCfgPath = '.continue/config.agent'
$newCfg | ConvertTo-Json -Depth 6 | Set-Content -Path $teamCfgPath -Encoding UTF8
Write-Log "Wrote team config to $teamCfgPath"

# Ensure logs dir exists
if (-not (Test-Path 'logs')) { New-Item -ItemType Directory -Path 'logs' | Out-Null }

Write-Log "Detecting local Python executable to pass to orchestrator"
$pyCmd = Get-Command py -ErrorAction SilentlyContinue
if (-not $pyCmd) { $pyCmd = Get-Command python -ErrorAction SilentlyContinue }
$pyPath = $null
if ($pyCmd) { $pyPath = $pyCmd.Source; Write-Log "Detected Python: $pyPath" } else { Write-Log "No Python detected; orchestrator will attempt runtime detection." }

Write-Log "Running orchestrator DryRun (MaxParallel=$MaxParallel MaxVramGB=$MaxVramGB)"
if ($pyPath) { powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-agents-epic.ps1 -DryRun -MaxParallel $MaxParallel -MaxVramGB $MaxVramGB -PythonExe $pyPath } else { powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-agents-epic.ps1 -DryRun -MaxParallel $MaxParallel -MaxVramGB $MaxVramGB }

Write-Log "Running orchestrator REAL (MaxParallel=$MaxParallel MaxVramGB=$MaxVramGB)"
if ($pyPath) { powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-agents-epic.ps1 -MaxParallel $MaxParallel -MaxVramGB $MaxVramGB -PythonExe $pyPath } else { powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-agents-epic.ps1 -MaxParallel $MaxParallel -MaxVramGB $MaxVramGB }

Write-Log "Restoring original config"
if (Test-Path $bakPath) { Move-Item -Path $bakPath -Destination $origPath -Force; Write-Log "Restored original config from $bakPath" } else { Write-Log "No backup found; leaving team config in place" }

Write-Log "Done"
exit 0
