## Local setup (Windows)

This document describes the minimal steps to finalize local installation and verify the repo on Windows (PowerShell 5.1).

1) Quick dry-run (recommended first):

```powershell
# from repo root
# discover actions without making changes
powershell -NoProfile -ExecutionPolicy Bypass -File .\.continue\tool\quick-setup.ps1 -DryRun
```

2) Install required tools (if dry-run shows missing items):

Common actions the quick-setup may recommend:
- Install `ollama` (or other local model runtime)
- Install required system packages for any optional helpers

3) Validate the repository state (syntax and basic checks):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\.continue\tool\validate-repo.ps1
```

4) Run the PowerShell test suite (unit + integration quick run):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\.continue\tool\SimRacingAgent.Tests\SimRacingAgent.Tests\TestRunner.ps1 -Verbose
```

5) Installation smoke test (basic commands):

```powershell
# ensure agent code imports
Import-Module .\agent\SimRacingAgent\Core\ConfigManager.psm1 -ErrorAction Stop
Import-Module .\agent\SimRacingAgent\Core\AgentCore.psm1 -ErrorAction Stop
Import-Module .\agent\SimRacingAgent\Modules\USBMonitor.psm1 -ErrorAction Stop
# quick health check
(Get-USBHealthCheck).OverallHealth
```

Notes:
- Use `-DryRun` first to inspect actions.
- Many helper scripts live under `.continue/tool/`.
- If you plan to run on Linux/macOS, adapt the PowerShell invocations to `pwsh` and adjust paths.

If you'd like, I can run the dry-run now and then proceed to apply any missing-install fixes interactively.