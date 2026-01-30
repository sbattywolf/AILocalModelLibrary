from services.backlog.backlog_store import BacklogStore
from pathlib import Path
import tempfile


def test_add_and_list(tmp_path):
    db = tmp_path / "db.json"
    store = BacklogStore(path=db)
    assert store.list() == []
    item = store.add("task1", "desc")
    assert item.id == 1
    assert item.title == "task1"
    assert len(store.list()) == 1


def test_persist_and_load(tmp_path):
    db = tmp_path / "db.json"
    store = BacklogStore(path=db)
    store.add("t1")
    # reload
    s2 = BacklogStore(path=db)
    assert len(s2.list()) == 1


def test_update_status(tmp_path):
    db = tmp_path / "db.json"
    store = BacklogStore(path=db)
    it = store.add("t1")
    ok = store.update_status(it.id, "done")
    assert ok
    assert store.get(it.id).status == "done"
