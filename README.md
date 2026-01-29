## Install & Smoke Test

Quick steps to verify local environment and run the agent smoke test.

- Inspect environment checks (non-destructive):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-windows.ps1 -DryRun
```

- Pull the default model (requires `ollama` installed). This will prompt for confirmation unless `-Confirm` is supplied:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-windows.ps1 -PullModel -Model 'codellama/7b-instruct' -Runtime 'ollama'
# Non-interactive (be careful):
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-windows.ps1 -PullModel -Model 'codellama/7b-instruct' -Runtime 'ollama' -Confirm
```

- Run the smoke test to verify core modules import and `Get-USBHealthCheck`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/smoke/agent-smoke-test.ps1
```

Notes:
- The `install-windows.ps1` script only prints recommended install commands when run with `-DryRun`.
- Pulling a model requires the specified runtime (e.g. `ollama`) to be installed and available on PATH.
- The smoke test resolves the agent location (prefers `agent/SimRacingAgent` if present, otherwise `templates/agent/SimRacingAgent`).
