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
from collections import deque


CONTINUE_DIR = Path.cwd() / ".continue"
IMPEDIMENTS_FILE = CONTINUE_DIR / "impediments.json"


class DialogManager:
    def __init__(self, max_options: int = 10, max_invalid_attempts: int = 10, default_human_origin: bool = True, default_secret_mode: bool = False):
        self.max_options = min(max_options, 10)
        self.max_invalid_attempts = max_invalid_attempts
        # if True, select_option treats messages as human-origin by default (permissive)
        self.default_human_origin = bool(default_human_origin)
        # if True, secret-mode is enabled by default (masks sensitive data in outputs)
        self.default_secret_mode = bool(default_secret_mode)
        # track recent replies for debugging (included in impediments)
        self.recent_replies_max = 10
        self._recent_replies = deque(maxlen=self.recent_replies_max)
        CONTINUE_DIR.mkdir(parents=True, exist_ok=True)

    def _raise_impediment(self, reason: str, context: dict, weight: int = 1, secret_mode: Optional[bool] = None):
        # write an impediment with ISO8601 timestamp, provided context, and optional weight
        from datetime import datetime, timezone
        # resolve secret_mode default
        if secret_mode is None:
            secret_mode = bool(getattr(self, "default_secret_mode", False))
        # defer import to avoid cycles
        try:
            from services import secrets as secrets_mod
        except Exception:
            secrets_mod = None

        # include recent replies if not already present (mask when secret_mode)
        ctx = dict(context)
        if "recent_replies" not in ctx:
            recent = list(self._recent_replies)
            if secret_mode and secrets_mod is not None:
                try:
                    recent = [secrets_mod.mask_text(r) for r in recent]
                except Exception:
                    pass
            ctx["recent_replies"] = recent

        entry = {
            "reason": reason,
            "weight": int(weight),
            "context": ctx,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
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
        backoff_initial: float = 0.0,
        backoff_factor: float = 2.0,
        backoff_max: float = 5.0,
        timeout_retries: int = 3,
        human_origin: Optional[bool] = None,
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
        # backoff state (no-op when backoff_initial == 0)
        current_backoff = float(backoff_initial)
        # timeout-specific retries tracking (only used when waiting interactively)
        timeout_attempts = 0

        # reset recent replies buffer for this call
        try:
            self._recent_replies.clear()
        except Exception:
            pass

        # resolve human_origin default from instance if not explicit
        if human_origin is None:
            human_origin = bool(self.default_human_origin)

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
                            # successful read resets timeout attempts
                            timeout_attempts = 0
                        else:
                            raw = ""
                            # count this as a timeout attempt
                            timeout_attempts += 1
                    else:
                        raw = input(prompt_text + "\n> ")
                except Exception:
                    raw = ""
                    # could be an interactive read failure; treat as timeout-like
                    if timeout_seconds:
                        timeout_attempts += 1
            else:
                try:
                    raw = next(resp_iter)
                except StopIteration:
                    raw = ""

            reply = self._normalize_reply(raw)

            # record recent (raw) replies for debugging
            try:
                self._recent_replies.append(raw)
            except Exception:
                pass

            # check short codes (allow optional short sentence up to 20 words)
            for code in allowed_short:
                if reply == code:
                    return reply
                if reply.startswith(code + " "):
                    tail = reply[len(code) + 1 :].strip()
                    # humans: be permissive about explanatory phrase length
                    if human_origin:
                        return code + " " + tail
                    # allow at most 20 words in the optional explanatory phrase for non-humans
                    if 0 < len(tail.split()) <= 20:
                        return code + " " + tail

            # check numeric
            if reply.isdigit():
                idx = int(reply)
                if 1 <= idx <= len(options):
                    return options[idx - 1]

            invalid += 1
            # apply backoff sleep when configured
            # apply backoff sleep when configured
            if current_backoff and current_backoff > 0:
                try:
                    time.sleep(min(current_backoff, float(backoff_max)))
                except Exception:
                    # if sleep is patched or fails, continue
                    pass
                current_backoff = min(current_backoff * float(backoff_factor), float(backoff_max))
            # if timeout attempts reached the configured cap, raise timeout impediment
            if not human_origin and timeout_attempts and timeout_seconds and timeout_attempts >= int(timeout_retries or 0):
                self._raise_impediment("timeout_no_response", {"options": options}, weight=5)
                return None
            # if invalid attempts exceeded and not a human-origin message, escalate
            if not human_origin and invalid >= self.max_invalid_attempts:
                # raise impediment and return None so caller can proceed to next task
                self._raise_impediment("too_many_invalid_replies", {"options": options}, weight=3)
                return None

            # otherwise loop again


if __name__ == "__main__":
    dm = DialogManager()
    res = dm.select_option(["Do thing A", "Do thing B"], timeout_seconds=20)
    print("result:", res)
