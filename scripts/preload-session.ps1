<#
.SYNOPSIS
    Load secrets/placeholders from .continue/secrets.json into the current PowerShell session
    and optionally install a profile hook to preload them on every interactive session.

USAGE
    .\scripts\preload-session.ps1 [-SecretsFile '.continue/secrets.json'] [-InstallProfile] [-WhatIf]
#>

param(
    [string]$SecretsFile = '.continue/secrets.json',
    [switch]$InstallProfile,
    [switch]$WhatIf
)

function Log { param($m) Write-Output "[preload] $m" }

if (-not (Test-Path $SecretsFile)) { Log "Secrets file not found: $SecretsFile"; exit 1 }

try {
    $raw = Get-Content $SecretsFile -Raw -ErrorAction Stop
    $secrets = $raw | ConvertFrom-Json -ErrorAction Stop
} catch {
    Log "Failed to read/parse secrets file: $($_.Exception.Message)"; exit 1
}

# Apply home_env
if ($secrets.home_env) {
    foreach ($k in $secrets.home_env.PSObject.Properties.Name) {
        $v = $secrets.home_env.$k
        if (-not $WhatIf) { Set-Item -Path Env:$k -Value $v }
        Log "Set env $k => (hidden)"
    }
}

# Apply workspace_env
if ($secrets.workspace_env) {
    foreach ($k in $secrets.workspace_env.PSObject.Properties.Name) {
        $v = $secrets.workspace_env.$k
        if (-not $WhatIf) { Set-Item -Path Env:$k -Value $v }
        Log "Set env $k => (hidden)"
    }
}

# Optionally expose certain non-sensitive CI placeholders as env vars for local dev tools
if ($secrets.github) {
    foreach ($k in $secrets.github.PSObject.Properties.Name) {
        $v = $secrets.github.$k
        # Do not export real secrets unless user explicitly opts in; create masked audit entry instead
        Log "Found secret placeholder: $k (not exported)"
    }
}

# Trace usage in .continue/secrets-audit.log (do not store secret values)
try {
    $audit = '.continue/secrets-audit.log'
    $entry = [PSCustomObject]@{
        ts = (Get-Date).ToString('s')
        user = $env:USERNAME
        set_keys = @()
    }
    if ($secrets.home_env) { $entry.set_keys += ($secrets.home_env.PSObject.Properties.Name) }
    if ($secrets.workspace_env) { $entry.set_keys += ($secrets.workspace_env.PSObject.Properties.Name) }
    $line = ($entry | ConvertTo-Json -Compress)
    Add-Content -Path $audit -Value $line
    Log "Wrote audit to $audit"
} catch { Log "Failed to write audit: $($_.Exception.Message)" }

if ($InstallProfile) {
    $preloadPath = (Join-Path (Get-Location) 'scripts\preload-session.ps1')
    $profileLine = @"
# Auto-preload repo secrets for AILocalModelLibrary
. '$preloadPath' >`$null 2>&1
"@
    $profilePath = $PROFILE.CurrentUserAllHosts
    if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Path $profilePath -Force | Out-Null }
    $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if ($content -notmatch '\.\\scripts\\preload-session.ps1') {
        if ($WhatIf) { Log "Would append preload line to $profilePath" } else { Add-Content -Path $profilePath -Value $profileLine; Log "Appended preload to $profilePath" }
    } else { Log "Profile already contains preload entry." }
}

Log 'Done.'
