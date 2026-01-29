Title: Fix unused parameters and empty-catch blocks

File: agent/SimRacingAgent/Services/APIServer.psm1

Problem
- Analyzer flagged many `PSReviewUnusedParameter` and `EmptyCatchNotLast` issues.

Suggested fixes (safe)
- For unused parameters likely required by an interface, add `[Parameter()] [object]$unused = $null` with a comment.
- Replace empty catch blocks with a logging call and optional `throw` when appropriate.

Patch examples
```powershell
function Invoke-SomeApi {
    param(
        [Parameter(Mandatory=$true)][string]$Id,
        [Parameter()][object]$UnusedParam # required by interface
    )
    try {
        # original work
    } catch {
        Write-AgentError -Message "Invoke-SomeApi failed: $($_.Exception.Message)"
        throw
    }
}
```

Post-change checks
- Run PS Script Analyzer and `validate-repo.ps1`.
- Run integration smoke tests.
