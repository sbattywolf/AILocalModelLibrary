import os
import json
from pathlib import Path

from services.comm.dialog_manager import DialogManager
from services import secrets as secrets_mod


def test_impediment_masks_known_env_secret(monkeypatch, tmp_path):
    # set a fake secret in env and in user_config
    os.environ["GITHUB_PAT"] = "ghp_FAKESECRET1234567890"

    # ensure user_config references GITHUB_PAT
    cfg = Path.cwd() / ".continue" / "user_config.json"
    data = json.loads(cfg.read_text())
    assert "GITHUB_PAT" in data.get("secrets", {})

    # simulate replies including the secret
    dm = DialogManager(default_secret_mode=True)
    imp = Path.cwd() / ".continue" / "impediments.json"
    if imp.exists():
        imp.unlink()

    # trigger an impediment via invalid replies (non-human strict)
    res = dm.select_option(["A", "B"], responses=["nope", os.environ["GITHUB_PAT"], ""], human_origin=False, backoff_initial=0.0)
    assert res is None
    assert imp.exists()
    raw = imp.read_text()
    # secret should not appear in the impediments file
    assert os.environ["GITHUB_PAT"] not in raw
    assert "<REDACTED>" in raw
