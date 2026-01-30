# Wrapper: import module and call function so callers (tests) can import the module and call reliably
try {
    $modulePath = Join-Path $PSScriptRoot 'scheduler-prefer-skill.psm1'
    if (Test-Path $modulePath) { . $modulePath }
} catch {
    Write-Verbose "Could not dot-source module: $($_.Exception.Message)"
}

# If invoked directly with parameters, call the function with the script's bound parameters
if ($PSBoundParameters.Count -gt 0) {
    Invoke-PreferSkillScheduler @PSBoundParameters
}
