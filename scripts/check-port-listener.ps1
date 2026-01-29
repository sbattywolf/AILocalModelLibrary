<#
.SYNOPSIS
  Check which processes are listening on a given TCP port and return structured output.

.DESCRIPTION
  Cross-checks `netstat -ano` for listeners on the specified `-Port` and `-Address`,
  inspects the owning processes, and returns JSON or table output. Designed for
  reuse in microservice tooling and CI.

.PARAMETER Port
  TCP port to inspect (required).

.PARAMETER Address
  Local address to filter on (default: 127.0.0.1). Use '0.0.0.0' to match all interfaces.

.PARAMETER OutFile
  Optional path to write JSON output. When not provided, prints JSON to stdout.

.PARAMETER Format
  Output format: 'json' or 'table' (default 'table').
#>
param(
    [Parameter(Mandatory=$true)][int]$Port,
    [string]$Address = '127.0.0.1',
    [string]$OutFile = '',
    [ValidateSet('json','table')][string]$Format = 'table'
)

function Write-Trace($message) {
    $ts = (Get-Date).ToString('s')
    $line = "${ts}`t${message}"
    try { Add-Content -Path '.\.continue\install-trace.log' -Value $line -ErrorAction SilentlyContinue } catch {}
}

# Run netstat and collect lines matching address:port or :port
$searchPattern = ':{0}\b' -f $Port
$netLines = netstat -ano 2>$null | Select-String -Pattern $searchPattern
if (-not $netLines) {
    Write-Trace "No listeners found for port $Port"
    $result = @{ Port = $Port; Address = $Address; Listeners = @() }
    if ($OutFile) { $result | ConvertTo-Json -Depth 6 | Set-Content -Path $OutFile -Encoding utf8 }
    if ($Format -eq 'json') { $result | ConvertTo-Json -Depth 6 } else { $result.Listeners | Format-Table -AutoSize }
    exit 0
}

# Parse netstat lines to extract PID and local endpoint
$entries = @()
foreach ($lineMatch in $netLines) {
    $line = $lineMatch.Line.Trim()
    # netstat columns: Proto  Local Address  Foreign Address  State  PID
    $cols = ($line -split '\s+') | Where-Object { $_ -ne '' }
    if ($cols.Count -lt 5) { continue }
    $proto = $cols[0]
    $localAddr = $cols[1]
    $state = $cols[3]
    $ownerPid = $cols[-1]
    # Filter by address if specified (allow 0.0.0.0 matching)
    if ($Address -and $Address -ne '0.0.0.0') {
        if ($localAddr -notlike "${Address}:*" -and $localAddr -notlike "*:${Port}") { continue }
    }
    $entries += [PSCustomObject]@{ Proto=$proto; LocalAddress=$localAddr; State=$state; PID=[int]$ownerPid }
}

# Deduplicate PIDs and gather process info
$pids = $entries | Select-Object -ExpandProperty PID -Unique | Where-Object { $_ -gt 0 }
$resultListeners = @()
foreach ($procId in $pids) {
    $procInfo = Get-Process -Id $procId -ErrorAction SilentlyContinue
    if ($procInfo) {
        $pathVal = $null
        if ($procInfo.Path) { $pathVal = $procInfo.Path }
        $startVal = $null
        try { $startVal = ($procInfo.StartTime).ToString('o') } catch { $startVal = $null }
        $threadsVal = $null
        try { $threadsVal = $procInfo.Threads.Count } catch { $threadsVal = $null }
        $handlesVal = $null
        try { $handlesVal = $procInfo.HandleCount } catch { $handlesVal = $null }
        $wsVal = $null
        try { $wsVal = [math]::Round($procInfo.WorkingSet64/1MB,2) } catch { $wsVal = $null }
        $stateVal = ($entries | Where-Object { $_.PID -eq $procId } | Select-Object -ExpandProperty State -First 1)
        $localsVal = ($entries | Where-Object { $_.PID -eq $procId } | Select-Object -ExpandProperty LocalAddress -Unique)
        $listener = [PSCustomObject]@{
            PID = $procInfo.Id
            ProcessName = $procInfo.ProcessName
            Path = $pathVal
            StartTime = $startVal
            Threads = $threadsVal
            Handles = $handlesVal
            WorkingSetMB = $wsVal
            State = $stateVal
            LocalAddresses = $localsVal
        }
    } else {
        $stateVal = ($entries | Where-Object { $_.PID -eq $procId } | Select-Object -ExpandProperty State -First 1)
        $localsVal = ($entries | Where-Object { $_.PID -eq $procId } | Select-Object -ExpandProperty LocalAddress -Unique)
        $listener = [PSCustomObject]@{
            PID = $procId
            ProcessName = $null
            Path = $null
            StartTime = $null
            Threads = $null
            Handles = $null
            WorkingSetMB = $null
            State = $stateVal
            LocalAddresses = $localsVal
        }
    }
    $resultListeners += $listener
}

$result = @{ CollectedAt = (Get-Date).ToString('o'); Port = $Port; Address = $Address; Listeners = $resultListeners }

# Output
if ($OutFile) {
    $result | ConvertTo-Json -Depth 6 | Set-Content -Path $OutFile -Encoding utf8
    Write-Trace "Wrote port check JSON to $OutFile for port $Port"
}

if ($Format -eq 'json') {
    $result | ConvertTo-Json -Depth 6
} else {
    $result.Listeners | Select-Object PID,ProcessName,Path,State,LocalAddresses,WorkingSetMB,Threads,Handles | Format-Table -AutoSize
}
