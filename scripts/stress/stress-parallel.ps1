<#
.SYNOPSIS
  Stress-test orchestrator with parallel combinations and increasing load.

.DESCRIPTION
  Generates a temporary `.continue/config.agent` containing many duplicate
  lightweight agents, then invokes `scripts/run-agents-epic.ps1` in DryRun
  (or real run if `-Run` is supplied) across a matrix of `MaxParallel` and
  `MaxVramGB` values. Captures logs and produces a JSON summary.

.PARAMETER Copies
  Number of duplicate agents to generate (default 20).

.PARAMETER MaxParallelList
  Array of MaxParallel values to test. Default: 1,3,5.

.PARAMETER MaxVramList
  Array of MaxVramGB values to test. Default: 8,16,32.

.PARAMETER Run
  If supplied, actually start agents (NOT recommended without verification).

#>
param(
  [int]$Copies = 20,
  [int[]]$MaxParallelList = @(1,3,5),
  [int[]]$MaxVramList = @(8,16,32),
  [switch]$Run
)

function Write-Log { param($m) $t=(Get-Date).ToString('s'); "$t`t$m" | Write-Host }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repoRoot = Resolve-Path (Join-Path $scriptDir '..\..')
Set-Location $repoRoot

$origCfg = Join-Path $repoRoot '.continue\config.agent'
if (-not (Test-Path $origCfg)) { Write-Log "Original config not found: $origCfg"; exit 2 }

$outDir = Join-Path $repoRoot 'logs\stress'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$cfg = Get-Content $origCfg -Raw | ConvertFrom-Json

# Pick a small, safe agent to duplicate (prefer local-script CustomAgent)
$template = $cfg.agents | Where-Object { $_.type -eq 'local-script' } | Select-Object -First 1
if (-not $template) { $template = $cfg.agents | Select-Object -First 1 }

if (-not $template) { Write-Log "No agent template found in config.agent"; exit 2 }

$timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$summary = @()

Write-Log "Creating temporary stress config with $Copies copies of '$($template.name)'."

$stressCfgPath = '.continue/config.agent.stress.json'

$agents = @()
for ($i=1; $i -le $Copies; $i++) {
    $copy = $template | ConvertTo-Json -Depth 5 | ConvertFrom-Json
    $copy.name = "stress-$($template.name)-$i"
    # ensure logs are unique
    if (-not $copy.entry) { $copy.entry = $template.entry }
    $agents += $copy
}

$stressCfg = @{ preference = $cfg.preference; agents = $agents; default = $agents[0].name }
$stressCfg | ConvertTo-Json -Depth 6 | Set-Content -Path $stressCfgPath -Encoding UTF8

Write-Log "Stress config written to $stressCfgPath"

foreach ($mp in $MaxParallelList) {
  foreach ($mv in $MaxVramList) {
    $logFile = Join-Path $outDir "stress-MP${mp}-VR${mv}-$timestamp.log"
    $runMode = if ($Run) { '' } else { '-DryRun' }
    Write-Log "Running orchestrator: MaxParallel=$mp MaxVramGB=$mv Run=$($Run.IsPresent) -> $logFile"

    $runner = Join-Path $repoRoot 'scripts\run-agents-epic.ps1'
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$runner)
    if (-not $Run) { $args += '-DryRun' }
    $args += '-MaxParallel'; $args += $mp; $args += '-MaxVramGB'; $args += $mv

    Write-Log "Exec: powershell $($args -join ' ')"
    $errFile = "$logFile.err"
    $proc = Start-Process -FilePath powershell -ArgumentList $args -RedirectStandardOutput $logFile -RedirectStandardError $errFile -NoNewWindow -Wait -PassThru

    # Parse results: count scheduled vs queued (merge stderr if present)
    $content = @()
    if (Test-Path $logFile) { $content += Get-Content -Path $logFile -ErrorAction SilentlyContinue }
    if (Test-Path $errFile) { $content += Get-Content -Path $errFile -ErrorAction SilentlyContinue }
    $scheduled = ($content | Select-String '\[DryRun\] SCHEDULED' -SimpleMatch).Count
    $queued = ($content | Select-String '\[DryRun\] QUEUED' -SimpleMatch).Count
    $summary += [PSCustomObject]@{ MaxParallel=$mp; MaxVramGB=$mv; Scheduled=$scheduled; Queued=$queued; Log=$logFile }
  }
}

$summaryPath = Join-Path $outDir "summary-$timestamp.json"
$summary | ConvertTo-Json -Depth 5 | Set-Content -Path $summaryPath -Encoding UTF8
Write-Log "Stress test complete. Summary: $summaryPath"
Write-Log "You can inspect logs under $outDir"

# Cleanup: leave stress config in place (user may want to inspect). To restore original, delete .continue/config.agent.stress.json
exit 0
