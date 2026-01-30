"""LAN-secret communication channel scaffold.

This channel is intended for local/internal-only communication where
`secret_mode` is strictly enforced: outgoing messages are masked and
no remote/internet endpoints are used by default.

This is a conservative scaffold — extend with local sockets, named pipes,
or in-process queues depending on your environment.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Iterable, Optional

from services import secrets

USER_CFG = Path.cwd() / ".continue" / "user_config.json"


class LanSecretChannel:
    """LAN-only channel that enforces `secret_mode` masking for messages.

    Methods:
    - `send(message)`: mask known secrets and record to a local audit file
    - `receive()`: no-op (lan channel should implement local listeners)
    """

    def __init__(self, user_cfg: Optional[str] = None):
        self.user_cfg = Path(user_cfg) if user_cfg else USER_CFG
        self._cfg = self._load_cfg()

    def _load_cfg(self) -> dict[str, Any]:
        if not self.user_cfg.exists():
            return {}
        try:
            return json.loads(self.user_cfg.read_text(encoding="utf-8"))
        except Exception:
            return {}

    def _secret_mode_enabled(self) -> bool:
        return bool(self._cfg.get("secret_mode", False))

    def send(self, message: str, audit_file: Optional[str] = None) -> bool:
        """Send a message on the LAN-secret channel.

        Behavior:
        - If `secret_mode` enabled, mask known secrets before storing.
        - Do not attempt any remote network calls by default.
        - Optionally write an audit record to `audit_file` (local only).
        """
        msg = message
        if self._secret_mode_enabled():
            # Collect any env-based secret values declared in this user config
            extra_values: list[str] = []
            try:
                sec = self._cfg.get("secrets", {}) or {}
                import os

                for k, v in sec.items():
                    if isinstance(v, dict):
                        env = v.get("env_var")
                        if env:
                            val = os.environ.get(env)
                            if val:
                                extra_values.append(val)
            except Exception:
                extra_values = []

            msg = secrets.mask_text(msg, extra_values=extra_values)

        # For now: write a local-only audit log to `.continue/lan_audit.log`
        dest = Path(audit_file) if audit_file else (Path.cwd() / ".continue" / "lan_audit.log")
        try:
            dest.parent.mkdir(parents=True, exist_ok=True)
            with dest.open("a", encoding="utf-8") as fh:
                fh.write(msg.replace("\n", "\\n") + "\n")
            return True
        except Exception:
            return False

    def receive(self) -> Optional[str]:
        # Not implemented: replace with socket/pipe listener as needed.
        return None
