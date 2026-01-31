# Read Me First — Installation & Environment Setup

Purpose: a single page for first-time users that lists required tools, installers,
PATH and environment-variable setup, secrets handling tips, and references to
platform-specific installer scripts and templates in this repository. Read this
before attempting to run or contribute to the library.

1) Prerequisite tools
- git
- Python (3.10+ recommended)
- Node.js (for optional tooling)
- Ollama (or other local LLM runtime) if you plan to use local models
- git-filter-repo (optional, for repository maintenance)

2) Quick check (Windows PowerShell)
Run the included checker to detect common missing dependencies:

```powershell
# .\scripts\check-installs.ps1
```

3) PATH and environment variables
- Ensure executables are on your PATH. Example PowerShell (permanent for current user):

```powershell
# $env:Path is session-only; to persist for current user:
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Path\to\tool", "User")
```

- Common env vars used by this library:
  - `OPENAI_API_KEY` — optional for OpenAI integrations
  - `OLLAMA_HOME` — optional, location where Ollama stores models

Windows example: set `OLLAMA_HOME` for current user

```powershell
[Environment]::SetEnvironmentVariable("OLLAMA_HOME", "C:\ollama_data", "User")
```

Notes about Ollama model storage and logs
----------------------------------------
- Where to store models: If you set `OLLAMA_HOME` the repository's helper scripts and templates will use that folder as the model store root. A common layout used by the installer templates is:

  - `<OLLAMA_HOME>`\models  — model files and pulled images

- If you prefer a custom location (for example a dedicated drive for large models), set `OLLAMA_HOME` to that path before running setup or the `start-ollama-role` scripts.

- Repository run logs and process mappings: this project keeps per-run metadata under the `.continue` directory (examples: `.continue/ollama-processes.json`, `.continue/install-trace.log`). The installer and agent scripts write these files so you can inspect which model runs were started and where logs are stored.

- Restore guidance: if your personal `.continue/user_config.json` is missing, copy `.continue/user_config.example.json` to `.continue/user_config.json` and update the `paths` and `env_overrides.OLLAMA_HOME` values to match your environment.

Local user config storage
-------------------------
- For personal/local, non-shared values (tool install paths, per-user `OLLAMA_HOME`, etc.), keep them in the ignored `.private/user_config.local.json` file. The repository tracks a sanitized `.continue/user_config.json` that contains non-sensitive defaults and pointers to the local file.
- The `.private` folder is already ignored by `.gitignore`. Do not commit secrets or personal paths — keep them in `.private/user_config.local.json`.


4) Installing recommended packages (Windows using Chocolatey)

```powershell
# install Chocolatey first (if not already)
# then install common tools
choco install git -y
choco install python -y
choco install nodejs -y
```

5) macOS / Linux
- Use your platform's package manager (Homebrew, apt, pacman). See `templates/install/` for helper scripts.

6) Local LLM runtimes and model storage
- If using `ollama`, follow official install docs: https://ollama.com/docs/install
- For local runtimes (llama.cpp / ggml / gguf) follow the templates in `templates/install/` and `templates/agents/*/README.md`.

7) Secrets and sensitive data: search and cleaning tips
- Before sharing or publishing, search for secrets and API keys in the repo history.
- Suggested tools and commands:
  - `git grep -n "API_KEY|OPENAI|SECRET|TOKEN"`
  - `git log --all -S 'OPENAI'`
  - Use `git-secrets` or `truffleHog` to scan history: https://github.com/awslabs/git-secrets

- If you find secrets, rotate keys immediately and remove them from history using `git-filter-repo` (careful; rewriting history affects all collaborators).

8) Installer templates and automation
- See `templates/install/` for PowerShell model-store and other helper scripts.
- See `scripts/check-installs.ps1` to validate the environment on Windows.

9) Troubleshooting PATH issues
- Common problem: executable installed but not found in shell — ensure you opened a new shell after installing, or add the install directory to PATH as above.
- Verify with `Get-Command <tool>` on PowerShell or `which <tool>` on macOS/Linux.

10) Additional references
- `TASKS.md` — high-level tasks and pointers to local-setup documentation.
- `templates/agents/*/README.md` — per-agent notes on required runtimes and env vars.

11) Read this first
- Add a link to this file in the repository `README.md` and include a short banner: "Read `docs/README_FIRST.md` before setup".

If you want, I can:
- Insert a prominent link into the top of `README.md`.
- Export this guide to `docs/README_FIRST.txt` or a downloadable checklist.
