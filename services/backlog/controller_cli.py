"""CLI for controller: claim-next, list-open, release, complete."""
from __future__ import annotations

import argparse
import json
from services.backlog.controller import Controller
from pathlib import Path


def main(argv=None):
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd")

    s_claim = sub.add_parser("claim-next")
    s_claim.add_argument("--owner", required=True)

    s_list = sub.add_parser("list-open")

    s_release = sub.add_parser("release")
    s_release.add_argument("id", type=int)

    s_complete = sub.add_parser("complete")
    s_complete.add_argument("id", type=int)

    args = p.parse_args(argv)
    controller = Controller(db_path=Path.cwd() / "services" / "backlog" / "backlog_store.json")

    if args.cmd == "claim-next":
        it = controller.claim_next(args.owner)
        print(json.dumps({"claimed": it is not None, "item": it.__dict__ if it else None}, indent=2))
    elif args.cmd == "list-open":
        items = controller.list_open()
        print(json.dumps([i.__dict__ for i in items], indent=2))
    elif args.cmd == "release":
        ok = controller.release(args.id)
        print("ok" if ok else "not found")
    elif args.cmd == "complete":
        ok = controller.complete(args.id)
        print("ok" if ok else "not found")


if __name__ == "__main__":
    main()
