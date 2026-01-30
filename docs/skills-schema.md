# Skills Schema

This document explains the `skills` schema added to `config.template.json` and used in `.continue/agent-roles.json`.

- Format: `category:capability` (examples: `nlp:code-review`, `ops:monitoring`, `analysis:data-summary`).
- Purpose: allow the monitor/scheduler and autoscale controller to match roles and compose composite agents based on capability tags rather than only `primaryRole`.
- Guidance:
  - Keep tags short and namespaced by category.
  - Use '-' for multi-word capability names: `nlp:prompt-eval`.
  - Prefer existing categories: `nlp`, `ops`, `vision`, `analysis`.

Choices made in this iteration:
- Schema is advisory (free-form strings) to keep compatibility and avoid strict validation failures across environments.
- Representative skills were added to `.continue/agent-roles.json` for `Low-*` tester agents to seed tests and composition logic.

Next steps planned:
- Add a Pester test that validates `skills` presence and examples across agents.
- Extend the scheduler to support `PreferSkill` option and composite agent proposals.
