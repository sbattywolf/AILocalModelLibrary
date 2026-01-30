from services.comm.channel_lan_secret import LanSecretChannel
from pathlib import Path


def test_lan_secret_send_masks_and_writes(tmp_path):
    # create a fake user_config with secret_mode true and a known secret
    cfg = tmp_path / "user_config.json"
    cfg.write_text('{"secret_mode": true, "secrets": {"DUMMY": {"env_var": "DUMMY"}}}', encoding="utf-8")
    # set environment secret so mask_text will pick it up
    import os

    os.environ["DUMMY"] = "supersecret"

    audit = tmp_path / "lan_audit.log"
    ch = LanSecretChannel(user_cfg=str(cfg))
    ok = ch.send("this has supersecret inside", audit_file=str(audit))
    assert ok is True
    content = audit.read_text(encoding="utf-8")
    assert "<REDACTED>" in content
