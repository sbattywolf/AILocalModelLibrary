from services.comm.channel_public import PublicChannel
import json


def test_public_channel_send_denied_by_role(tmp_path, capsys):
    cfg = tmp_path / "cfg.json"
    cfg.write_text(json.dumps({}), encoding="utf-8")
    # default policy (no network) — ensure send blocked when role not allowed
    ch = PublicChannel(config_path=str(cfg))
    ok = ch.send("attempt remote", role="worker")
    assert ok is False
    out = capsys.readouterr().out
    assert "blocked send" in out


def test_public_channel_send_allowed_when_role_permitted(tmp_path, capsys):
    cfg = tmp_path / "cfg.json"
    cfg.write_text(json.dumps({"network": {"internet_access": False, "internet_allowed_roles": ["worker"]}}), encoding="utf-8")
    ch = PublicChannel(config_path=str(cfg))
    ok = ch.send("remote ok", role="worker")
    assert ok is True
    out = capsys.readouterr().out
    assert "send: remote ok" in out
