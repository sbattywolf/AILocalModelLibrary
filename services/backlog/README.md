Backlog service prototype

This package provides a lightweight backlog store and a JIRA integration stub for testing two-agent workflows.

Commands:

- `python -m services.backlog` — run simple CLI to add/list backlog items.

Modules:

- `backlog_store.py` — simple JSON-backed persistent store.
- `jira_stub.py` — no-op adapter simulating JIRA interactions.
