$repoRoot = Split-Path -Path $PSScriptRoot -Parent
 $path = Join-Path $repoRoot '.continue\agent-roles.json'
 Write-Host "Inspecting: $path"
 try {
     $raw = Get-Content -Raw -Encoding UTF8 -Path $path
     $raw = $raw -replace "^\s*```(?:json)?\s*",""
     $raw = $raw -replace "\s*```\s*$",""
     $roles = $raw | ConvertFrom-Json -ErrorAction Stop
 } catch {
     Write-Host "Load failed: $($_.Exception.Message)"; exit 1
 }
if ($null -eq $roles) { Write-Host 'roles is null'; exit 0 }
Write-Host ('Loaded type: ' + $roles.GetType().FullName)
if ($roles -and $roles.PSObject -and $roles.PSObject.Properties) {
    Write-Host ('Properties count: ' + $roles.PSObject.Properties.Count)
    foreach ($p in $roles.PSObject.Properties) { Write-Host ('- ' + $p.Name) }
} else {
    Write-Host 'PSObject.Properties not available' 
}
