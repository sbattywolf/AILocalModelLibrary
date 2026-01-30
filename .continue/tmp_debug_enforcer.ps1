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
Write-Output '=== BEFORE MAPPING ==='
Get-Content $mappingPath -Raw
Write-Output "Alive pids: $($p1.Id), $($p2.Id)"
$enforcer = (Resolve-Path .\scripts\enforce-single-agent-per-role.ps1).Path
$outLog = Join-Path $tmpDir 'enforcer.log'
$errLog = Join-Path $tmpDir 'enforcer.err'
$psArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$enforcer,'-MappingFile',$mappingPath)
$proc = Start-Process -FilePath powershell -ArgumentList $psArgs -WorkingDirectory $tmpDir -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru
# Wait up to 8s for enforcer to complete
for ($i=0; $i -lt 8; $i++) { Start-Sleep -Seconds 1; if (-not (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)) { break } }
Start-Sleep -Seconds 1
Write-Output '=== AFTER MAPPING ==='
Get-Content $mappingPath -Raw
Write-Output '=== ENFORCER LOG ==='
Get-Content $outLog -Raw
if (Test-Path $errLog) { Write-Output '=== ENFORCER ERR ==='; Get-Content $errLog -Raw }
$alive = @()
try { Get-Process -Id $p1.Id -ErrorAction Stop | Out-Null; $alive += $p1.Id } catch {}
try { Get-Process -Id $p2.Id -ErrorAction Stop | Out-Null; $alive += $p2.Id } catch {}
Write-Output ("Alive after enforcer: {0}" -f ($alive -join ', '))
foreach ($p in $alive) { Try { Stop-Process -Id $p -Force -ErrorAction SilentlyContinue } Catch {} }
Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Output 'Debug run done.'
