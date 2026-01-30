PreferMaxAgent

Overview
- `-PreferMaxAgent` is a switch for `scripts/run-agents-epic.ps1` and `scripts/monitor-agents-epic.ps1`.
- When enabled, agents are ordered by an estimated VRAM value (descending) to prefer scheduling higher-capability agents first.

Usage
- Orchestrator DryRun with preference:

```powershell
.\scripts\run-agents-epic.ps1 -DryRun -PreferMaxAgent -MaxParallel 3 -MaxVramGB 32
```

- Monitor enabling preference when scheduling queued agents:

```powershell
.\scripts\monitor-agents-epic.ps1 -PreferMaxAgent -MappingFile .continue\agents-epic.json
```

Notes
- Estimated VRAM values are read from `.continue/agent-roles.json` (field `resources.vramGB`). If missing, agents fall back to vram=0.
- This is a best-effort heuristic; the monitor still enforces `MaxVramGB` and may evict lower-priority agents to make room.
