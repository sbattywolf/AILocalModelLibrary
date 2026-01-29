Manual PATH update and restore instructions

Files created by the simulated installer

- Backup of previous user PATH: .continue/path-backup.txt
- Simulated runtime bin: .continue/tempTest/bin
- Simulated model marker: .continue/tempTest/models/codellama-7b-instruct.txt

Recommended safe manual steps

1) Inspect the backup and current user PATH

```powershell
# Show backed-up PATH
Get-Content .\.continue\path-backup.txt

# Show current user PATH
[Environment]::GetEnvironmentVariable('Path','User')
```

2) Preview adding the runtime folder (no writes yet)

```powershell
$runtime = (Resolve-Path .\.continue\tempTest\bin).Path
$current = [Environment]::GetEnvironmentVariable('Path','User')
if ($current -like "*$runtime*") { Write-Host "Runtime path already present" } else { $new = "$current;$runtime"; Write-Host "New PATH length: $($new.Length)"; Write-Host "Preview (first 200 chars): $($new.Substring(0,[Math]::Min(200,$new.Length)))" }
```

3) Safest manual update (recommended)

- Use Windows Settings → System → About → Advanced system settings → Environment Variables → under "User variables" select `Path` → Edit → New → paste the runtime folder path (`.continue/tempTest/bin`) → OK.

4) Apply via PowerShell (alternative; use with caution)

```powershell
# WARNING: setx truncates long values on some systems. Prefer GUI edit above.
$runtime = (Resolve-Path .\.continue\tempTest\bin).Path
$current = [Environment]::GetEnvironmentVariable('Path','User')
if ($current -notlike "*$runtime*") {
  $new = "$current;$runtime"
  # Optional: inspect length
  Write-Host "Applying PATH (length=$($new.Length))"
  [Environment]::SetEnvironmentVariable('Path',$new,'User')
  Write-Host "User PATH updated. New sessions will see the change." 
} else { Write-Host "Runtime path already in user PATH." }
```

5) To restore the previous PATH from backup

```powershell
$backup = Get-Content .\.continue\path-backup.txt -Raw
[Environment]::SetEnvironmentVariable('Path',$backup,'User')
Write-Host "User PATH restored from .continue/path-backup.txt"
```

Notes

- The installer already wrote the backup to `.continue/path-backup.txt`. Keep that file until you confirm PATH is correct.
- GUI edit is the safest for avoiding truncation or accidental removal of other PATH entries.
- If you need a System PATH change (global), an elevated admin process is required and will affect all users; I can prepare an elevated helper script if you want.
