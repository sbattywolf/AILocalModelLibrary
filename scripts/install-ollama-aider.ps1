<#
.SYNOPSIS
    Install and configure local developer tools: pip (if missing), Aider (aider-chat), optional Bitwarden CLI and PowerShell Core.

USAGE
    .\install-ollama-aider.ps1 [-InstallBitwarden] [-InstallPwsh] [-PersistScriptsToPath] [-WhatIf]

This script performs user-scoped installs and attempts to avoid requiring admin rights.
#>

param(
    [switch]$InstallBitwarden,
    [switch]$InstallPwsh,
    [switch]$PersistScriptsToPath,
    [switch]$AutoInstallMiniforge,
    [switch]$WhatIf
)

function Log { param($m) Write-Output "[install] $m" }

if ($WhatIf) { Log 'Running in WhatIf mode (no changes will be made)'; }

Log 'Checking Python...'
function Get-PythonCandidates {
    $candidates = @()

    # 1) Use py launcher to enumerate installed Pythons (if available)
    if (Get-Command py -ErrorAction SilentlyContinue) {
        try {
            $out = py -0p 2>$null
            if ($out) {
                foreach ($line in $out -split "\r?\n") {
                    $t = $line.Trim()
                    if (-not $t) { continue }
                    # py -0p prints version prefixes then path; extract last token that looks like a path
                    $parts = $t -split '\s+'
                    $p = $parts | Where-Object { $_ -match ':[\\/]'} | Select-Object -Last 1
                    if ($p -and (Test-Path $p)) { $candidates += $p }
                }
            }
        } catch {
            # fallback: try to probe default py -3 executable path
            try {
                $probe = py -3 -c "import sys;print(sys.executable)" 2>$null
                if ($probe) { $p2 = $probe.Trim(); if (Test-Path $p2) { $candidates += $p2 } }
            } catch { }
        }
    }

    # Explicitly probe common py versions (helps when py -0p parsing is weird)
    foreach ($ver in @('3.12','3.11')) {
        try {
            $out = py -$ver -c "import sys;print(sys.executable)" 2>$null
            if ($out) { $p = $out.Trim(); if (Test-Path $p) { $candidates += $p } }
        } catch { }
    }

    # 2) Known executable names on PATH
    $known = 'python3.12','python3.11','python3.10','python3','python'
    foreach ($name in $known) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { $candidates += $cmd.Source }
    }

    # 3) Conda/Mambaforge detection (use conda python)
    if (Get-Command conda -ErrorAction SilentlyContinue) {
        try {
            $condaInfo = conda info --base 2>$null
            if ($condaInfo) {
                $base = ($condaInfo -split "\r?\n" | Select-String -Pattern ":" -NotMatch) -join ''
            }
        } catch { }
    }

    # Unique list, preserve order
    return ($candidates | Where-Object { $_ } | Select-Object -Unique)
}

function Probe-Python { param($exe)
    try {
        $js = & $exe -c "import sys,json;print(json.dumps({'v':list(sys.version_info[:3]),'exe':sys.executable}))" 2>$null
        if ($js) { return ConvertFrom-Json $js }
    } catch { }
    return $null
}

function Install-Miniforge {
    param(
        [switch]$WhatIf
    )
    $url = 'https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Windows-x86_64.exe'
    $tmp = Join-Path $env:TEMP 'Miniforge3-installer.exe'
    Log "Miniforge installer URL: $url"
    if ($WhatIf) {
        Log "Would download Miniforge to $tmp and run silent installer (JustMe)."
        return $true
    }

    try {
        Log "Downloading Miniforge installer to $tmp..."
        Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing -ErrorAction Stop
    } catch {
        Log "Failed to download Miniforge: $($_.Exception.Message)"
        return $false
    }

    # Verify checksum if available from common suffixes
    function Get-FirstHex64Token([string]$s) {
        if (-not $s) { return $null }
        $m = ($s -split '\s+' | Where-Object { $_ -match '^[0-9a-fA-F]{64}$' }) | Select-Object -First 1
        return $m
    }

    function Verify-DownloadedFile([string]$filePath,[string]$sourceUrl) {
        $trySuffixes = @('.sha256','.sha256.txt','.sha256sum','.sha256sum.txt','SHA256SUMS')
        foreach ($sfx in $trySuffixes) {
            $chkUrl = $sourceUrl + $sfx
            try {
                $tmpChk = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName())
                Invoke-WebRequest -Uri $chkUrl -OutFile $tmpChk -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
                $content = Get-Content -Raw -Path $tmpChk -ErrorAction SilentlyContinue
                Remove-Item $tmpChk -ErrorAction SilentlyContinue
                if ($content) {
                    # try to find a 64-hex token in the content
                    $hex = Get-FirstHex64Token $content
                    if (-not $hex) {
                        # maybe it's a multi-line file with filename included; try lines
                        foreach ($ln in $content -split "\r?\n") {
                            $hex = Get-FirstHex64Token $ln
                            if ($hex) { break }
                        }
                    }
                    if ($hex) {
                        $actual = (Get-FileHash -Path $filePath -Algorithm SHA256).Hash
                        if ($actual -ieq $hex) { Log "Checksum verified for $filePath"; return $true }
                        else { Log "Checksum mismatch for $filePath (expected $hex, got $actual)"; return $false }
                    }
                }
            } catch {
                # try next suffix
            }
        }
        Log 'No checksum file found for Miniforge installer; aborting for security.'
        return $false
    }

    if (-not (Verify-DownloadedFile -filePath $tmp -sourceUrl $url)) {
        Log 'Downloaded Miniforge failed checksum verification; aborting.'
        Remove-Item -Force -ErrorAction SilentlyContinue $tmp
        return $false
    }

    try {
        $args = '/InstallationType=JustMe /AddToPath=0 /RegisterPython=0 /S'
        Log "Running Miniforge installer (silent)..."
        $p = Start-Process -FilePath $tmp -ArgumentList $args -Wait -PassThru -ErrorAction Stop
        Log "Miniforge installer exited with code $($p.ExitCode)"
        return $p.ExitCode -eq 0
    } catch {
        Log "Failed to run Miniforge installer: $($_.Exception.Message)"
        return $false
    }
}

Log 'Discovering Python interpreters on this machine...'
$cands = Get-PythonCandidates
if (-not $cands -or $cands.Count -eq 0) {
    if ($AutoInstallMiniforge) {
        Log 'No Python interpreters found; attempting Miniforge bootstrap (AutoInstallMiniforge enabled)'
        if (-not (Install-Miniforge -WhatIf:$WhatIf)) {
            Log 'Miniforge installation failed; aborting.'
            exit 1
        }
        # re-probe candidates after installing Miniforge
        $cands = Get-PythonCandidates
        if (-not $cands -or $cands.Count -eq 0) {
            Log 'No Python interpreters discovered after Miniforge install. Aborting.'
            exit 1
        }
    } else {
        Log 'No Python interpreters found. Please install Python 3.11 or 3.12 (recommended) or run again with -AutoInstallMiniforge.'
        exit 1
    }
}

Log "Found candidates: $($cands -join ', ')"

# probe all candidates and collect version info
$probed = @()
foreach ($c in $cands) {
    $info = Probe-Python $c
    if ($info -and $info.v) {
        $probed += [PSCustomObject]@{ exe = $c; major = $info.v[0]; minor = $info.v[1]; patch = $info.v[2]; info = $info }
    }
}

if ($probed.Count -eq 0) {
    if ($AutoInstallMiniforge) {
        Log 'No usable Python interpreter discovered; attempting Miniforge bootstrap (AutoInstallMiniforge enabled)'
        if (-not (Install-Miniforge -WhatIf:$WhatIf)) {
            Log 'Miniforge installation failed; aborting.'
            exit 1
        }
        # re-probe all candidates and collect version info
        $cands = Get-PythonCandidates
        $probed = @()
        foreach ($c in $cands) {
            $info = Probe-Python $c
            if ($info -and $info.v) {
                $probed += [PSCustomObject]@{ exe = $c; major = $info.v[0]; minor = $info.v[1]; patch = $info.v[2]; info = $info }
            }
        }
        if ($probed.Count -eq 0) { Log 'No usable Python interpreter discovered after Miniforge install. Aborting.'; exit 1 }
    } else { Log 'No usable Python interpreter discovered. Please install Python 3.11 or 3.12 and re-run.'; exit 1 }
}

foreach ($p in $probed) { Log "  -> $($p.exe) => Python $($p.major).$($p.minor).$($p.patch)" }

# Prefer 3.11 or 3.12
$preferred = $probed | Where-Object { $_.major -eq 3 -and ($_.minor -in 11,12) } | Select-Object -First 1
if ($preferred) { $py = $preferred.exe; $bestInfo = $preferred.info }
else {
    # Otherwise choose highest 3.x with minor < 14 if available
    $fallback = $probed | Where-Object { $_.major -eq 3 -and $_.minor -lt 14 } | Sort-Object -Property minor -Descending | Select-Object -First 1
    if ($fallback) { $py = $fallback.exe; $bestInfo = $fallback.info }
    else { $choice = $probed | Sort-Object -Property @{Expression={$_.major};Descending=$true}, @{Expression={$_.minor};Descending=$true} | Select-Object -First 1; $py = $choice.exe; $bestInfo = $choice.info }
}

Log "Selected Python: $py (version $($bestInfo.v -join '.'))"

function Ensure-Pip { param($pythonExe)
    try {
        $havePip = & $pythonExe -m pip --version 2>$null
        if (-not $havePip) {
            Log 'pip not found for selected interpreter; bootstrapping via ensurepip'
            if ($WhatIf) { Log "Would run: $pythonExe -m ensurepip --upgrade" } else { & $pythonExe -m ensurepip --upgrade }
        }
        return $true
    } catch {
        Log "ensurepip check failed: $($_.Exception.Message)"
        return $false
    }
}

if (-not (Ensure-Pip $py)) { Log 'pip bootstrap failed; aborting.'; exit 1 }

# Upgrade pip and install tooling into user site
if ($WhatIf) {
    Log 'Would upgrade pip and install aider-chat in user scope'
} else {
    Log 'Upgrading pip, setuptools and wheel (user scope)'
    & $py -m pip install --upgrade --user pip setuptools wheel

    Log 'Attempting to install binary-friendly dependencies and aider-chat (user scope)'
    $installOk = $false
    try {
        # First try to install with preference for binary wheels (may succeed if wheels are available)
        & $py -m pip install --user --prefer-binary aider-chat
        $installOk = $true
    } catch {
        Log "Initial install failed: $($_.Exception.Message)"
    }

    if (-not $installOk) {
        Log 'Attempting explicit binary install for numpy (may fail if wheel not available for this Python)'
        try { & $py -m pip install --user --only-binary=:all: numpy; $installOk = $true } catch { Log "numpy binary install failed: $($_.Exception.Message)" }
    }

    if ($installOk) {
        try { & $py -m pip install --user aider-chat } catch { Log "aider install failed even after numpy binary attempt: $($_.Exception.Message)" }
    } else {
        Log 'Could not install binary numpy. Recommended options:'
        Log '- Install Miniforge/Conda and install in that environment (recommended)'
        Log '- Install Visual C++ Build Tools to allow compiling wheels (heavy)'
        Log '- Install a supported Python (3.11 or 3.12) which likely has prebuilt numpy wheels'
    }
}

# Ensure user Scripts path is on PATH for this session
try {
    $userBase = & $py -c "import site,sys; print(site.getusersitepackages())" 2>$null
    if ($userBase) {
        $scriptsPath = [System.IO.Path]::Combine((Split-Path $userBase -Parent), 'Scripts')
        if (Test-Path $scriptsPath) {
            if (-not ($env:PATH -split ';' | Where-Object { $_ -eq $scriptsPath })) {
                Log "Adding $scriptsPath to PATH for current session"
                $env:PATH = "$scriptsPath;$env:PATH"
            }
        }
    }
} catch {
    Log "Could not compute user Scripts path: $($_.Exception.Message)"
}

Log 'Checking Aider...'
if (Get-Command aider -ErrorAction SilentlyContinue) {
    try { aider --version | Write-Output } catch { Write-Output 'aider present but --version failed' }
} else {
    if ($WhatIf) { Log 'Would check aider availability after install' } else { Log 'Aider not found on PATH after install. You may need to log out and back in, or add the user Scripts folder to PATH permanently.' }
}

# Offer to persist user Scripts folder to User PATH (prompted, WhatIf-safe)
try {
    if ($scriptsPath -and (Test-Path $scriptsPath)) {
        $currentUserPath = [Environment]::GetEnvironmentVariable('Path','User')
        $already = $false
        if ($currentUserPath) { $already = ($currentUserPath -split ';' | Where-Object { $_ -eq $scriptsPath }) }
        if (-not $already) {
            if ($PersistScriptsToPath) {
                if ($WhatIf) {
                    Log "Would add $scriptsPath to the persistent User PATH (non-interactive)"
                } else {
                    try {
                        $sep = ';'
                        $new = if ($currentUserPath) { "$currentUserPath$sep$scriptsPath" } else { $scriptsPath }
                        [Environment]::SetEnvironmentVariable('Path',$new,'User')
                        Log "Added $scriptsPath to User PATH. Sign out/in or restart terminals to apply."
                    } catch {
                        Log "Failed to set User PATH: $($_.Exception.Message)"
                    }
                }
            } else {
                if ($WhatIf) {
                    Log "Would add $scriptsPath to the persistent User PATH"
                } else {
                    $resp = Read-Host "Add $scriptsPath to your User PATH persistently? (Y/n)"
                    if ([string]::IsNullOrWhiteSpace($resp) -or $resp -match '^[Yy]') {
                        try {
                            $new = if ($currentUserPath) { "$currentUserPath;$scriptsPath" } else { $scriptsPath }
                            [Environment]::SetEnvironmentVariable('Path',$new,'User')
                            Log "Added $scriptsPath to User PATH. Sign out/in or restart terminals to apply."
                        } catch {
                            Log "Failed to set User PATH: $($_.Exception.Message)"
                        }
                    } else { Log 'Skipped persistent PATH modification.' }
                }
            }
        } else { Log "User PATH already contains $scriptsPath" }
    }
} catch { Log "Error while checking/persisting user PATH: $($_.Exception.Message)" }

if ($InstallBitwarden) {
    Log 'Optional: installing Bitwarden CLI via winget (if available)'
    if ($WhatIf) { Log 'Would run winget install --id Bitwarden.BitwardenCLI -e' } else {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id Bitwarden.BitwardenCLI -e --silent
        } else { Log 'winget not available; please install Bitwarden CLI manually from https://bitwarden.com/help/cli/' }
    }
}

if ($InstallPwsh) {
    Log 'Optional: install PowerShell Core (pwsh) via winget'
    if ($WhatIf) { Log 'Would run winget install --id Microsoft.PowerShell -e' } else {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget install --id Microsoft.PowerShell -e --silent
        } else { Log 'winget not available; please install PowerShell Core manually from https://github.com/PowerShell/PowerShell' }
    }
}

Log 'Done. Next steps:'
Log '- If Aider was installed, verify with: aider --version'
Log "- Add any installed user Scripts folder to your persistent PATH (System Properties -> Environment Variables)."
Log "- Create GitHub Secrets (GEMINI_API_KEY, BITWARDEN_APIKEY etc.) as described in docs/SECRETS_SETUP.md"
