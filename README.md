# AILocalModelLibrary

IMPORTANT: Read this before setup — see [docs/README_FIRST.md](docs/README_FIRST.md)

## Monitor

See [docs/MONITOR_BACKGROUND.md](docs/MONITOR_BACKGROUND.md) for how to run the background monitor and interpret outputs.

## RoleArbiter handlers

The `RoleArbiter` supports pluggable handlers for running scheduled jobs. See [docs/ROLE_ARBITER_HANDLERS.md](docs/ROLE_ARBITER_HANDLERS.md) for examples of synchronous, asynchronous, and per-job override handlers.

Quick example:

```python
from services.comm.role_arbiter import RoleArbiter, RoleDescriptor

arb = RoleArbiter()
arb.add_role(RoleDescriptor(name="worker", skills=["task"]))

def handler(ctx):
	return {"status": "ok", "result": "done"}

arb.register_handler("worker", handler)
arb.schedule_job("worker", {"job_id": 1})
arb.start_executor(num_threads=1)
```
# AILocalModelLibrary