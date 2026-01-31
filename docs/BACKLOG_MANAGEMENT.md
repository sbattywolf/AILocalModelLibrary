# Backlog management: Epics, Features, Stories, Tasks, Todos

This short guide defines a simple hierarchy and workflow for managing backlog items and mapping them to agent teams and roles.

Hierarchy
- Epic -> 1..n Features
- Feature -> 1..n Stories
- Story -> 1..m Tasks
- Task -> 1..k Todo items (fine-grained actionable work)

Guidelines
- Each Epic should have an owner (team or person) and a clear goal.
- Features are scope-bounded chunks inside an Epic; assign one feature lead.
- Stories describe user-/operator-facing behavior and acceptance criteria.
- Tasks are implementation steps with clear owners and estimates.
- Todo items are small actions that can be picked up by agents or developers.

Mapping to agents
- Tag todo items with `team` and `role` fields so agent selectors can pick them.
- Agents will select tasks based on their `skills` and `capabilities` (vramGB, cpu, memory).
- For parent-child agent scenarios: allow stories to create child tasks that can be executed in parallel by junior agents (limit: 1 parent -> max 2 children).

Backlog grooming
- Hold a short grooming session to split Epics -> Features -> Stories and prioritize top N stories.
- Maintain a `backlog.json` (or use the repo `manage_todo_list` tool) with explicit `team` and `role` fields.

Automation
- The `scripts/export-todos-dashboard.ps1` (added) reads a todo JSON and produces a Markdown dashboard grouped by `team` and `role` for easy review.

Next steps
- Add validation and CI checks for `backlog.json` shapes.
- Integrate backlog dashboard generation into a PR-comment GitHub Action or scheduled job.
