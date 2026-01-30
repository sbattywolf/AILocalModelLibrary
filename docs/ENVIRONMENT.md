````markdown
# Environment requirements

- PowerShell: Windows PowerShell 5.1 (recommended for developer workflows in this repo).
- Pester: version 4.x (4.10.0 recommended). The repository tests and helpers target Pester v4 behaviors (`Should -BeTrue`, `-Not`, etc.).

Install recommended Pester version (current user):

```powershell
Install-Module -Name Pester -RequiredVersion 4.10.0 -Scope CurrentUser -Force -AllowClobber
```

If you cannot install modules system-wide, run `scripts/run-tests.ps1 -ForceInstallPester` which will attempt a CurrentUser install.

Notes:
- Tests are executed on PS5.1 in CI and locally; avoid PS7-only constructs in shared scripts to maintain compatibility.
- For quick local test runs without changing persistent state, use the temporary env helper: `.\\continue\\set-temp-env.ps1 -FromFile .\\.continue\\temp-env.sample.json -DryRun` then remove `-DryRun` to apply to the current process.

````

## Ollama & Local Tools

Detected on this machine (automated check):

- `ollama` detected at `C:\Users\sbatt\AppData\Local\Programs\Ollama\ollama.exe` (version 0.15.2).
- `git` detected.
- `nvidia-smi` detected (NVIDIA drivers/CUDA present).
- `python`, `docker`, `pip` were not found on PATH.

If `ollama` is installed but not on `PATH`, update `config.template.json` -> `ollama.path` with the full executable path or add its folder to your `PATH`.

Check local Ollama models:

```powershell
# List models Ollama knows about
& "C:\\Users\\sbatt\\AppData\\Local\\Programs\\Ollama\\ollama.exe" list

# Run a quick probe (non-interactive) using Ollama if desired
& "C:\\Users\\sbatt\\AppData\\Local\\Programs\\Ollama\\ollama.exe" run --help
```

Environment variables useful for tests and CI:

```powershell
#$env:OLLAMA_DISABLED = "1"          # force offline/echo fallback
#$env:RUN_OLLAMA_INTEGRATION = "1"   # enable live Ollama integration in tests
```

Secrets: copy `.continue/secrets.template` to `.private/secrets.json` and fill values. Never commit `.private`.

Next actions:

- I can run `ollama list` now and report what models are available.
- Or, if you prefer, I can prepare a `config.json` derived from the template and a `.private/secrets.json` stub for you to edit.
# Environment requirements

- PowerShell: Windows PowerShell 5.1 (recommended for developer workflows in this repo).
- Pester: version 4.x (4.10.0 recommended). The repository tests and helpers target Pester v4 behaviors (`Should -BeTrue`, `-Not`, etc.).

Install recommended Pester version (current user):

```powershell
Install-Module -Name Pester -RequiredVersion 4.10.0 -Scope CurrentUser -Force -AllowClobber
```

If you cannot install modules system-wide, run `scripts/run-tests.ps1 -ForceInstallPester` which will attempt a CurrentUser install.

Notes:
- Tests are executed on PS5.1 in CI and locally; avoid PS7-only constructs in shared scripts to maintain compatibility.
- For quick local test runs without changing persistent state, use the temporary env helper: `.\.continue\set-temp-env.ps1 -FromFile .\.continue\temp-env.sample.json -DryRun` then remove `-DryRun` to apply to the current process.
