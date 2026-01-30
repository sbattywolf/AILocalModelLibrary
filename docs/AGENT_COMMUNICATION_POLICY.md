## Network / Internet Access

By default internet access is DISABLED. A workspace-level `network` policy controls whether agents may contact external services.

- `network.internet_access` (boolean): default `false`. When `false`, agents must not perform outbound internet requests.
- `network.internet_allowed_roles` (array): role names allowed to request internet access (e.g., `"controller"`).

If an agent requires internet access to complete a task and the policy disallows it, the agent MUST raise an impediment with reason `internet_required`. The impediment should include context describing the requested URL or service and a `weight` indicating urgency. Example policy snippet:

```json
"network": {
  "internet_access": false,
  "internet_allowed_roles": ["controller"]
}
```

Agents running with restricted roles should request escalation or delegate the internet-requiring step to a permitted role instead of performing the download themselves.
**Agent Communication Policy**

This document defines message formats, turn-taking, timeouts, escalation rules, and impediment handling for agents and humans interacting with the system.

- **Roles:**
  - **Controller:** orchestration agent that issues task lists and decisions.
  - **Worker:** execution agent performing tasks from the backlog.
  - **Manager:** human or agent that approves, claims, or reprioritizes tasks.
  - **Human:** external user; may reply with short-codes or full messages.

## Channels and Transport

We support two communication channels by configuration: `public` and `lan-secret`.

- **public**: Default channel. Internet-capable transports (HTTP, WebSocket, remote APIs) may be used. Use this channel for interactions that require external services or cloud-hosted agents. Do not send secrets or raw credentials over this channel unless the transport is end-to-end encrypted and you have explicit consent.

- **lan-secret**: Local/internal-only channel intended for sensitive messages inside a trusted LAN or single host. When using `lan-secret`, `secret_mode` MUST be enabled for agents that handle secrets. Messages written by LAN channels should be masked and stored only locally; by default no remote network endpoints are contacted.

Example configuration (add to `config.template.json` or `.continue/user_config.json`):

```json
"comm_channel": {
  "default": "public",
  "available": ["public", "lan-secret"]
}

"secret_mode": true
```

- **Reply formats (single-line):**
  - Numeric selection: `1`, `2`, ... (selects option index).
  - Short-code: single-letter codes optionally followed by a short explanation (<=20 words):
    - `y` — yes/accept
    - `n` — no/reject
    - `g` — go / proceed (may include reason, e.g. `g continue with step 2`)
    - `p` — pass / postpone

- **Validation rules:**
  - If reply starts with a recognized short-code, accept it only if the remainder is <=20 words. Longer messages are treated as invalid.
  - Numeric replies must be within the active option range after any truncation (Controller may limit to 10 options).
  - Invalid replies increment an `invalid_attempts` counter; on reaching `max_invalid_attempts` the DialogManager writes an impediment record to `.continue/impediments.json` and returns `None`.

- **Timeouts and retries:**
  - Agents should supply `timeout_seconds` when awaiting replies.
  - If a reply is not received within `timeout_seconds`, treat as a non-response and apply exponential backoff for retries (1s, 2s, 4s...) up to a retry cap. After retry cap, create an impediment.

- **Escalation & impediment:**
  - An impediment record format:
    - `timestamp` (ISO8601)
    - `source` (agent id)
    - `reason` (e.g. `too_many_invalid_replies`, `timeout_no_response`)
    - `payload` (the last N replies and context)
  - Impediments are written to `.continue/impediments.json` (append) and optionally surfaced to Controller for manual resolution.

- **Turn-taking:**
  - Controller issues one prompt to a Worker or Human, which must reply once; further prompts require a new short turn token.
  - Do not chain multiple decisions in a single short-code reply; use multiple turns.

- **Task generation limits:**
  - Controller must generate no more than 10 actionable tasks per message.

Examples:

- Valid short-code: `g proceed to step 2` (3 words after code)
- Invalid short-code: `g ` followed by 30 words — treated as invalid and counts toward attempts.

See also: `services/comm/dialog_manager.py` behavior and `tests/test_dialog_manager_policy.py` for automated checks.
# Agent Communication Policy

Purpose
- A short, human-readable protocol for agent↔agent and agent↔human communication.
- Designed for clarity, traceability, and safe automated decision-making.

Principles
- Keep messages concise and action-oriented.
- Prefer structured replies where possible (short codes + optional note).
- Ephemeral commands use single-letter codes (`y`,`n`,`g`,`p`) to limit ambiguity.

Role annotations
- **Controller**: authoritative coordinator; may increase priority of tasks by +20%.
- **Manager / Regista**: organizes backlog, splits epics/features, issues assignments.
- **Worker / Agent**: executes tasks, reports progress and signals impediments.
- **Human**: reviewer/approver; may override or confirm actions.

Reply codes (preferred)
- `y` — yes / accept / acknowledge
- `n` — no / reject
- `g` — go on / next (proceed to next step or provide more info)
- `p` — proceed (start execution now)

Guidelines for usage
- When a controller requests a decision, agents should reply only with one of the codes above, optionally followed by a single brief sentence (max 20 words) explaining context.
- If a decision needs more than a code, send `g` then a short message describing the required clarification.
- Controllers may accept multiple `g` responses before issuing `p` to start execution.

Status & progress reporting
- Every agent must expose and update a status object: { state, progress, last_update, current_task_id }.
  - `state`: one of `idle`, `queued`, `running`, `blocked`, `done`, `error`.
  - `progress`: 0..100 integer percent.
  - `last_update`: ISO8601 timestamp.
  - `current_task_id`: backlog identifier or null.
- Agents must emit a status update at least on: start, 25%, 50%, 75%, completion, and on any error.
- Agents should self-adjust polling/heartbeats based on load and task complexity (ex: low load -> poll 30s, high load -> 5s).

Task generation rule
- When asked to build a TODO sprint, agents must produce at most 10 tasks.
- Each task: { id, title, estimate_pts, priority_rank } and be ordered by priority.
- Controller-sourced tasks receive +20% effective priority weight for sorting/assignment.

Priority encoding
- Use numeric ranks 1..5 (1=highest). When weights are summed, apply controller bonus (+20%) before sorting.

Impediment handling
- If an agent replies `n` or reports `state: blocked`, it must include a short impediment note and an optional suggested mitigation.
- Controller should log impediments and either reassign, escalate to Human, or issue `g` for clarification.

Example exchange
- Controller -> Agent: "Start task T123? (expect quick run)" 
- Agent -> Controller: `g` "Need env var X set" 
- Controller -> Agent: `p` 
- Agent status updates: running 0%, 25%, 50%, 75%, 100% (done)

Operational notes
- Always persist status and task events to the backlog store to maintain an audit trail.
- Keep communication channels authenticated and encrypted.
- Prefer idempotent commands; design for safe retries.

Change control
- Document policy changes in `docs/AGENT_COMMUNICATION_POLICY.md` and update the changelog.

---
Be concise in messages, prefer structured replies, and ensure traceable status updates.
