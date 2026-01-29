Title: Make test imports robust to script context

File: agent/SimRacingAgent.Tests/TestRunner.ps1 (and related test scripts)

Problem
- Tests fail when run outside module context due to `Import-Module` relative paths.

Suggested fix
- Resolve module paths relative to the test script using `$PSScriptRoot` or
  the repository root, not the current working directory.

Patch example
```powershell
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\..\..\agent\SimRacingAgent\Utils\Configuration.psm1'
Import-Module (Resolve-Path $modulePath) -Force
```

Post-change checks
- Run unit tests locally and in CI.
