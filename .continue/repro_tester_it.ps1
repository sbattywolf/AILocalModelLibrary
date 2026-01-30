$ErrorActionPreference='Stop'
$tmpDir = Join-Path $env:TEMP ([guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tmpDir | Out-Null
$mappingPath = Join-Path $tmpDir 'mapping.json'
$p1 = Start-Process -FilePath ping -ArgumentList '-t','127.0.0.1' -PassThru
$p2 = Start-Process -FilePath ping -ArgumentList '-t','127.0.0.1' -PassThru
Start-Sleep -Seconds 1
$agents = @(
  @{ name='tester-1'; pid=$p1.Id; primaryRole='tester'; startedAt=(Get-Date).ToString('o') },
  @{ name='tester-2'; pid=$p2.Id; primaryRole='tester'; startedAt=(Get-Date).ToString('o') }
)
$agents | ConvertTo-Json -Compress | Set-Content -Path $mappingPath -Encoding UTF8
$log = Join-Path $tmpDir 'repro.log'
"=== BEFORE MAPPING ===" | Out-File $log -Encoding utf8
Get-Content $mappingPath -Raw | Out-File $log -Append -Encoding utf8
"Alive pids: $($p1.Id), $($p2.Id)" | Out-File $log -Append -Encoding utf8
$enforcer = (Resolve-Path (Join-Path (Get-Location) 'scripts\enforce-single-agent-per-role.ps1')).Path
$outLog = Join-Path $tmpDir 'enforcer.out'
$errLog = Join-Path $tmpDir 'enforcer.err'
$psArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$enforcer,'-MappingFile',$mappingPath)
$proc = Start-Process -FilePath powershell -ArgumentList $psArgs -WorkingDirectory $tmpDir -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru
# Wait up to 12s for enforcer to finish
for ($i=0; $i -lt 12; $i++) { Start-Sleep -Seconds 1; if (-not (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)) { break } }
Start-Sleep -Seconds 1
"=== AFTER MAPPING ===" | Out-File $log -Append -Encoding utf8
Get-Content $mappingPath -Raw | Out-File $log -Append -Encoding utf8
"=== ENFORCER STDOUT ===" | Out-File $log -Append -Encoding utf8
if (Test-Path $outLog) { Get-Content $outLog -Raw | Out-File $log -Append -Encoding utf8 }
if (Test-Path $errLog) { "=== ENFORCER STDERR ===" | Out-File $log -Append -Encoding utf8; Get-Content $errLog -Raw | Out-File $log -Append -Encoding utf8 }
# record alive
$alive = @(); try { Get-Process -Id $p1.Id -ErrorAction Stop | Out-Null; $alive += $p1.Id } catch {}; try { Get-Process -Id $p2.Id -ErrorAction Stop | Out-Null; $alive += $p2.Id } catch {}
"Alive after enforcer: $($alive -join ', ')" | Out-File $log -Append -Encoding utf8
# copy log to stdout for CI
Get-Content $log -Raw
# cleanup
foreach ($p in $alive) { Try { Stop-Process -Id $p -Force -ErrorAction SilentlyContinue } Catch {} }
Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
