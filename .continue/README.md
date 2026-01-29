This repository ships a small repo-local agent toolset under `.continue/`.

Quick pointers
- `.
.continue\tool\quick-setup.ps1` — orchestrates dependency checks and model pulls (dry-run by default).
- `.
.continue\tool\pull-model.ps1` — pulls a model into the configured runtime (default: `ollama`).
- `.
.continue\tool\record-last-test-run.ps1` — write `.continue/last_test_run.json` after tests.
- `.
.continue\tool\validate-repo-fast.ps1` — fast focused validator (JSON + PS1 syntax) used in CI and locally.

Safety & CI guidance
- All tools default to dry-run where destructive actions may occur. Check printed actions before running without `-DryRun`.
- Use `validate-repo-fast.ps1` locally before creating PRs to reduce CI noise.

Where to start
1. `powershell -NoProfile -ExecutionPolicy Bypass -File .\.continue\tool\quick-setup.ps1 -DryRun`
2. Review the dry-run output; then run without `-DryRun` to perform installs/pulls.

If you need the model files moved from the runtime's data dir, see `docs/local-model-setup.md` for recommended approaches (junctions / config).
# `.continue` — workspace agent/tooling pack

This folder contains per-repository agent configuration and helper tooling used
to run a local assistant and CI-safe interactive tests. If you'd like to reuse
this across repositories, you can import it as a standalone library.

Recommended approaches:

- Git submodule: keep `.continue` as a separate repo and add it as a submodule in each project.
  Pros: clear separation, easy updates with `git submodule update --init --remote`.
  Cons: extra git commands for contributors.

- Git subtree: useful if you want to vendor the files and push upstream occasionally.

- Package repo: publish the pack as a small repo and use `export-continue.ps1` to create zips for ad-hoc installs.

Files of interest:

- `tool/install-deps.ps1` — detect/install host dependencies (ollama, git, winget suggestions).
- `tool/start-model.ps1` / `tool/stop-model.ps1` — start/stop local model runtimes (dry-run safe).
- `tool/export-continue.ps1` — package `.continue` to a zip or push into a remote repo.
- `agent-runner.ps1` — the lightweight agent runner used by VS Code tasks and automation.

VS Code integration:
- Example tasks are provided in `.vscode/tasks.example.json` and a ready-to-use copy is placed at `.vscode/tasks.json` in this repository. Use the `Chat With Agent` task to select an agent and send prompts to the local runner.

Security/safety:

- The export script excludes runtime artifacts (`*.pid`, `*.marker`, `selected_agent.txt`) by default.
- When pushing to a remote repo via `export-continue.ps1 -Push`, the script will use `git` and requires valid credentials; review the files before pushing.

Usage:

1. To export a zip (dry-run):

   powershell -NoProfile -ExecutionPolicy Bypass -File .\continue\tool\export-continue.ps1 -DryRun

2. To actually create a zip:

   powershell -NoProfile -ExecutionPolicy Bypass -File .\continue\tool\export-continue.ps1 -OutZip ..\continue-pack.zip -DryRun:$false -Force
