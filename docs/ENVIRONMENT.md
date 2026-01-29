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
