
Param(
    [Parameter(Mandatory=$false)] [int]$TargetPid,
    [Parameter(Mandatory=$false)] [string]$TelemetryFile = "$PSScriptRoot\..\.continue\telemetry-single.log",
    [Parameter(Mandatory=$false)] [string]$MappingFile
)

# If no PID provided, try to read the first pid from the mapping file
if (-not $TargetPid -and $MappingFile) {
    try {
        $raw = Get-Content -Path $MappingFile -Raw -ErrorAction Stop
        $m = $raw | ConvertFrom-Json
        if ($m -is [System.Array]) { $first = $m[0] } else { $first = $m }
        if ($first -and $first.pid) { $TargetPid = [int]$first.pid }
    } catch { }
}

if (-not $TargetPid) {
    Write-Error 'No PID provided and no PID found in mapping file.'
    exit 2
}

# Sample the process once and append a single JSON line to telemetry file
$p = Get-Process -Id $TargetPid -ErrorAction SilentlyContinue
$entry = [ordered]@{
    timestamp = (Get-Date).ToString('o')
    pid = $TargetPid
    processName = if ($p) { $p.ProcessName } else { $null }
    cpu = if ($p) { [math]::Round($p.CPU,3) } else { $null }
    workingSetMB = if ($p) { [math]::Round($p.WorkingSet/1MB,2) } else { $null }
}

$line = $entry | ConvertTo-Json -Compress

# Ensure directory exists
$dir = Split-Path -Path $TelemetryFile -Parent
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }

# Write single line atomically by writing to temp file then move
$tmp = "$TelemetryFile.$([System.Guid]::NewGuid().ToString()).tmp"
Set-Content -Path $tmp -Value $line -Encoding UTF8
Try {
    if (Test-Path $TelemetryFile) {
        # append: read existing and write combined to temp then move
        $existing = Get-Content -Path $TelemetryFile -Raw -ErrorAction SilentlyContinue
        Set-Content -Path $tmp -Value ($existing + "`n" + $line) -Encoding UTF8
    }
    Move-Item -Path $tmp -Destination $TelemetryFile -Force
} Catch {
    # fallback: append directly
    Add-Content -Path $TelemetryFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    if (Test-Path $tmp) { Remove-Item -Path $tmp -Force -ErrorAction SilentlyContinue }
}

exit 0
