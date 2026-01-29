Title: Global patterns for automated fixes

This file lists small code patterns I can automatically apply to many files to
address common analyzer findings.

1) Empty catch blocks
- Replace `catch {}` with:
```powershell
catch {
    Write-AgentWarning -Message "Unhandled exception: $($_.Exception.Message)"
    # optionally rethrow if this should not be swallowed
}
```

2) Uninitialized variables
- Initialize script-scoped variables at module top:
```powershell
if (-not (Test-Path Variable:Script:MyVar)) { Set-Variable -Name 'MyVar' -Value $null -Scope Script }
```

3) Convert `Global:` to `Script:` where appropriate
- Pattern-based replacement is possible but should be reviewed per-file.

4) Add `SupportsShouldProcess` to state-changing functions
- Add `[CmdletBinding(SupportsShouldProcess=$true)]` and guard with `ShouldProcess`.

Applying patches
- I can generate patch files for each target (PR-ready). Approve `create stubs` to generate and commit them.
