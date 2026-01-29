function Get-DefaultConfiguration {
    [CmdletBinding()]
    param()

    $agentName = "SimRacingAgent"
    return @{
        Agent = @{ Name = $agentName; DataPath = "C:\ProgramData\$agentName" }
        Logging = @{ LogFilePath = "C:\ProgramData\$agentName\logs\agent.log" }
    }
}

function Test-Configuration {
    param(
        [Parameter(Mandatory=$true)] [hashtable]$Config
    )
    if (-not $Config) { return $false }
    if (-not $Config.ContainsKey('Agent')) { return $false }
    if (-not $Config.Agent.ContainsKey('Name')) { return $false }
    return $true
}

function Save-Configuration {
    param(
        [Parameter(Mandatory=$true)] [hashtable]$Config,
        [Parameter(Mandatory=$true)] [string]$Path
    )
    $json = $Config | ConvertTo-Json -Depth 10
    $json | Set-Content -Path $Path -Encoding UTF8
    return $true
}

function Load-Configuration {
    param(
        [Parameter(Mandatory=$true)] [string]$Path
    )
    if (-not (Test-Path $Path)) { throw "Config file not found: $Path" }
    $text = Get-Content -Path $Path -Raw
    return $text | ConvertFrom-Json
}

function Export-Configuration {
    param(
        [Parameter(Mandatory=$true)] [hashtable]$Config
    )
    $fileName = "config_export_$(Get-Date -Format yyyyMMdd_HHmmss).json"
    $path = Join-Path -Path $env:TEMP -ChildPath $fileName
    $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $path
    return @{ FileName = $fileName; Path = $path }
}

if ($PSModuleInfo) {
    Export-ModuleMember -Function Get-DefaultConfiguration,Test-Configuration,Save-Configuration,Load-Configuration,Export-Configuration -ErrorAction Stop
} else {
    Write-Verbose "Export-ModuleMember skipped (not running inside a module)"
}
