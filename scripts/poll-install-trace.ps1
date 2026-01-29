param(
    [int]$Minutes = 5,
    [int]$IntervalSeconds = 5,
    [string]$LogPath = '.\.continue\install-trace.log'
)

function Write-Now { param($m) $t=(Get-Date).ToString('s'); Write-Host "$t`t$m" }

$loops = [int](([double]$Minutes*60)/$IntervalSeconds)
$pos = 0
Write-Now "Starting poll: $Minutes minute(s), interval $IntervalSeconds sec."
for ($i=0; $i -lt $loops; $i++) {
    if (Test-Path $LogPath) {
        try {
            $text = Get-Content -Path $LogPath -Raw -ErrorAction Stop
        } catch { $text = '' }
        if ($text.Length -gt $pos) {
            $new = $text.Substring($pos)
            Write-Now "--- New log output ---"
            Write-Host $new
            $pos = $text.Length
        }
    }
    Start-Sleep -Seconds $IntervalSeconds
}
Write-Now "POLLING_COMPLETE"
