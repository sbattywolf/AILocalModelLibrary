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


def test_claim_release_complete(tmp_path):
    db = tmp_path / "db.json"
    store = BacklogStore(path=db)
    it = store.add("t-claim")
    assert it.status == "open"
    ok = store.claim(it.id, "worker-1")
    assert ok
    got = store.get(it.id)
    assert got.status == "claimed"
    assert got.owner == "worker-1"
    ok = store.release(it.id)
    assert ok
    got = store.get(it.id)
    assert got.status == "open"
    assert got.owner is None
    ok = store.claim(it.id, "worker-2")
    assert ok
    ok = store.complete(it.id)
    assert ok
    assert store.get(it.id).status == "done"
