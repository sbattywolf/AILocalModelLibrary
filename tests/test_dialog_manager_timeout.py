import json
from pathlib import Path
import select
import time

from services.comm.dialog_manager import DialogManager


def test_timeout_escalation_writes_impediment(monkeypatch, tmp_path):
    # simulate select.select always returning no ready descriptors (timeout)
    def fake_select(r, w, x, timeout):
        return ([], [], [])

    monkeypatch.setattr(select, "select", fake_select)

    # patch sleep to avoid real waits
    sleeps = []

    def fake_sleep(s):
        sleeps.append(s)

    monkeypatch.setattr(time, "sleep", fake_sleep)

    # ensure impediments file removed
    imp = Path.cwd() / ".continue" / "impediments.json"
    if imp.exists():
        imp.unlink()

    dm = DialogManager(max_invalid_attempts=100)
    # call with timeout_seconds and timeout_retries set low to trigger escalation
    res = dm.select_option(["a", "b"], timeout_seconds=0.01, timeout_retries=2, backoff_initial=0.0, human_origin=False)
    assert res is None
    assert imp.exists()
    data = json.loads(imp.read_text())
    assert data[-1]["reason"] == "timeout_no_response"
