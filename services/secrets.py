"""Simple secrets utilities: masking and adapters.

This module provides a conservative `mask_text` function that replaces any
explicit secret values found in the environment (based on `.continue/user_config.json`)
with `<REDACTED>`. It intentionally avoids trying to guess secrets by pattern.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Iterable, List


def _load_config_secrets() -> List[str]:
    cfg = Path.cwd() / ".continue" / "user_config.json"
    if not cfg.exists():
        return []
    try:
        data = json.loads(cfg.read_text(encoding="utf-8"))
        sec = data.get("secrets", {})
        vals = []
        for k, v in sec.items():
            env = v.get("env_var") if isinstance(v, dict) else None
            if env:
                val = os.environ.get(env)
                if val:
                    vals.append(val)
        return vals
    except Exception:
        return []


def mask_text(s: str, extra_values: Iterable[str] | None = None) -> str:
    """Return a masked copy of `s`, replacing any occurrences of known secret
    values with `<REDACTED>`. `extra_values` may be supplied to include
    additional sensitive substrings for masking.
    """
    if not s:
        return s
    try:
        values = list(_load_config_secrets())
        if extra_values:
            values.extend(list(extra_values))
        out = s
        for v in sorted(set(filter(None, values)), key=len, reverse=True):
            try:
                out = out.replace(v, "<REDACTED>")
            except Exception:
                continue
        return out
    except Exception:
        return s


def mask_iterable(items: Iterable[str], extra_values: Iterable[str] | None = None) -> List[str]:
    return [mask_text(i, extra_values=extra_values) for i in items]
