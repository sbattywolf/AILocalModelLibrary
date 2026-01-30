"""Agent network CLI

Usage examples:
  python scripts/agent_net_cli.py --role worker --check
  python scripts/agent_net_cli.py --role worker --require-internet --impediment

This CLI checks `services.comm.internet_policy` and optionally raises an impediment
via `services.comm.dialog_manager.DialogManager` when internet is required but disabled.
"""
from __future__ import annotations

import argparse
import sys
from typing import Optional

from services.comm import internet_policy


def main(argv: Optional[list[str]] = None) -> int:
    p = argparse.ArgumentParser(prog="agent_net_cli")
    p.add_argument("--role", required=True, help="Agent role (e.g., worker, controller)")
    p.add_argument("--check", action="store_true", help="Print whether internet is allowed")
    p.add_argument("--require-internet", action="store_true", help="Simulate a task that requires internet")
    p.add_argument("--impediment", action="store_true", help="If internet disallowed, raise impediment via DialogManager")
    args = p.parse_args(argv)

    allowed = internet_policy.is_internet_allowed(role=args.role)
    if args.check:
        print(f"internet_allowed={allowed}")

    if args.require_internet:
        if allowed:
            print("Internet access permitted by policy. Proceeding.")
            return 0
        # not allowed — either raise impediment or exit non-zero
        if args.impediment:
            try:
                from services.comm.dialog_manager import DialogManager

                dm = DialogManager()
                internet_policy.require_internet_or_impediment(dm, reason="internet_required", context={"requested_by": args.role}, role=args.role)
                print("Impediment raised: internet_required")
                return 0
            except Exception as e:
                print("Failed to raise impediment:", e, file=sys.stderr)
                return 2
        else:
            print("Internet access required but disabled by policy", file=sys.stderr)
            return 3

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
