from services.comm.role_arbiter import RoleArbiter, RoleDescriptor
import time
import asyncio


def test_register_handler_and_invoke(tmp_path):
    arb = RoleArbiter()
    r = RoleDescriptor(name="handler_role", skills=["task"], allowed_network=False, max_parallel_jobs=2)
    arb.add_role(r)

    called = []

    def my_handler(task_ctx):
        # record the call and return a status dict
        called.append(task_ctx)
        # simulate small work
        time.sleep(0.02)
        return {"status": "ok", "result": "done"}

    arb.register_handler("handler_role", my_handler)
    arb.schedule_job("handler_role", {"job_id": 1})
    arb.start_executor(num_threads=1)

    # wait for job to be processed
    timeout = 2.0
    start = time.time()
    while time.time() - start < timeout:
        if not arb.get_job_queue():
            break
        time.sleep(0.01)

    arb.stop_executor()

    assert called, "Handler should have been invoked"
    acts = arb.get_activations()
    assert any(a.get("status") == "ok" for a in acts), "Activation should record handler status"


def test_async_handler_invoked(tmp_path):
    arb = RoleArbiter()
    r = RoleDescriptor(name="async_role", skills=["task"], allowed_network=False)
    arb.add_role(r)

    called = []

    async def async_handler(task_ctx):
        called.append(task_ctx)
        await asyncio.sleep(0.02)
        return {"status": "async_ok", "result": "done"}

    arb.register_handler("async_role", async_handler)
    arb.schedule_job("async_role", {"job_id": 2})
    arb.start_executor(num_threads=1)

    timeout = 2.0
    start = time.time()
    while time.time() - start < timeout:
        if not arb.get_job_queue():
            break
        time.sleep(0.01)

    arb.stop_executor()

    assert called, "Async handler should have been invoked"
    acts = arb.get_activations()
    # handler returns status "async_ok"; the arbiter normalizes statuses for dict returns
    assert any(a.get("status") == "async_ok" for a in acts) or any(a.get("status") == "ok" for a in acts), "Activation should record async handler status"


def test_per_job_handler_override(tmp_path):
    arb = RoleArbiter()
    r = RoleDescriptor(name="override_role", skills=["task"], allowed_network=False)
    arb.add_role(r)

    called = []

    def override_handler(task_ctx):
        called.append(task_ctx)
        return {"status": "overridden", "result": "ok"}

    # schedule job with per-job handler in task_ctx
    arb.schedule_job("override_role", {"job_id": 3, "handler": override_handler})
    arb.start_executor(num_threads=1)

    timeout = 2.0
    start = time.time()
    while time.time() - start < timeout:
        if not arb.get_job_queue():
            break
        time.sleep(0.01)

    arb.stop_executor()

    assert called, "Per-job override handler should have been invoked"
    acts = arb.get_activations()
    assert any(a.get("status") == "overridden" for a in acts), "Activation should record overridden handler status"
