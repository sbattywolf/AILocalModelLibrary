from services.comm.dialog_manager import DialogManager
from pathlib import Path
import json


def test_accept_code_with_short_message():
    dm = DialogManager()
    # code + short message (<=20 words) should be accepted and returned
    res = dm.select_option(["A", "B"], responses=["g please continue with step 2"], human_origin=False)
    assert res.startswith("g ")
    assert "please continue" in res


def test_reject_code_with_long_message(tmp_path):
    # make max_invalid_attempts small to trigger impediment
    dm = DialogManager(max_invalid_attempts=2)
    imp = Path.cwd() / ".continue" / "impediments.json"
    if imp.exists():
        imp.unlink()
    long_msg = "g " + "word " * 25
    # two invalid replies should create impediment
    res = dm.select_option(["A", "B"], responses=[long_msg, "x", ""], human_origin=False)  # long, invalid, then exhausted
    assert res is None
    assert imp.exists()
    data = json.loads(imp.read_text())
    assert any(d.get("reason") == "too_many_invalid_replies" for d in data)


def test_numeric_out_of_range_with_truncation():
    dm = DialogManager(max_options=3)
    # provide 5 options, but dialog manager will truncate to 3
    options = [f"opt{i}" for i in range(1, 6)]
    # selecting '4' should be invalid for truncated list, causing an impediment after attempts
    res = dm.select_option(options, responses=["4", "4", "4", "4", "4", "4", "4", "4", "4", "4"], human_origin=False) 
    # With default max_invalid_attempts=10, after 10 invalid replies it should return None
    assert res is None


def test_accept_long_message_if_human_origin():
    dm = DialogManager()
    long_msg = "g " + "word " * 25
    # when flagged as human_origin, long explanatory tails are accepted
    res = dm.select_option(["A", "B"], responses=[long_msg], human_origin=True)
    assert res.startswith("g ")


def test_impediment_format_on_too_many_invalid_replies(tmp_path):
    dm = DialogManager(max_invalid_attempts=2)
    imp = Path.cwd() / ".continue" / "impediments.json"
    if imp.exists():
        imp.unlink()
    # trigger invalid replies to create an impediment
    res = dm.select_option(["one", "two"], responses=["bad", "bad", "bad"], human_origin=False)
    assert res is None
    assert imp.exists()
    data = json.loads(imp.read_text())
    entry = data[-1]
    assert "reason" in entry and entry["reason"] == "too_many_invalid_replies"
    assert "timestamp" in entry
    # basic ISO8601 sanity check
    assert "T" in entry["timestamp"] and entry["timestamp"].endswith("Z") or "+00:00" in entry["timestamp"]
