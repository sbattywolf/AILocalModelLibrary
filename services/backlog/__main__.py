"""Simple CLI for backlog service."""
from __future__ import annotations

import argparse
from pathlib import Path
from services.backlog.backlog_store import BacklogStore


def main(argv=None):
    p = argparse.ArgumentParser()
    p.add_argument("command", choices=["list", "add", "status"], help="command")
    p.add_argument("--title", help="title for add")
    p.add_argument("--description", help="description for add")
    p.add_argument("--id", type=int, help="id for status update")
    p.add_argument("--status", help="new status")
    args = p.parse_args(argv)

    store = BacklogStore(path=Path.cwd() / "services" / "backlog" / "backlog_store.json")

    if args.command == "list":
        for it in store.list():
            print(f"{it.id}: {it.title} ({it.status})")
    elif args.command == "add":
        if not args.title:
            p.error("--title required for add")
        item = store.add(args.title, args.description)
        print(f"added {item.id}")
    elif args.command == "status":
        if not args.id or not args.status:
            p.error("--id and --status required for status")
        ok = store.update_status(args.id, args.status)
        print("ok" if ok else "not found")


if __name__ == "__main__":
    main()
