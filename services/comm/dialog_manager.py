"""Dialog manager enforcing up-to-10-option communications between agent and human.

Behavior (defaults):
- max_options limited to 10.
- default expected short replies: 'y' (yes), 'n' (no), 'g' (next), 'p' (proceed).
- numeric replies 1..N are accepted to select options.
- agent provides `timeout_seconds` and may decide allowed options.
- after `max_invalid_attempts` (default 10) of invalid replies, an impediment is raised
  and written to `.continue/impediments.json`, then the dialog returns None so caller
  can proceed to next task.

This module exposes `DialogManager` with methods for interactive use and for unit tests
(simulated responses).
"""
from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Iterable, List, Optional


CONTINUE_DIR = Path.cwd() / ".continue"
IMPEDIMENTS_FILE = CONTINUE_DIR / "impediments.json"


class DialogManager:
    def __init__(self, max_options: int = 10, max_invalid_attempts: int = 10):
        self.max_options = min(max_options, 10)
        self.max_invalid_attempts = max_invalid_attempts
        CONTINUE_DIR.mkdir(parents=True, exist_ok=True)

    def _raise_impediment(self, reason: str, context: dict):
        entry = {"reason": reason, "context": context, "ts": time.time()}
        data = []
        if IMPEDIMENTS_FILE.exists():
            try:
                data = json.loads(IMPEDIMENTS_FILE.read_text(encoding="utf-8-sig"))
            except Exception:
                data = []
        data.append(entry)
        IMPEDIMENTS_FILE.write_text(json.dumps(data, indent=2), encoding="utf-8")

    def _normalize_reply(self, reply: str) -> str:
        return (reply or "").strip().lower()

    def select_option(
        self,
        options: List[str],
        timeout_seconds: Optional[float] = None,
        allowed_short: Optional[List[str]] = None,
        responses: Optional[Iterable[str]] = None,
    ) -> Optional[str]:
        """Select an option from `options`.

        - `timeout_seconds` is advisory (only applied for interactive input).
        - `allowed_short` defaults to ['y','n','g','p'] and are returned as-is.
        - `responses` if provided is an iterable of pre-recorded replies (for tests/non-interactive).

        Returns selected option string, one of the `allowed_short` codes, or None when
        an impediment was raised after too many invalid replies.
        """
        if len(options) > self.max_options:
            options = options[: self.max_options]

        allowed_short = allowed_short or ["y", "n", "g", "p"]

        resp_iter = iter(responses) if responses is not None else None
        invalid = 0

        prompt_lines = ["Choose an option:"]
        for i, opt in enumerate(options, start=1):
            prompt_lines.append(f"  {i}) {opt}")
        prompt_lines.append("Reply 'y'/'n'/'g'/'p' or option number.")
        prompt_text = "\n".join(prompt_lines)

        while True:
            if resp_iter is None:
                try:
                    if timeout_seconds:
                        print(prompt_text)
                        start = time.time()
                        # simple blocking read with timeout
                        import sys, select

                        print(f"(waiting up to {timeout_seconds}s)")
                        rlist, _, _ = select.select([sys.stdin], [], [], timeout_seconds)
                        if rlist:
                            raw = sys.stdin.readline().strip()
                        else:
                            raw = ""
                    else:
                        raw = input(prompt_text + "\n> ")
                except Exception:
                    raw = ""
            else:
                try:
                    raw = next(resp_iter)
                except StopIteration:
                    raw = ""

            reply = self._normalize_reply(raw)

            # check short codes
            if reply in allowed_short:
                return reply

            # check numeric
            if reply.isdigit():
                idx = int(reply)
                if 1 <= idx <= len(options):
                    return options[idx - 1]

            invalid += 1
            if invalid >= self.max_invalid_attempts:
                # raise impediment and return None so caller can proceed to next task
                self._raise_impediment("too_many_invalid_replies", {"options": options})
                return None

            # otherwise loop again


if __name__ == "__main__":
    dm = DialogManager()
    res = dm.select_option(["Do thing A", "Do thing B"], timeout_seconds=20)
    print("result:", res)
