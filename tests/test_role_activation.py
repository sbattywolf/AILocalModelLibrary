from services.comm.role_arbiter import RoleArbiter, RoleDescriptor
import time


def test_activate_role_records_and_enqueues():
    arb = RoleArbiter()
    r = RoleDescriptor(name="worker", skills=["nlp"], allowed_network=False)
    arb.add_role(r)

    task = {"required_skills": ["nlp"], "complexity": 1}
    res = arb.activate_role("worker", task)
    assert res["status"] == "activated"
    activations = arb.get_activations()
    assert activations and activations[-1]["status"] == "activated"
    queue = arb.get_job_queue()
    assert queue and queue[-1]["role"] == "worker"


def test_activate_role_blocked_by_internet():
    arb = RoleArbiter()
    r = RoleDescriptor(name="wnet", skills=["web"], allowed_network=False)
    arb.add_role(r)

    task = {"required_skills": ["web"], "requires_internet": True}
    class DummyDM:
        def __init__(self):
            self.calls = []

        def _raise_impediment(self, reason, context, weight=1):
            self.calls.append((reason, context, weight))

    dm = DummyDM()
    res = arb.activate_role("wnet", task, dialog_manager=dm)
    assert res["status"] == "blocked_internet"
    activations = arb.get_activations()
    assert activations and activations[-1]["status"] == "blocked_internet"
    assert dm.calls, "DialogManager should have been notified on blocked internet activation"


def test_executor_respects_max_parallel_jobs(tmp_path):
    arb = RoleArbiter()
    # role allows 1 parallel job
    r = RoleDescriptor(name="runner", skills=["task"], allowed_network=False, max_parallel_jobs=1)
    arb.add_role(r)

    # enqueue two quick jobs that simulate a short duration
    arb.schedule_job("runner", {"simulate_duration": 0.05})
    arb.schedule_job("runner", {"simulate_duration": 0.05})

    arb.start_executor(num_threads=2)
    # wait for jobs to complete (bounded)
    timeout = 2.0
    start = time.time()
    while time.time() - start < timeout:
        queue = arb.get_job_queue()
        if not queue:
            break
        time.sleep(0.02)

    arb.stop_executor()
    acts = arb.get_activations()
    # Expect at least one completed activation
    completed = [a for a in acts if a.get("status") == "completed"]
    assert len(completed) >= 2
