RoleArbiter Handler Usage

This document shows examples for registering and using job handlers with `RoleArbiter`.

Handler signature

- A handler accepts a single argument `task_ctx` (a `dict`).
- It may be a synchronous function or an `async def` coroutine function.
- It may return `None` or a dict-like status object, for example:
  - `{"status": "ok", "result": <anything>}`
  - `{"status": "failed", "result": <error info>}`
- If a handler is asynchronous, the arbiter will run it and await the result.

Examples

1) Registering a synchronous handler

```python
from services.comm.role_arbiter import RoleArbiter, RoleDescriptor

arb = RoleArbiter()
role = RoleDescriptor(name="sync_role", skills=["task"], allowed_network=False)
arb.add_role(role)

def my_handler(task_ctx):
    # do work
    return {"status": "ok", "result": "done"}

arb.register_handler("sync_role", my_handler)
arb.schedule_job("sync_role", {"job_id": 1})
arb.start_executor(num_threads=1)
```

2) Registering an async handler

```python
import asyncio
from services.comm.role_arbiter import RoleArbiter, RoleDescriptor

arb = RoleArbiter()
role = RoleDescriptor(name="async_role", skills=["task"], allowed_network=False)
arb.add_role(role)

async def my_async_handler(task_ctx):
    await asyncio.sleep(0.1)
    return {"status": "ok", "result": "async-done"}

arb.register_handler("async_role", my_async_handler)
arb.schedule_job("async_role", {"job_id": 2})
arb.start_executor(num_threads=1)
```

3) Per-job handler override

```python
# You can pass a callable in the task context to override the registered handler
arb.schedule_job("some_role", {"job_id": 3, "handler": lambda ctx: {"status": "ok"}})
```

Notes

- The `RoleArbiter` normalizes handler return values and records activations with a `status` and optional `result` field.
- For long-running async workloads you may prefer a shared asyncio loop or an external worker pool. The current implementation uses `asyncio.run` per handler for simplicity.
