$info = @{}
function cmdpath($name){
    $c = Get-Command $name -ErrorAction SilentlyContinue
    if($c){ return $c.Source } else { return $null }
}
$tools = 'python','gh','git','docker','ollama','nvidia-smi','bw','llmstudio'
foreach ($t in $tools){ $info[$t] = cmdpath($t) }
try{ $info.git_version = (git --version 2>$null) -as [string] } catch { $info.git_version = $null }
try{ $vc = Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,AdapterRAM; $info.video = $vc } catch { $info.video = $null }
try{ $drivers = Get-CimInstance Win32_PnPSignedDriver | Select-Object DeviceName,DriverVersion,Manufacturer,DriverProviderName | Where-Object { $_.Manufacturer -match 'NVIDIA|AMD|Intel|Realtek|Broadcom|Qualcomm' } | Sort-Object Manufacturer -Unique; $info.drivers = $drivers } catch { $info.drivers = $null }
$info.env_names = (Get-ChildItem Env: | Select-Object -Expand Name)
if(-not(Test-Path .\ .continue)){ New-Item -ItemType Directory -Path .continue -Force | Out-Null }
$info | ConvertTo-Json -Depth 5 | Out-File -FilePath .\.continue\system_inventory.json -Encoding utf8
Write-Host 'WROTE .continue/system_inventory.json'