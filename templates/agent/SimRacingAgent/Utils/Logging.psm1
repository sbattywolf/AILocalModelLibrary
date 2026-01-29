function Write-Log {
    param(
        [string]$Message,
        [string]$Level = 'Info',
        [string]$Component = 'Agent',
        [string]$Path = $null
    )
    if (-not $Path) { $Path = Join-Path $env:TEMP 'template_agent.log' }
    $line = "[$((Get-Date).ToString('o'))] [$Level] [$Component] $Message"
    $line | Out-File -FilePath $Path -Append -Encoding UTF8
    return $true
}

function Write-AgentLog {
    param(
        [string]$Message,
        [string]$Level = 'Info',
        [string]$Component = 'Agent',
        [string]$LogPath = $null
    )
    return Write-Log -Message $Message -Level $Level -Component $Component -Path $LogPath
}

if ($PSModuleInfo) {
    Export-ModuleMember -Function Write-Log,Write-AgentLog -ErrorAction Stop
} else {
    Write-Verbose "Export-ModuleMember skipped (not running inside a module)"
}
