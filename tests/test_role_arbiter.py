from services.comm.role_arbiter import RoleArbiter, RoleDescriptor


def test_role_arbiter_nomination_with_network():
    arb = RoleArbiter()
    r1 = RoleDescriptor(name="worker", skills=["nlp"], allowed_network=False)
    r2 = RoleDescriptor(name="web-worker", skills=["nlp", "web"], allowed_network=True)
    arb.add_role(r1)
    arb.add_role(r2)

    task = {"required_skills": ["web"], "requires_internet": True, "complexity": 1}
    res = arb.evaluate(task)
    assert res["role"] == "web-worker"
    assert res["needs_internet"] is False
    assert res["est_seconds"] is not None


def test_role_arbiter_no_network_available():
    arb = RoleArbiter()
    r1 = RoleDescriptor(name="worker", skills=["nlp"], allowed_network=False)
    arb.add_role(r1)

    task = {"required_skills": ["web"], "requires_internet": True}
    class DummyDM:
        def __init__(self):
            self.calls = []

        def _raise_impediment(self, reason, context, weight=1):
            self.calls.append((reason, context, weight))

    dm = DummyDM()
    res = arb.evaluate(task, dialog_manager=dm)
    assert res["role"] is None
    assert res["needs_internet"] is True
    assert dm.calls, "DialogManager should have been notified of missing internet"
