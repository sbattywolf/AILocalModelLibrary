<#
Monitor Ollama role-listed processes from .continue/ollama-processes.json.
Writes a JSON snapshot to .continue/ollama-monitor.json and appends CSV to logs/ollama-monitor.csv.
#>
param(
    [int]$SampleIntervalSeconds = 1,
    [int]$SampleCount = 1,
    [string]$MapFile = '.\.continue\ollama-processes.json',
    [string]$OutJson = '.\.continue\ollama-monitor.json',
    [string]$OutCsv = '.\\logs\\ollama-monitor.csv'
)

if (-not (Test-Path '.\.continue')) { New-Item -ItemType Directory -Path '.\.continue' | Out-Null }
if (-not (Test-Path '.\\logs')) { New-Item -ItemType Directory -Path '.\\logs' | Out-Null }

function Sample-Proc($pidVal) {
    $p = Get-Process -Id $pidVal -ErrorAction SilentlyContinue
    if (-not $p) { return @{ PID = $pidVal; Alive = $false } }
    $info = @{ 
        PID = $p.Id
        Alive = $true
        ProcessName = $p.ProcessName
        StartTime = ($p.StartTime).ToString('o')
        Threads = $p.Threads.Count
        Handles = $p.HandleCount
        WorkingSetMB = [math]::Round($p.WorkingSet64 / 1MB,2)
        PrivateMB = [math]::Round($p.PrivateMemorySize64 / 1MB,2)
        VirtualMB = [math]::Round($p.VirtualMemorySize64 / 1MB,2)
        IOReadBytes = $p.IOReadBytes
        IOWriteBytes = $p.IOWriteBytes
        CPUSeconds = $p.CPU
    }
    return $info
}

# Read mapping file
$maps = @()
if (Test-Path $MapFile) {
    try { $maps = Get-Content -Path $MapFile -Raw | ConvertFrom-Json -ErrorAction Stop } catch { $maps = @() }
}
$pids = @()
foreach ($m in $maps) { if ($m.PID) { $pids += [int]$m.PID } }
$pids = $pids | Sort-Object -Unique

# Do sampling
$snapshots = @()
for ($i=0; $i -lt $SampleCount; $i++) {
    $sampleTime = Get-Date
    $first = @{}
    foreach ($p in $pids) { $first[$p] = Sample-Proc $p }
    Start-Sleep -Seconds $SampleIntervalSeconds
    foreach ($p in $pids) {
            $second = Sample-Proc $p
            $f = $first[$p]
            if ($f -and $f.Alive -and $second -and $second.Alive) {
                $deltaCpu = ($second.CPUSeconds - $f.CPUSeconds)
                $cpuPercent = 0
                if ($deltaCpu -ge 0) { $cpuPercent = [math]::Round(($deltaCpu / $SampleIntervalSeconds) * 100 / [Environment]::ProcessorCount,2) }
                $entry = [PSCustomObject]@{
                    Timestamp = (Get-Date).ToString('o')
                    PID = $p
                    ProcessName = $second.ProcessName
                    Role = ($maps | Where-Object { $_.PID -eq $p } | Select-Object -ExpandProperty Role -First 1)
                    CPUPercent = $cpuPercent
                    WorkingSetMB = $second.WorkingSetMB
                    PrivateMB = $second.PrivateMB
                    VirtualMB = $second.VirtualMB
                    Threads = $second.Threads
                    Handles = $second.Handles
                    IOReadBytes = $second.IOReadBytes
                    IOWriteBytes = $second.IOWriteBytes
                    Alive = $second.Alive
                    StartTime = $second.StartTime
                }
            } else {
                $entry = [PSCustomObject]@{
                    Timestamp = (Get-Date).ToString('o')
                    PID = $p
                    ProcessName = $null
                    Role = ($maps | Where-Object { $_.PID -eq $p } | Select-Object -ExpandProperty Role -First 1)
                    CPUPercent = $null
                    WorkingSetMB = $null
                    PrivateMB = $null
                    VirtualMB = $null
                    Threads = $null
                    Handles = $null
                    IOReadBytes = $null
                    IOWriteBytes = $null
                    Alive = $false
                    StartTime = $null
                }
            }
            $snapshots += $entry
        }
}

# Write JSON snapshot (append as array entries)
$outObj = @{ CollectedAt = (Get-Date).ToString('o'); Samples = $snapshots }
try {
    $existing = @()
    if (Test-Path $OutJson) { try { $existing = Get-Content -Path $OutJson -Raw | ConvertFrom-Json -ErrorAction Stop } catch { $existing = @() } }
    $new = @()
    if ($existing -is [System.Array]) { $new += $existing }
    $new += $outObj
    $new | ConvertTo-Json -Depth 6 | Set-Content -Path $OutJson -Encoding utf8
} catch { Write-Output "Failed writing JSON: $_" }

# Append CSV
$csvHeader = "Timestamp,PID,Role,ProcessName,CPUPercent,WorkingSetMB,PrivateMB,VirtualMB,Threads,Handles,IOReadBytes,IOWriteBytes,Alive,StartTime"
if (-not (Test-Path $OutCsv)) { $csvHeader | Out-File -FilePath $OutCsv -Encoding utf8 }
foreach ($s in $snapshots) {
    $line = "{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12},{13}" -f $s.Timestamp,$s.PID,($s.Role -replace ',',';'),($s.ProcessName -replace ',',';'),$s.CPUPercent,$s.WorkingSetMB,$s.PrivateMB,$s.VirtualMB,$s.Threads,$s.Handles,$s.IOReadBytes,$s.IOWriteBytes,$s.Alive,$s.StartTime
    $line | Out-File -FilePath $OutCsv -Append -Encoding utf8
}

# Also print a short summary to stdout
$snapshots | Select-Object Timestamp,PID,Role,ProcessName,CPUPercent,WorkingSetMB,PrivateMB,Threads,Alive | Format-Table -AutoSize

Write-Output "Wrote JSON: $OutJson`nAppended CSV: $OutCsv"
