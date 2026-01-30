Set-StrictMode -Version Latest
$repoRoot = Split-Path -Path $PSScriptRoot -Parent

function Test-LoadJson {
    param([string]$Path)
    $raw = Get-Content -Raw -Encoding UTF8 -Path $Path
    $raw = $raw -replace "^\s*```(?:json)?\s*",""
    $raw = $raw -replace "\s*```\s*$",""
    return $raw | ConvertFrom-Json -ErrorAction Stop
}

$path = Join-Path $repoRoot '.continue\agent-roles.json'
Write-Host "Reading $path"
try { $roles = Test-LoadJson -Path $path } catch { Write-Host "Load failed: $($_.Exception.Message)"; exit 1 }
Write-Host "roles type: $($roles.GetType().FullName)"
if ($roles -eq $null) { Write-Host 'roles null'; exit 0 }
Write-Host 'Roles raw:'
$roles | Format-List | Out-String | Write-Host
Write-Host 'PSObject available:'; if ($roles.PSObject) { Write-Host 'yes' } else { Write-Host 'no' }
try { $props = $roles.PSObject.Properties; Write-Host ('props type: ' + $props.GetType().FullName) } catch { Write-Host 'Failed to read PSObject.Properties: ' + $_.Exception.Message }
if ($props) { Write-Host ('props.Count: ' + $props.Count) ; $props | ForEach-Object { Write-Host ('- ' + $_.Name) } }
