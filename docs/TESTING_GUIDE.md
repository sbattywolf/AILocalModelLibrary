# Testing guide and conventions

Purpose: provide quick guidelines for running and extending the repository's Pester tests, telemetry validation, and DryRun smoke tests.

**Quick commands**
- Run all unit/ops tests locally:

```powershell
Import-Module Pester -ErrorAction Stop
Invoke-Pester -Script tests/*.Tests.ps1
```

- Run a single test file:

```powershell
Invoke-Pester -Script tests/Monitor.PreferSkill.Tests.ps1 -EnableExit
```

**Testing conventions used in this repo**
- Tests must avoid mutating ConvertFrom-Json PSObjects; construct plain/ordered hashtables before serializing.
- Use temporary directories under `$env:TEMP` and always remove them in `AfterAll` when possible.
- Coerce Where-Object results to arrays before accessing `.Count` to avoid null counts.
- Prefer deterministic single-sample samplers for tests that depend on telemetry files.

**Adding new tests**
1. Create `tests/My.New.Tests.ps1` with `Describe{}` blocks and `BeforeAll`/`AfterAll` for setup/teardown.
2. Use the `scripts/*` helpers where possible to avoid duplicating logic.
3. Keep tests fast and deterministic; avoid long sleeps—use retries/timeouts with exponentially increasing waits if necessary.

**CI-specific notes**
- CI runs a light subset of tests; heavy DryRun or long-run telemetry tasks should be gated under a nightly workflow.
- The CI analysis step currently writes safe suggestions to `.continue/analysis/` for developers to review; integrate real analysis only after adding secret management and audit controls.

**Schema & shape recommendations**
- Add `schemas/` for canonical JSON shapes and a small validation helper used by tests and scripts to ensure stable producer/consumer contracts.
