<#
.SYNOPSIS
  Toggle secret mode in .continue/user_config.json

.DESCRIPTION
  Enables or disables `secret_mode` in the per-workspace `.continue/user_config.json` file.
  This script only updates the config flag; it does not store secret values.

.PARAMETER Enable
  If present, enable secret mode.

.PARAMETER Disable
  If present, disable secret mode.

.EXAMPLE
  .\scripts\enable-secret-mode.ps1 -Enable

#>

param(
    [switch]$Enable,
    [switch]$Disable
)

Set-StrictMode -Version Latest

$cfgPath = Join-Path (Get-Location) '.continue\user_config.json'
if (-not (Test-Path $cfgPath)) {
    Write-Error "Config file not found: $cfgPath"
    exit 2
}

try {
    $text = Get-Content -Path $cfgPath -Raw -ErrorAction Stop
    $obj = $text | ConvertFrom-Json -ErrorAction Stop
} catch {
  Write-Error "Failed to read or parse $cfgPath: $($_)"
  exit 2
}

if ($Enable -and $Disable) {
    Write-Error "Specify only one of -Enable or -Disable"
    exit 2
}

if ($Enable) { $obj.secret_mode = $true }
elseif ($Disable) { $obj.secret_mode = $false }
else { $obj.secret_mode = -not ($obj.secret_mode -eq $true) }

try {
    $json = $obj | ConvertTo-Json -Depth 6
    Set-Content -Path $cfgPath -Value $json -Encoding UTF8 -Force
    Write-Host "WROTE $cfgPath (secret_mode = $($obj.secret_mode))"
} catch {
  Write-Error "Failed to write config: $($_)"
  exit 2
}
