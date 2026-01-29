# Elevated install/run guidance

- Run installers from a single elevated PowerShell terminal to avoid multiple concurrent UAC sessions.
- If a script relaunches elevated, accept the UAC prompt in that single terminal and let it finish.
- Scripts may record elevated PIDs to `.continue/elevated-pids.txt` by calling `scripts/register-elevated-pid.ps1` at start.
- If you need to abort or clean up, run `scripts/cleanup-elevated.ps1` from any PowerShell (no elevation required to attempt stopping PIDs).
- Keep this workflow simple: prefer `choco` bootstrap path (scripts/install-choco-7zip.ps1) when you want fewer UAC/store interactions.

Example elevated sequence (open one Administrator PowerShell window):

```powershell
# In an elevated PowerShell session:
# 1) Run installer that registers its PID (if it supports it):
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-choco-7zip.ps1 -Apply -LogPath .\.continue\install-trace.log

# 2) If a process was registered and you want to terminate it:
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\cleanup-elevated.ps1 -LogPath .\.continue\install-trace.log
```

Keep the `.continue` folder and its logs under version control ignore; the helpers use these files as state.
