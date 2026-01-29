Title: Initialize fallback logging variable(s)

File: agent/SimRacingAgent/Utils/Logging.psm1

Problem
- Analyzer & tests reported an uninitialized variable used in fallback logging
  path (runtime exception observed at line ~53 in the PR draft notes).

Suggested fix (safe, minimal)
- Ensure `$fallbackLog` (or similarly named variable) exists and has a default
  value before use.

Patch (example)
```powershell
# near the top of the module, initialize fallback variables
if (-not (Test-Path Variable:FallbackLog)) { Set-Variable -Name 'FallbackLog' -Value $null -Scope Script }
# or
$Script:FallbackLog = $Script:FallbackLog -or ''
```

Post-change checks
- Run `.\.continue\tool\validate-repo.ps1`.
- Run agent unit tests (if available) or the specific test that previously failed.

Notes
- Do not change runtime behavior; only add a default assignment. If the module
  already sets a different variable name, adapt accordingly.
