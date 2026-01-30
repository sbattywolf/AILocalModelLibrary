"""Simple JSON-backed backlog store."""
from __future__ import annotations

import json
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import List, Optional

DEFAULT_DB = Path.cwd() / "services" / "backlog" / "backlog_store.json"

@dataclass
class BacklogItem:
    id: int
    title: str
    description: Optional[str] = None
    status: str = "open"


class BacklogStore:
    def __init__(self, path: Optional[Path] = None):
        self.path = Path(path) if path else DEFAULT_DB
        self._items: List[BacklogItem] = []
        self._load()

    def _load(self):
        if not self.path.exists():
            self._items = []
            return
        try:
            data = json.loads(self.path.read_text(encoding="utf-8-sig"))
            self._items = [BacklogItem(**it) for it in data]
        except Exception:
            self._items = []

    def _persist(self):
        self.path.write_text(json.dumps([asdict(i) for i in self._items], indent=2), encoding="utf-8")

    def list(self) -> List[BacklogItem]:
        return list(self._items)

    def add(self, title: str, description: Optional[str] = None) -> BacklogItem:
        nid = 1 if not self._items else max(i.id for i in self._items) + 1
        item = BacklogItem(id=nid, title=title, description=description)
        self._items.append(item)
        self._persist()
        return item

    def get(self, item_id: int) -> Optional[BacklogItem]:
        for it in self._items:
            if it.id == item_id:
                return it
        return None

    def update_status(self, item_id: int, status: str) -> bool:
        it = self.get(item_id)
        if not it:
            return False
        it.status = status
        self._persist()
        return True
