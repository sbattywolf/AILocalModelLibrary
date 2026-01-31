# Agent Resource Monitoring

This document describes the lightweight runtime monitoring added to collect per-agent CPU and RAM usage and how eviction heuristics use system pressure.

Files added/updated:
- `scripts/monitor-agents-epic.ps1` — now samples per-agent process stats and system CPU/memory to inform eviction decisions. Writes mapping to `.continue/agents-epic.json` and requires `agent-roles` to include `memoryGB`/`cpus`.
- `scripts/agent-runtime-monitor.ps1` — small continuous sampler that reads `.continue/agents-epic.json`, samples `Get-Process -Id <pid>` for running agents, and appends JSON lines to `.continue/agent-runtime-telemetry.log`.
- `config.template.json` — added `agent_defaults` block describing default `vramGB`, `memoryGB`, and `cpus`.

Usage examples:

Start the main monitor (recommended):

```powershell
# run monitor (observes mapping and enforces evictions / restarts)
.
\scripts\monitor-agents-epic.ps1 -IntervalSeconds 10 -MaxVramGB 19 -MaxParallel 3
```

Start the lightweight runtime sampler (optional):

```powershell
.
\scripts\agent-runtime-monitor.ps1 -IntervalSeconds 10
```

Telemetry file: `.continue/agent-runtime-telemetry.log` contains JSON-lines with entries like:

```json
{"ts":"2026-01-30T03:10:18Z","name":"Low-7","pid":1234,"cpuSec":0.012,"workingSetMB":45.12}
```

Eviction behavior summary:
- The monitor computes current VRAM usage and, when scheduling queued agents, will attempt to evict lower-priority agents to make room.
- When system memory is low (free physical RAM < 4GB) or CPU load is high (>85%), eviction selection is relaxed to consider more candidates, and memory-heavy agents are preferred for eviction.

Next steps:
- Tune thresholds (`sysFreeGB` and CPU load) to match your system and workloads.
- Optionally add historical aggregation (rolling averages) for CPU and memory before making eviction decisions.

