# Monitor Background Service

Overview
- `scripts/monitor-background.ps1` scans `.continue/agents-epic.json` and `.continue/agent-roles.json` and emits `.continue/skill-suggestions.json` and `.continue/monitor-dashboard.md`.

Run (once, dry-run):

```powershell
# from repo root
Import-Module ./tests/TestHelpers.psm1
.
& .\scripts\monitor-background.ps1 -DryRun -Once
```

Run continuously (background):

```powershell
# run in a terminal; the script sleeps between iterations
& .\scripts\monitor-background.ps1
```

Outputs
- `.continue/skill-suggestions.json` — machine-readable suggestions (timestamp, topSkills, roleSuggestions, heavyWeights).
- `.continue/monitor-dashboard.md` — human-friendly summary (top skills, heavy weights, per-role missing skills).

Notes
- Helpers: `tests/TestHelpers.psm1` provides `Test-LoadJson` and `Test-WriteJsonAtomic` used by the monitor.
- Files are written atomically to avoid partial writes.
