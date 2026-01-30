<#
.SYNOPSIS
    Create a secrets placeholder file under .continue/secrets.json with workspace/home keys and placeholders for CI keys.

USAGE
    .\scripts\init-secrets.ps1
#>

param(
    [string]$Out = '.continue/secrets.json',
    [switch]$Force
)

function Log { param($m) Write-Output "[init-secrets] $m" }

if (-not (Test-Path '.continue')) { New-Item -ItemType Directory -Path '.continue' | Out-Null }

if ((Test-Path $Out) -and -not $Force) {
    Log "$Out already exists. Use -Force to overwrite."
    exit 0
}

$template = @{
    version = '1'
    home_env = @{
        HOME_DEV = "C:\\Users\\<you>\\Dev"
        HOME_DATA = "C:\\Users\\<you>\\Data"
    }
    workspace_env = @{
        WORKSPACE_ROOT = (Get-Location).Path
        WORKSPACE_NAME = 'AILocalModelLibrary'
    }
    github = @{
        GEMINI_API_KEY = '<placeholder>'
        BITWARDEN_APIKEY = '<placeholder>'
    }
    winget = @{
        packages = @('Microsoft.PowerShell','Bitwarden.BitwardenCLI')
    }
    notes = 'Placeholders only. Replace sensitive values before use. Use scripts/preload-session.ps1 to load into session.'
}

$json = $template | ConvertTo-Json -Depth 6
Set-Content -Path $Out -Value $json -Encoding UTF8
Log "Wrote placeholder secrets to $Out"
