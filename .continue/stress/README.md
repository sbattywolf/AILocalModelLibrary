This folder contains the planned scaling test matrix.

How to run a single planned run (example for `all-low-10`):

1) DryRun to validate scheduling:

```powershell
# DryRun
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-agents-epic.ps1 -DryRun -MaxParallel 10 -MaxVramGB 24
```

2) Run the orchestrator (real):

```powershell
# Real run - be cautious
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-agents-epic.ps1 -MaxParallel 10 -MaxVramGB 24
```

Notes:
- The orchestrator uses `.continue/config.agent`. For stress runs you may temporarily replace that file with a run-specific config (back it up first) or use the existing stress harness `scripts/stress/stress-parallel.ps1` to generate large test configs.
- Collect logs: `logs/stress/` and `.continue/agents-epic.json` snapshots after each run.
- For safety, prefer running the DryRun commands first and review `.continue/agents-epic.json`.
