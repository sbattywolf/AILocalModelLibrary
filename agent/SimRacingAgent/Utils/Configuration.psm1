function Get-DefaultConfiguration {
    try {
        if (Get-Command -Name Get-DefaultConfiguration -ErrorAction SilentlyContinue) {
            return & Get-DefaultConfiguration
        }
    } catch {}

    # Fallback simple configuration
    $jsonPath = Join-Path $PSScriptRoot 'agent-config.json'
    if (Test-Path $jsonPath) {
        try { return Get-Content -Path $jsonPath -Raw | ConvertFrom-Json } catch {}
    }

    return @{ Agent = @{ Name = 'SimRacingAgent'; DataPath = "C:\\ProgramData\\SimRacingAgent" }; Logging = @{ LogFilePath = "C:\\ProgramData\\SimRacingAgent\\logs\\agent.log" } }
}

function Save-Configuration {
    param([hashtable]$Config, [string]$Path)
    $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
    return $true
}

function Load-Configuration {
    param([string]$Path)
    if (-not (Test-Path $Path)) { throw "Config file not found: $Path" }
    return Get-Content -Path $Path -Raw | ConvertFrom-Json
}

Export-ModuleMember -Function Get-DefaultConfiguration,Save-Configuration,Load-Configuration
