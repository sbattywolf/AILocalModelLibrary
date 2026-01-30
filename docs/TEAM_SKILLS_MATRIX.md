<!--
Team Skills Matrix proposal
This document defines the team/agent skills matrix, constraints (max 3 skills per member), proposed skill presets, distribution options, and suggested team architectures.
-->
# Team Skills Matrix — Proposal

**Purpose:**
- Define a consistent skills matrix for teams and agents so schedulers, monitors, and humans can reason about capability coverage and surface candidates for tasks.

**Constraints:**
- Each team member (agent) may have up to **3** skills assigned.
- Teams have a *team-skill set* (union of member skills). Teams may list additional *team-presets* for common roles.

**Deliverables:**
- A suggested preset list of skills for the project.
- A recommended distribution plan mapping presets to teams and agents (max 3 per agent).
- Suggested team/agent architecture options (flat, matrix, hub-spoke). 
- A diagram visualizing teams, agents and skill coverage.

## 1) Suggested skill presets (extended)
- Core: `inference`, `vram-heavy`, `fast-response`, `low-latency`
- Data & Ops: `data-prep`, `ingest`, `monitoring`, `telemetry`
- Dev & Test: `unit-test`, `integration-test`, `fuzzing`
- LLM-related: `prompt-engineering`, `fewshot`, `chain-of-thought`
- Infra: `gpu-admin`, `container`, `vm-orchestration`, `network`
- UX/Automation: `cli`, `webhook`, `notebook`

These presets form a superset; concrete teams will pick relevant subsets.

## 2) Distribution proposal (teams -> agents)

- Principle: ensure each team has coverage for at least one `inference` and one `monitoring`-adjacent skill.
- For small teams (3–5 agents): distribute so each agent has 2 skills on average, with at least one agent having `vram-heavy`.
- For medium teams (6–10 agents): aim for each skill category to have 2+ agents.

Example distribution (Infra team, 4 agents):

- infra-agent-1: `gpu-admin`, `vram-heavy`, `container`
- infra-agent-2: `container`, `vm-orchestration`
- infra-agent-3: `monitoring`, `telemetry`
- infra-agent-4: `network`, `cli`

Example distribution (Runtime team, 5 agents):

- runtime-agent-1: `inference`, `fast-response`, `prompt-engineering`
- runtime-agent-2: `inference`, `fewshot`
- runtime-agent-3: `monitoring`, `telemetry`
- runtime-agent-4: `integration-test`, `unit-test`
- runtime-agent-5: `low-latency`, `vram-heavy`

## 3) Team architecture proposals

- Flat: all agents equal peers, scheduler picks by skill/vram/capacity. Good for small teams.
- Hub-Spoke: one hub agent provides coordination and heavy `vram-heavy` tasks; spokes provide specialized skills and offload. Good when one node has larger GPU resources.
- Matrix: team-level roles (e.g., inference, testing, ops) mapped across members — each member contributes to multiple roles (up to 3 skills). This increases resilience and avoids single points of failure.

## 4) Diagram (mermaid)
```mermaid
graph LR
  subgraph Infra Team
    I1[infra-agent-1\n(gpu-admin,vram-heavy,container)]
    I2[infra-agent-2\n(container,vm-orchestration)]
    I3[infra-agent-3\n(monitoring,telemetry)]
    I4[infra-agent-4\n(network,cli)]
  end

  subgraph Runtime Team
    R1[runtime-agent-1\n(inference,fast-response,prompt-engineering)]
    R2[runtime-agent-2\n(inference,fewshot)]
    R3[runtime-agent-3\n(monitoring,telemetry)]
    R4[runtime-agent-4\n(integration-test,unit-test)]
    R5[runtime-agent-5\n(low-latency,vram-heavy)]
  end

  I3 --> R3
  I1 --> R1
  I1 --> R5
  R1 --> R2
  R4 --> R2
```

## 5) Implementation steps (next actions)
1. Finalize skill preset list and publish JSON schema extension (`schemas/skills.schema.json`).
2. Pick canonical team presets (Infra, Runtime, Dev, QA) and create `.continue/team-presets.json`.
3. Annotate `.continue/agent-roles.json` entries with up to 3 skills each; add Pester tests enforcing the 3-skill max.
4. Add scheduler acceptance test: ensure scheduler respects skill-matrix and prefers agents covering missing skills.
5. Add docs and a short PR template for skill changes (who can add new skills, how to deprecate).

## 6) Notes & rationale
- Limiting skills per agent to 3 keeps agent profiles readable and schedulable; complex multi-capability agents should be modeled as composites.
- Team-level presets allow simple recruiter-like queries: "find an agent in team X with skill Y".

## 7) Next
- If this looks good I will:
  - add the schema file and the `team-presets.json` sample,
  - add Pester tests enforcing `max 3 skills` per agent,
  - and annotate existing `.continue/agent-roles.json` with suggested skills for a first pass.

---
Generated: January 30, 2026
