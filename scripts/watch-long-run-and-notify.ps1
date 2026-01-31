Param(
    [int]$PollSeconds = 5,
    [int]$TimeoutSeconds = 1800
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$continueDir = Join-Path $scriptRoot '..\.continue' | Resolve-Path -ErrorAction SilentlyContinue
if (-not $continueDir) { $continueDir = Join-Path $scriptRoot '..' '.continue' }
$continuePath = (Resolve-Path $continueDir).Path

$end = (Get-Date).AddSeconds($TimeoutSeconds)
Write-Output "Watcher started; watching $continuePath for long-run-* dirs"
while ((Get-Date) -lt $end) {
    $found = Get-ChildItem -Path $continuePath -Directory -Filter 'long-run-*' -ErrorAction SilentlyContinue
    if ($found) {
        $ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
        $marker = Join-Path $continuePath "long-run-complete-$ts.txt"
        "Long run artifacts detected: $($found[0].FullName)" | Out-File -FilePath $marker -Encoding UTF8
        Write-Output "LONG_RUN_FINISHED: $($found[0].FullName)"
        exit 0
    }
    Start-Sleep -Seconds $PollSeconds
}
Write-Output "Watcher timed out after $TimeoutSeconds seconds"
exit 2
