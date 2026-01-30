from services.comm.dialog_manager import DialogManager
from pathlib import Path
import json


def test_select_numeric_option(tmp_path, monkeypatch):
    dm = DialogManager()
    res = dm.select_option(["A", "B", "C"], responses=["2"], human_origin=False)
    assert res == "B"


def test_short_code_reply(tmp_path):
    dm = DialogManager()
    res = dm.select_option(["A", "B"], responses=["y"], human_origin=False)
    assert res == "y"


def test_impediment_written(tmp_path):
    # use small max_invalid_attempts for test
    dm = DialogManager(max_options=3, max_invalid_attempts=2)
    # ensure impediments file path is inside repo .continue
    imp = Path.cwd() / ".continue" / "impediments.json"
    if imp.exists():
        imp.unlink()
    res = dm.select_option(["A", "B"], responses=["x", "", ""], human_origin=False)  # 2 invalid then third triggers
    assert res is None
    assert imp.exists()
    data = json.loads(imp.read_text())
    assert any(d.get("reason") == "too_many_invalid_replies" for d in data)
