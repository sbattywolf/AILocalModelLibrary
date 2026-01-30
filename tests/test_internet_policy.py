import json
import os
from pathlib import Path

from services.comm import internet_policy


def test_is_internet_allowed_by_role(tmp_path):
    cfg_dir = tmp_path / ".continue"
    cfg_dir.mkdir()
    cfg = cfg_dir / "user_config.json"
    cfg.write_text(json.dumps({"network": {"internet_access": False, "internet_allowed_roles": ["controller"]}}))

    # role allowed
    assert internet_policy.is_internet_allowed(path=str(cfg), role="controller") is True
    # other role denied
    assert internet_policy.is_internet_allowed(path=str(cfg), role="worker") is False


def test_require_internet_or_impediment_raises(tmp_path):
    cfg_dir = tmp_path / ".continue"
    cfg_dir.mkdir()
    cfg = cfg_dir / "user_config.json"
    cfg.write_text(json.dumps({"network": {"internet_access": False, "internet_allowed_roles": []}}))

    class DummyDM:
        def __init__(self):
            self.calls = []

        def _raise_impediment(self, reason, context, weight=1):
            self.calls.append((reason, context, weight))

    dm = DummyDM()
    ok = internet_policy.require_internet_or_impediment(dm, reason="internet_required", context={"task": "download"}, path=str(cfg), role="worker")
    assert ok is False
    assert dm.calls, "Impediment should have been raised"
    reason, context, weight = dm.calls[0]
    assert reason == "internet_required"
    assert context.get("role") == "worker" or context.get("requested_by") == "worker"
