from services.backlog.controller import Controller
from services.backlog.backlog_store import BacklogStore
from pathlib import Path


def test_claim_next(tmp_path):
    db = tmp_path / "db.json"
    store = BacklogStore(path=db)
    store.add("task1")
    store.add("task2")
    ctrl = Controller(db_path=db)
    it = ctrl.claim_next("worker-1")
    assert it is not None
    assert it.owner == "worker-1"
    assert it.status == "claimed"


def test_release_and_complete(tmp_path):
    db = tmp_path / "db.json"
    store = BacklogStore(path=db)
    it = store.add("taskX")
    ctrl = Controller(db_path=db)
    claimed = ctrl.claim_next("wk")
    assert claimed is not None
    ok = ctrl.release(claimed.id)
    assert ok
    assert store.get(claimed.id).status == "open"
    claimed2 = ctrl.claim_next("wk2")
    assert claimed2 is not None
    ok = ctrl.complete(claimed2.id)
    assert ok
    # reload store to observe persisted state
    store2 = BacklogStore(path=db)
    assert store2.get(claimed2.id).status == "done"
