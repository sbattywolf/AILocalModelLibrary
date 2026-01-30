Param(
    [int]$Count = 2,
    [string]$MappingPath = "$PWD\mapping.json",
    [string]$NamePrefix = 'dummy',
    [string]$PrimaryRole = 'tester'
)

Set-StrictMode -Version Latest

$agents = @()
for ($i=1; $i -le $Count; $i++) {
    $proc = Start-Process -FilePath ping -ArgumentList '-t','127.0.0.1' -PassThru
    $agent = [ordered]@{
        name = ("{0}-{1}" -f $NamePrefix, $i)
        pid = $proc.Id
        primaryRole = $PrimaryRole
        startedAt = (Get-Date).ToString('o')
    }
    $agents += $agent
}

($agents | ConvertTo-Json -Compress) | Set-Content -Path $MappingPath -Encoding UTF8

Write-Output "Spawned $Count dummy agents; mapping written to $MappingPath"
exit 0
