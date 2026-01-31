import time

from services.comm.role_arbiter import RoleArbiter, RoleDescriptor


def test_dialog_manager_job_hooks():
    arb = RoleArbiter()
    arb.add_role(RoleDescriptor(name="coach", skills=["motivation"], allowed_network=True))
    calls = {"started": [], "completed": [], "activated": []}

    class DummyDM:
        def on_job_started(self, role, task):
            calls["started"].append((role, task))

        def on_job_completed(self, role, task, status):
            calls["completed"].append((role, task, status))

        def on_activation(self, role, status):
            calls["activated"].append((role, status))

    dm = DummyDM()

    # register a simple quick handler
    def handler(task):
        return {"status": "done", "result": "ok"}

    arb.register_handler("coach", handler)
    # start executor with dialog manager
    arb.start_executor(num_threads=1, dialog_manager=dm)
    arb.activate_role("coach", {"simulate_duration": 0})

    # wait briefly for background thread to process job
    deadline = time.time() + 2.0
    while time.time() < deadline and not calls["completed"]:
        time.sleep(0.01)

    arb.stop_executor(wait=True)

    assert calls["started"], "on_job_started was not called"
    assert calls["completed"], "on_job_completed was not called"
    assert calls["activated"], "on_activation was not called"
