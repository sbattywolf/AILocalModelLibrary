param(
  [switch]$DryRun,
  [switch]$Notify,
  [string]$ModelsFile = ".continue/models.json",
  [string]$Config = ".continue/config.agent",
  [string]$Out = ".continue/model_updates.json"
)

# Simple, robust model update check (dry-run friendly).
function Collect-Models {
  param([string]$modelsFile, [string]$configFile)
  $list = @()
  if (Test-Path $modelsFile) {
    try { $m = Get-Content $modelsFile -Raw | ConvertFrom-Json } catch { $m = $null }
    if ($m) {
      if ($m -is [System.Array]) { foreach ($e in $m) { if ($e.name) { $list += $e.name } } }
      else { foreach ($p in $m.PSObject.Properties) { $list += $p.Name } }
    }
  }
  if (Test-Path $configFile) {
    try { $c = Get-Content $configFile -Raw | ConvertFrom-Json } catch { $c = $null }
    if ($c -and $c.agents) { foreach ($a in $c.agents) { if ($a.options -and $a.options.model) { $list += $a.options.model } } }
  }
  return ($list | Sort-Object -Unique)
}

$models = Collect-Models -modelsFile $ModelsFile -configFile $Config
if (-not $models -or $models.Count -eq 0) { Write-Host "No models found to check."; exit 0 }

$out = @()
foreach ($n in $models) {
  $o = [ordered]@{ name = $n; checkable = ($n -match '/'); notes = '' }
  if ($o.checkable) { $o.notes = 'Hugging Face style name; remote checkable (network required).' } else { $o.notes = 'Local or non-HF name; skip remote check.' }
  $out += $o
}

if ($DryRun) {
  Write-Host "Dry-run: would produce report for the following models:"
  $out | ConvertTo-Json -Depth 3 | Write-Host
  exit 0
}

# Normal mode: write the report file
$json = $out | ConvertTo-Json -Depth 5
if (-not (Test-Path (Split-Path $Out -Parent))) { New-Item -ItemType Directory -Path (Split-Path $Out -Parent) -Force | Out-Null }
$json | Out-File -FilePath $Out -Encoding utf8
Write-Host "Wrote model updates to $Out"
exit 0
