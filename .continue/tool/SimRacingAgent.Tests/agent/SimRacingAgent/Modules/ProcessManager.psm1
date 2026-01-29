function Get-ProcessHealthCheck {
    param()
    try {
        $procs = Get-Process -ErrorAction SilentlyContinue
        $count = $procs.Count
        $memory = ($procs | Measure-Object -Property WorkingSet -Sum).Sum
        $score = if ($count -eq 0) { 100 } else { [math]::Round((100 - ($memory / 1GB * 100)),0) }
        return @{ ProcessCount = $count; MemoryUsage = ($memory / 1MB); OverallHealth = [math]::Max(0, [math]::Min(100,$score)) }
    } catch { return @{ ProcessCount = 0; MemoryUsage = 0; OverallHealth = 0 } }
}

function Test-ManagedProcess {
    param(
        [Parameter(Mandatory=$true)] [hashtable]$ProcessDefinition
    )
    if (-not $ProcessDefinition.Name) { return $false }
    if (-not $ProcessDefinition.ExecutablePath) { return $false }
    return Test-Path -Path $ProcessDefinition.ExecutablePath
}

function Start-ManagedProcess {
    param(
        [string]$Name,
        [string]$ExecutablePath,
        [string]$Arguments = ''
    )
    if (-not (Test-Path $ExecutablePath)) { throw "Executable not found: $ExecutablePath" }
    $p = Start-Process -FilePath $ExecutablePath -ArgumentList $Arguments -PassThru -ErrorAction SilentlyContinue
    return $true
}

function Get-ProcessMetrics {
    param([string]$ProcessName)
    $p = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $p) { return @{} }
    $uptime = (Get-Date) - $p.StartTime
    return @{ MemoryUsageMB = [math]::Round($p.WorkingSet / 1MB,2); CPUUsage = 0; UptimeMinutes = [math]::Round($uptime.TotalMinutes,0) }
}

function Calculate-ProcessHealth {
    param([hashtable]$ProcessData)
    $score = 100
    if ($ProcessData.MemoryUsageMB) { $score -= [math]::Min(50, [math]::Round($ProcessData.MemoryUsageMB / 10,0)) }
    if ($ProcessData.CPUUsage) { $score -= [math]::Min(30, [math]::Round($ProcessData.CPUUsage,0)) }
    return [math]::Max(0,[math]::Min(100,$score))
}

Export-ModuleMember -Function Get-ProcessHealthCheck,Test-ManagedProcess,Start-ManagedProcess,Get-ProcessMetrics,Calculate-ProcessHealth
