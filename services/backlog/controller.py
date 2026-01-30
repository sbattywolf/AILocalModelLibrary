"""Minimal controller wrapping BacklogStore for local agents."""
from __future__ import annotations

from typing import Optional
from services.backlog.backlog_store import BacklogStore, BacklogItem
from pathlib import Path


class Controller:
    def __init__(self, db_path: Optional[Path] = None):
        self.store = BacklogStore(path=db_path)

    def claim_next(self, owner: str) -> Optional[BacklogItem]:
        opens = self.store.list_open()
        if not opens:
            return None
        item = opens[0]
        ok = self.store.claim(item.id, owner)
        return self.store.get(item.id) if ok else None

    def release(self, item_id: int) -> bool:
        return self.store.release(item_id)

    def complete(self, item_id: int) -> bool:
        return self.store.complete(item_id)

    def list_open(self):
        return self.store.list_open()
