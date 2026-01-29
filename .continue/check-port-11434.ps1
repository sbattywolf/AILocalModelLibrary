<#
Forwarding wrapper for legacy callers. Calls the newer
`scripts/check-port-listener.ps1` with `-Port 11434` and
forwards common parameters like `-Format` and `-OutFile`.
#>

param(
    [string]$Format = 'table',
    [string]$OutFile,
    [string]$Address = '127.0.0.1'
)

$scriptPath = Join-Path $PSScriptRoot '..\scripts\check-port-listener.ps1'
if (-not (Test-Path $scriptPath)) {
    Write-Error "Unable to find helper script: $scriptPath"
    exit 2
}

$argsList = @('-Port','11434','-Format',$Format,'-Address',$Address)
if ($OutFile) { $argsList += @('-OutFile',$OutFile) }

# Execute the canonical script and forward exit code
& $scriptPath @argsList
$LASTEXITCODE = $global:LASTEXITCODE
exit $LASTEXITCODE
