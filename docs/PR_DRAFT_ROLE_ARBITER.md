PR draft: RoleArbiter — pluggable handlers, async support, docs

Summary

This branch introduces pluggable job handlers for `RoleArbiter`, async handler support, per-job handler overrides, type hints, and documentation/examples.

What changed

- services/comm/role_arbiter.py
  - Added `Handler` type alias and `register_handler()` with type hints.
  - Worker loop now invokes registered handlers (sync or async via `asyncio.run`) and records activation statuses.
  - Supports per-job override via `task_ctx['handler']`.
- docs/ROLE_ARBITER_HANDLERS.md — usage examples for sync/async/per-job handlers.
- README.md — small section linking handler docs and quick example.
- tests/test_role_handlers.py — new tests covering handler invocation, async handlers, and per-job overrides.

Motivation

Allow callers to register real work handlers with `RoleArbiter` so scheduled jobs can run real code instead of simulated sleeps. Handlers can be synchronous or asynchronous; per-job overrides allow ad-hoc behavior.

Testing

- Unit tests added/updated; full test suite passes locally: `33 passed`.

Notes

- Current implementation uses `asyncio.run` per handler invocation (simple approach). A backlog TODO has been added to implement a shared async executor for improved performance with many/long-running coroutine handlers.

Requested reviewers / follow-ups

- Consider implementing a shared async loop or pooled executor for high-throughput async handlers.
- Review activation/event recording shape and whether more structured events are needed.

Branch name: `feature/role-arbiter-handlers`

