<#
set-temp-env.ps1
Utility to load temporary environment variables for the workspace from a JSON file.
Designed as a lightweight workaround so local path configuration can be postponed.

Usage examples:
  .\.continue\set-temp-env.ps1 -FromFile .\.continue\temp-env.sample.json -DryRun
  .\.continue\set-temp-env.ps1 -FromFile .\.continue\temp-env.sample.json -Persist

#>

param(
    [Parameter(Mandatory=$true)][string]$FromFile,
    [switch]$Persist,
    [switch]$DryRun
)

if (-not (Test-Path $FromFile)) {
    Write-Error "File not found: $FromFile"
    exit 2
}

try {
    $map = Get-Content -Path $FromFile -Raw | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse JSON file: $($_.Exception.Message)"
    exit 3
}

foreach ($p in $map.PSObject.Properties) {
    $name = $p.Name
    $value = [string]$p.Value
    Write-Host "[set-temp-env] $name = $value"
    if (-not $DryRun) {
        [System.Environment]::SetEnvironmentVariable($name, $value, 'Process')
        if ($Persist) {
            try {
                Start-Process -FilePath setx -ArgumentList @($name, $value) -NoNewWindow -Wait
            } catch {
                Write-Warning ("Persist via setx failed for {0}: {1}" -f $name, $_.Exception.Message)
            }
        }
    }
}

Write-Host "set-temp-env completed. DryRun=$DryRun Persist=$Persist"
