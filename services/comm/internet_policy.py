"""Network / internet access policy helpers for agents.

Provides utilities to check whether internet access is permitted by
configuration and to raise an impediment via a DialogManager when
internet is required but disabled.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Optional


def _load_user_cfg(path: Optional[str] = None) -> dict[str, Any]:
    cfg_path = Path(path) if path else (Path.cwd() / ".continue" / "user_config.json")
    if not cfg_path.exists():
        return {}
    try:
        return json.loads(cfg_path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def is_internet_allowed(path: Optional[str] = None, role: Optional[str] = None) -> bool:
    """Return True if internet is allowed by global config or allowed roles.

    Behavior:
    - If `network.internet_access` is True, allow for all roles.
    - Else, if `role` is provided and appears in `network.internet_allowed_roles`, allow.
    - Otherwise, deny.
    """
    cfg = _load_user_cfg(path)
    net = cfg.get("network", {}) or {}
    if bool(net.get("internet_access", False)):
        return True
    if role:
        allowed = net.get("internet_allowed_roles") or []
        try:
            return role in allowed
        except Exception:
            return False
    return False


def require_internet_or_impediment(dialog_manager: Optional[object],
                                   reason: str = "internet_required",
                                   context: Optional[dict] = None,
                                   path: Optional[str] = None,
                                   role: Optional[str] = None) -> bool:
    """Return True if internet is allowed; otherwise, raise an impediment
    on the provided `dialog_manager` (if it exposes `_raise_impediment`) and
    return False.

    `context` may include additional diagnostic fields.
    """
    allowed = is_internet_allowed(path=path, role=role)
    if allowed:
        return True

    if dialog_manager and hasattr(dialog_manager, "_raise_impediment"):
        try:
            ctx = context.copy() if isinstance(context, dict) else {}
            if role:
                ctx.setdefault("role", role)
        except Exception:
            ctx = {}
        ctx.setdefault("note", "internet access required but disabled by policy")
        dialog_manager._raise_impediment(reason=reason, context=ctx, weight=5)

    return False
