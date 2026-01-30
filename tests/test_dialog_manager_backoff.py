import json
from pathlib import Path
import time

from services.comm.dialog_manager import DialogManager


def test_backoff_calls_sleep(monkeypatch):
    sleeps = []

    def fake_sleep(sec):
        sleeps.append(sec)

    monkeypatch.setattr(time, "sleep", fake_sleep)

    dm = DialogManager(max_invalid_attempts=3)
    # provide empty replies to trigger invalid attempts and backoff sleeps
    res = dm.select_option(["a", "b"], responses=["", "", ""], backoff_initial=0.01, backoff_factor=2.0, backoff_max=0.05, human_origin=False)
    assert res is None
    # we expect two or three sleep calls (one per invalid attempt before final impediment)
    assert len(sleeps) >= 1
    # ensure backoff increases (approx)
    assert sleeps[0] > 0
    if len(sleeps) > 1:
        assert sleeps[1] >= sleeps[0]


def test_backoff_respects_max(monkeypatch):
    sleeps = []

    def fake_sleep(sec):
        sleeps.append(sec)

    monkeypatch.setattr(time, "sleep", fake_sleep)

    dm = DialogManager(max_invalid_attempts=4)
    res = dm.select_option(["a", "b"], responses=["", "", "", ""], backoff_initial=0.05, backoff_factor=4.0, backoff_max=0.06, human_origin=False)
    assert res is None
    # verify that no sleep value exceeds backoff_max
    assert all(s <= 0.06 + 1e-6 for s in sleeps)
