"""Public communication channel scaffold.

This module provides a minimal `PublicChannel` class used as the default
communication channel. It's intentionally small: it defines a send/receive
API and reads `comm_channel` configuration from the workspace config files.

Extend this to integrate HTTP, WebSocket, or remote agent transports.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Optional

from services.comm import internet_policy

CONFIG_PATH = Path("config.template.json")


class PublicChannel:
    """Simple public channel stub.

    Methods:
    - `send(message)`: deliver a message to the public channel (returns True on success)
    - `receive()`: poll for incoming messages (returns None by default)
    """

    def __init__(self, config_path: Optional[str] = None):
        self.config_path = Path(config_path) if config_path else CONFIG_PATH
        self._cfg = self._load_config()

    def _load_config(self) -> dict[str, Any]:
        try:
            text = self.config_path.read_text(encoding="utf-8")
            return json.loads(text)
        except Exception:
            return {}

    def send(self, message: str, role: Optional[str] = None, dialog_manager: Optional[object] = None) -> bool:
        """Send a message over the public channel.

        Behavior:
        - Enforce `internet_policy`: if internet is not allowed for `role`, do not perform remote send.
        - If `dialog_manager` is provided and internet is disallowed, raise an impediment via the dialog manager.
        - This stub prints the message when allowed; replace with real HTTP/WebSocket client when integrating.
        """
        # consult the configured file for this channel when checking policy
        cfg_path = str(self.config_path) if self.config_path else None
        # if no role provided assume caller intends a local/test send and allow
        if role is None:
            allowed = True
        else:
            allowed = internet_policy.is_internet_allowed(path=cfg_path, role=role)
        if not allowed:
            # optionally raise an impediment to surface the need for internet
            if dialog_manager and hasattr(dialog_manager, "_raise_impediment"):
                try:
                    dialog_manager._raise_impediment("internet_required", {"message": message, "role": role}, weight=5)
                except Exception:
                    pass
            print(f"[PublicChannel] blocked send (internet disallowed for role={role}): {message}")
            return False

        # placeholder: perform the send (currently prints to stdout)
        print(f"[PublicChannel] send: {message}")
        return True

    def receive(self) -> Optional[str]:
        """Receive a message from the public channel.

        Returns None when no messages are available. Implement polling or
        event-driven handlers in concrete integrations.
        """
        return None
