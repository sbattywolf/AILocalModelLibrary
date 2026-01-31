# Session summary, repo concepts, conflicts, and epics

This document captures the work performed during the current session, summarizes repository concepts, lists observable conflicts or open questions, and proposes epics and next-step tasks.

**Session trace (high level)**
- Restored and hardened an Ollama-based local agent orchestration/monitor prototype.
- Implemented atomic persisted mappings under `.continue/` and sidecar `pid-<pid>.agent` files.
- Added a deterministic single-sample telemetry sampler and a longer sampler/monitor run helper.
- Hardened many Pester tests (OPS smoke, single-agent-per-role, eviction order).
- Added a `skills` schema to `agent-roles` and prototypes: `scheduler-prefer-skill.ps1`, `skill-monitor.ps1` and tests.
- Scaffoled CI analysis flow: CI → analysis (stub) → `.continue/analysis/` → `scripts/apply-aider-suggestion.ps1`.

**Key repository concepts**
- Agents: described in `.continue/agent-roles.json` with `vramGB`, `memoryGB`, `cpus`, and `skills`.
- Monitor/Enforcer: scripts that sample runtime metrics, enforce single-agent-per-role, and evict/start agents based on thresholds.
- Scheduler: DryRun scheduling that produces proposals (now includes `agents-proposal.json` for monitor consumption).
- Telemetry: `agent-runtime-telemetry.log` and sampler scripts used to tune thresholds.
- CI analysis: workflow scaffold to upload failing transcripts and produce suggestions into `.continue/analysis/`.

**Conflicts / open questions discovered**
- Param / legacy blocks accidentally duplicated in earlier script drafts (fixed for `scheduler-prefer-skill.ps1`).
- JSON shapes vary across scripts/tests (sometimes arrays, sometimes single strings). Tests and producers were hardened, but standardizing shapes in a single schema file is recommended.
- CI analysis is stubbed; real Gemini/API integration still requires secrets and security review.

**Recommendations & improvements (epic-level)**
- Epic: Standardize schemas — define canonical JSON schema for `agent-roles.json`, `agents-proposal.json`, mappings, and telemetry lines. Add validation tests and a schema-linting CI step.
- Epic: Scheduler → Monitor integration — wire `scheduler-prefer-skill.ps1` proposals into DryRun and monitor consumers and add end-to-end tests (DryRun -> proposal -> monitor consumer -> expected mapping changes).
- Epic: Backlog & team management — implement backlog management that groups tasks by team and agent role, supports grooming, and provides automated suggestions (see new task below).
- Epic: Child-agent / Team composition prototype — design and prototype parent-child agents (1 parent, up to 2 children), task-splitting logic, resource checks, and rebalancing heuristics. Provide Pester coverage for compositing and failure modes.
- Epic: CI analysis maturity — replace analysis stubs with an authenticated, auditable analysis pipeline (Gemini or other) and safe Aider integration with gating and manual review.

**Operational next steps (concrete)**
1. Add canonical JSON schema files under `schemas/` and update producers/consumers to validate against them.
2. Wire `agents-proposal.json` consumption: update monitor/enforcer to accept proposals from the scheduler, then write an end-to-end test.
3. Add nightly long-run job to collect longer telemetry and feed into threshold tuning.
4. Groom backlog per team/role and assign owners for each epic (see backlog management task in TODO list).
5. Backlog automation: use `scripts/export-todos-dashboard.ps1` to generate an owner+team view of the backlog; integrate into PR checks or a scheduled report.

**Files touched during session (representative)**
- `scripts/scheduler-prefer-skill.ps1` — scheduler prototype & monitor proposal output
- `scripts/skill-monitor.ps1` — skill constraints/warning generator
- `scripts/agent-runtime-monitor-single-sample.ps1` — deterministic sampler used by tests
- `tests/Monitor.PreferSkill.Tests.ps1`, `tests/Monitor.PreferSkill.AgentsProposal.Tests.ps1`, `tests/Monitor.SkillsValidation.Tests.ps1` — Pester tests
- `.github/workflows/ci-analyze.yml` and `scripts/ci-gemini-analyze.ps1` — CI analysis scaffold

---
**Contact & next owner actions**
- Recommend a short grooming session (30–60 minutes) with stakeholders (scheduler, monitor, CI) to: accept these epics, assign owners, and prioritize the schema standardization and scheduler integration tasks.
