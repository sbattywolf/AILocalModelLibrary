$fn = '.\.continue\system_inventory.json'
$j = Get-Content $fn -Raw | ConvertFrom-Json
function tryRun($path, $args){ if(-not $path){ return $null } ; try{ $out = & "$path" $args 2>&1 ; return $out } catch { return $null } }
$j.ollama_version = tryRun($j.ollama, '--version')
$j.gh_version = tryRun($j.gh, '--version')
$j.bw_version = tryRun($j.bw, '--version')
$j.docker_version = tryRun($j.docker, '--version')
$j.nvidia_smi_path = $j.'nvidia-smi'
$j | ConvertTo-Json -Depth 6 | Out-File $fn -Encoding utf8
Write-Host 'UPDATED .continue/system_inventory.json with runtime versions'