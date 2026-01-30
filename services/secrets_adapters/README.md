# Secrets Adapters

This folder contains placeholder adapters for secret stores (Bitwarden, Windows Credential Manager, etc.).

Currently these adapters are stubs for future implementation. They must provide a function `list_secret_values()` that returns an array of strings (secret values) for masking.

Planned adapters:
- `bitwarden_adapter.py` — use `bw` CLI or API to list items
- `wincred_adapter.py` — integrate with Windows Credential Manager

Security note: adapters should never write secrets to disk; only return values to the masking utilities in memory.
