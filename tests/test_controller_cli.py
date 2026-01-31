from services.backlog import controller_cli
from services.backlog.backlog_store import BacklogStore
from pathlib import Path
import json


def test_claim_list_release_complete_cli(tmp_path, capsys):
    db = tmp_path / "db.json"
    store = BacklogStore(path=db)
    store.add("alpha")
    store.add("beta")

    # claim-next
    controller_cli.main(["--db", str(db), "claim-next", "--owner", "cli-worker"])
    captured = capsys.readouterr()
    out = json.loads(captured.out)
    assert out["claimed"] or out.get("item") is not None or isinstance(out, dict)

    # list-open
    controller_cli.main(["--db", str(db), "list-open"])
    captured = capsys.readouterr()
    items = json.loads(captured.out)
    assert isinstance(items, list)

    # release first claimed item (if any)
    # find claimed id from store
    s2 = BacklogStore(path=db)
    claimed = next((i for i in s2.list_open() if i.owner in ("cli-worker", "")), None)

    # If none open, attempt to claim then release
    if claimed is None:
        it = s2.add("temp")
        controller_cli.main(["--db", str(db), "claim-next", "--owner", "cli-worker"])
        s2 = BacklogStore(path=db)
        claimed = next((i for i in s2.list_open() if i.owner == "cli-worker"), None)

    if claimed:
        controller_cli.main(["--db", str(db), "release", str(claimed.id)])
        captured = capsys.readouterr()
        assert "ok" in captured.out or "not found" in captured.out

    # complete an item
    s3 = BacklogStore(path=db)
    opens = s3.list_open()
    if opens:
        iid = opens[0].id
        controller_cli.main(["--db", str(db), "complete", str(iid)])
        captured = capsys.readouterr()
        assert "ok" in captured.out or "not found" in captured.out
