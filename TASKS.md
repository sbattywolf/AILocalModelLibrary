# Migration to Fully-Local Agent + Repo setup

Goal: replace Copilot/remote agents with a fully local assistant/tooling stack and consolidate imported USBManager tooling into this repo.

Priority steps (automatable)

1. Local agent runtime
- Install and configure local model runtime (recommended: `ollama` or local containerized LLM runtime).
- Use `.continue/tool/quick-setup.ps1` (dry-run) to discover required packages and steps.
- Validate models in `.continue/models.json` and download preferred model (e.g., `qwen2.5-coder:32b` for `TurboAgent`).

2. Tooling import & reuse
- Audit `.continue/imported_from_USBManager/extracted` to find reusable scripts (`.tools/*`, `agent-runner.ps1`, `export-continue.ps1`).
- Vendor or refactor helpers into `.continue/tool/` and remove duplicates.

3. Code/Repo hygiene
- Run `.continue/tool/validate-repo.ps1` and fix analyzer findings (logging var init, empty catch blocks, global vars).
- Apply small PR fixes from `PR_DRAFT_psa_apiserver_fixes.md` into a feature branch and run tests.

4. Replace Copilot/Centralized services
- Remove references to Copilot in README and config; set `selected_agent.txt` and configs to local-only models.
- Ensure editor integrations (VS Code tasks) call `.continue/agent-runner.ps1` or local `ollama` endpoint.

5. CI / Tests
- Ensure CI does not depend on remote models; mock model calls in tests or run in a minimal local container.
- Add `validate-repo-fast` as a CI pre-check.

6. Finalize
- Document setup in `docs/local-setup.md` with exact commands and optional optimizations for GPU.
- Create a release/zip export script using `.continue/tool/export-continue.ps1`.

Notes & Next Actions for me
- I will push this branch, then run `.continue/tool/quick-setup.ps1 -DryRun` and capture outputs.
- I will start applying small analyzer fixes (Logging variable) and prepare PR-ready commits on `session/recover-usb-session`.

----------------------------------

Commands to run locally (summary):

```powershell
# fetch latest remote main
git fetch origin
# rebase branch onto main
git checkout session/recover-usb-session
git rebase origin/main
# run quick-setup dry-run
powershell -NoProfile -ExecutionPolicy Bypass -File .\.continue\tool\quick-setup.ps1 -DryRun
```
