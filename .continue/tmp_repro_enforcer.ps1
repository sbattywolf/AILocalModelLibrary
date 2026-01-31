$ErrorActionPreference='Stop'
$tmpDir=Join-Path $env:TEMP ([guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tmpDir | Out-Null
$mappingPath=Join-Path $tmpDir 'mapping.json'
$p1=Start-Process -FilePath ping -ArgumentList '-t','127.0.0.1' -PassThru
$p2=Start-Process -FilePath ping -ArgumentList '-t','127.0.0.1' -PassThru
Start-Sleep -Seconds 1
$agents=@(
 @{ name='tester-1'; pid=$p1.Id; primaryRole='tester'; startedAt=(Get-Date).ToString('o') },
 @{ name='tester-2'; pid=$p2.Id; primaryRole='tester'; startedAt=(Get-Date).ToString('o') }
)
$agents | ConvertTo-Json -Compress | Set-Content -Path $mappingPath -Encoding UTF8
Write-Output "=== BEFORE MAPPING ==="
Get-Content $mappingPath -Raw
Write-Output "Alive pids: $($p1.Id), $($p2.Id)"
# run enforcer
$enforcer=(Resolve-Path (Join-Path $PSScriptRoot '..\\scripts\\enforce-single-agent-per-role.ps1')).Path
Write-Output "Running enforcer (no DryRun)..."
& powershell -NoProfile -ExecutionPolicy Bypass -File $enforcer -MappingFile $mappingPath
Start-Sleep -Seconds 1
Write-Output "=== AFTER MAPPING ==="
Get-Content $mappingPath -Raw
# Check alive pids
$alive= @()
try { Get-Process -Id $p1.Id -ErrorAction Stop | Out-Null; $alive += $p1.Id } catch {}
try { Get-Process -Id $p2.Id -ErrorAction Stop | Out-Null; $alive += $p2.Id } catch {}
Write-Output ("Alive after enforcer: {0}" -f ($alive -join ', '))
# Cleanup
foreach ($p in $alive) { Try { Stop-Process -Id $p -Force -ErrorAction SilentlyContinue } Catch {} }
Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Output "Reproducer done."