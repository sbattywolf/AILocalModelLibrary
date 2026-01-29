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

---

Expanded actionable checklist (automatable, do in order):

1) Environment bootstrap (safe, dry-run first)
 - Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\.continue\tool\quick-setup.ps1 -DryRun`
 - Inspect printed actions, then run without `-DryRun` if you agree.
 - Tasks performed: detect/install `ollama`, `git`, model pulls, optional package managers.

2) Consolidate `.continue` tooling
 - Copy reusable helpers from `.continue/imported_from_USBManager/extracted` into `.continue/tool/`.
 - Ensure `export-continue.ps1` excludes runtime artifacts (it already does).
 - Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\.continue\tool\validate-repo-fast.ps1` after changes.

3) Local agent configuration
 - Ensure `selected_agent.txt` is set to a local agent (currently `TurboAgent`).
 - Verify `.continue/config.json` and `.continue/config.agent` reference only local providers (ollama/local models).
 - Validate models list in `.continue/models.json` and update if you want different defaults.

4) Fix analyzer findings (priority)
 - Identify top analyzer issues from `.continue/imported_from_USBManager/extracted/psa-summary.json`.
 - Apply small, safe fixes (initialize variables, avoid global vars, avoid empty catch blocks).
 - Run `validate-repo.ps1` and unit tests after each fix.

5) Editor integration and tasks
 - Ensure `.vscode/tasks.json` contains a `Chat With Agent` task using `.continue/agent-runner.ps1`.
 - Replace any Copilot-specific tasks/configs with local runner calls.

6) CI adjustments
 - Add `validate-repo-fast` as an early CI job.
 - If CI referenced remote models, add mock fallbacks or run model pulls in CI runner.

7) Documentation & export
 - Create `docs/local-setup.md` with exact commands for Windows (powershell), macOS, Linux.
 - Use `.continue/tool/export-continue.ps1` to create a zip of `.continue` for reuse.

If you'd like, I can now run the `quick-setup.ps1 -DryRun` and capture results, then start applying the highest-priority analyzer fix (initialize logging fallback variable) if the target file exists in this workspace. Proceed? 
