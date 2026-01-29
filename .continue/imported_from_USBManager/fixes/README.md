Fix stubs for analyzer-reported issues

This folder contains patch stubs describing small, safe fixes that can be applied
automatically once the real source files are available in the workspace. Each stub
includes: problem summary, suggested small code change, and tests to run after
applying the change.

Workflow
- Review each stub and confirm you'd like the change applied.
- If you approve, I can apply the patch automatically and run `validate-repo.ps1`.

High-priority stubs:
- `Logging_fix.md` — initialize fallback logging variables.
- `DeviceMonitor_fix.md` — reduce global vars, add ShouldProcess for state changes.
- `APIServer_fix.md` — fix unused parameters and empty catches.
- `USBMonitor_fix.md` — reduce globals and sanitize WMIC usage.
- `TestRunner_fix.md` — update Import-Module paths for test context.
- `global_fixes.md` — patterns for empty-catch and global variables.
