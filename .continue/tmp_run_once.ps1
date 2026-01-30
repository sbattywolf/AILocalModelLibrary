param($mappingPath,$telemetryPath)
function Is-ProcessAlive { param($pid) try { Get-Process -Id $pid -ErrorAction Stop | Out-Null; return $true } catch { return $false } }
$raw = Get-Content $mappingPath -Raw
$agents = $raw | ConvertFrom-Json
foreach ($a in $agents) { if ($a.pid -and (Is-ProcessAlive -pid $a.pid)) { $entry = @{ ts = (Get-Date).ToString('o'); name = $a.name; pid = $a.pid }; $entry | ConvertTo-Json -Compress | Out-File -FilePath $telemetryPath -Encoding UTF8 -Append } }
