from services.comm.channel_public import PublicChannel


def test_public_channel_send_and_receive(tmp_path, capsys):
    cfg = tmp_path / "cfg.json"
    cfg.write_text("{}", encoding="utf-8")
    ch = PublicChannel(config_path=str(cfg))
    ok = ch.send("hello world")
    assert ok is True
    # send prints to stdout in the stub
    captured = capsys.readouterr()
    assert "hello world" in captured.out
    assert ch.receive() is None
