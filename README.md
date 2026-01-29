## Install & Smoke Test

Quick steps to verify local environment and run the agent smoke test.
## Install & Smoke Test

Quick steps to verify local environment and run the agent smoke test.

 Inspect environment checks (non-destructive):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-windows.ps1 -DryRun
```

 Pull the default model (requires `ollama` installed). This will prompt for confirmation unless `-Confirm` is supplied:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-windows.ps1 -PullModel -Model 'codellama/7b-instruct' -Runtime 'ollama'
# Non-interactive (be careful):
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-windows.ps1 -PullModel -Model 'codellama/7b-instruct' -Runtime 'ollama' -Confirm
```

 Run the smoke test to verify core modules import and `Get-USBHealthCheck`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/smoke/agent-smoke-test.ps1
```

Notes:
 The `install-windows.ps1` script only prints recommended install commands when run with `-DryRun`.
 Pulling a model requires the specified runtime (e.g. `ollama`) to be installed and available on PATH.
 The smoke test resolves the agent location (prefers `agent/TemplateAgent` if present, otherwise `templates/agent/TemplateAgent`).

Cleanup helper

```powershell
# Preview
.\scripts\cleanup-workspace.ps1
# Apply (permanent)
.\scripts\cleanup-workspace.ps1 -Apply
```

Trace & backups

- `.continue/install-trace.log` — installer trace
- `.continue/path-backup.txt` — user PATH backup
- `.continue/system-path-backup.txt` — system PATH backup (if updated)
-- `dist/TemplateAgent.zip` — packaged module

CI

A GitHub Actions workflow is included in `.github/workflows/ci.yml` to run tests and produce `dist` on push/PR.
