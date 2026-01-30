# Backlog Service

This folder contains a lightweight JSON-backed backlog service used for local controller workflows.

Usage

- Claim the next open item for an owner:

  python -m services.backlog.controller_cli claim-next --owner alice --db .continue/backlog.json

- List open items:

  python -m services.backlog.controller_cli list-open --db .continue/backlog.json

- Release a claimed item:

  python -m services.backlog.controller_cli release <item_id> --db .continue/backlog.json

- Complete an item:

  python -m services.backlog.controller_cli complete <item_id> --db .continue/backlog.json

Notes

- The backlog is file-backed (JSON) for the prototype; the `--db` path points to the JSON file.
- See `services/backlog/backlog_store.py` for data model and API details.
- Unit tests live under `tests/` and can be run with `pytest`.

Contributing

- Keep changes minimal and add tests for new behaviors.
Backlog service prototype

This package provides a lightweight backlog store and a JIRA integration stub for testing two-agent workflows.

Commands:

- `python -m services.backlog` — run simple CLI to add/list backlog items.

Modules:

- `backlog_store.py` — simple JSON-backed persistent store.
- `jira_stub.py` — no-op adapter simulating JIRA interactions.
