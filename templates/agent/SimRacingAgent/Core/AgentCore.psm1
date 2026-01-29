function Test-AgentRunning {
    [CmdletBinding()]
    param()
    try {
        $procs = Get-Process -ErrorAction SilentlyContinue
        return ($procs | Where-Object { $_.ProcessName -like 'SimRacingAgent*' }).Count -gt 0
    } catch { return $false }
}

function Set-AgentLock {
    param()
    if (-not $Global:AgentLockFile) { $Global:AgentLockFile = Join-Path $env:TEMP 'agent.lock' }
    $data = @{ ProcessId = $PID; Timestamp = (Get-Date).ToString() }
    $data | ConvertTo-Json | Set-Content -Path $Global:AgentLockFile -Encoding UTF8
    return $true
}

function Clear-AgentLock {
    param()
    if ($Global:AgentLockFile -and (Test-Path $Global:AgentLockFile)) {
        Remove-Item -Path $Global:AgentLockFile -Force -ErrorAction SilentlyContinue
        return $true
    }
    return $false
}

function Write-AgentLog {
    param(
        [string]$Message,
        [string]$Level = 'Info',
        [string]$Component = 'Agent',
        [string]$LogPath
    )
    if (-not $LogPath) { $LogPath = Join-Path $env:TEMP 'agent.log' }
    $entry = "[$((Get-Date).ToString('o'))] [$Level] [$Component] $Message"
    $entry | Out-File -FilePath $LogPath -Append -Encoding UTF8
    return $true
}

function Get-AgentStatus {
    param(
        [hashtable]$Config
    )
    $isRunning = Test-AgentRunning
    $configValid = $false
    try { Import-Module (Join-Path $PSScriptRoot '..\ConfigManager.psm1') -ErrorAction SilentlyContinue; $conf = Get-DefaultConfiguration; $configValid = $true } catch { $configValid = $false }

    $memory = (Get-Process -ErrorAction SilentlyContinue | Measure-Object -Property WorkingSet -Sum).Sum
    return @{
        AgentRunning = $isRunning
        ConfigValid = $configValid
        MemoryUsage = ($memory / 1MB)
    }
}

if ($PSModuleInfo) {
    Export-ModuleMember -Function Test-AgentRunning,Set-AgentLock,Clear-AgentLock,Write-AgentLog,Get-AgentStatus -ErrorAction Stop
} else {
    Write-Verbose "Export-ModuleMember skipped (not running inside a module)"
}
