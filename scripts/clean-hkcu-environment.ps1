# Inspect and remove malformed HKCU:\Environment properties (names starting with a dot)
$log = '.\\continue\\hkcu-environment.log'
$log = Join-Path (Get-Location) '.continue\hkcu-environment.log'
Add-Content -Path $log -Value "--- HKCU:\Environment cleanup run: $(Get-Date -Format o) ---"

# Capture BEFORE
try {
    $beforeObj = Get-ItemProperty -Path HKCU:\Environment -ErrorAction Stop
} catch {
    $beforeObj = $null
}
if ($beforeObj) {
    Add-Content -Path $log -Value "BEFORE:"
    $beforeObj | Format-List * | Out-String | Add-Content -Path $log
} else {
    Add-Content -Path $log -Value "BEFORE: (no HKCU:\Environment key or access denied)"
}

# Identify malformed properties (leading dot)
$props = @()
if ($beforeObj) { $props = $beforeObj.PSObject.Properties | Select-Object -ExpandProperty Name }
$bad = $props | Where-Object { $_ -match '^\\.' }
Add-Content -Path $log -Value ("Found properties: " + ($props -join ', '))
Add-Content -Path $log -Value ("Candidates to remove: " + ($bad -join ', '))

foreach ($n in $bad) {
    if ($n) {
        try {
            Remove-ItemProperty -Path HKCU:\Environment -Name $n -ErrorAction Stop
            Add-Content -Path $log -Value ("Removed registry property: " + $n)
        } catch {
            Add-Content -Path $log -Value ("Failed to remove " + $n + ": " + ($_ | Out-String))
        }
    }
}

# Capture AFTER
try {
    $afterObj = Get-ItemProperty -Path HKCU:\Environment -ErrorAction Stop
} catch {
    $afterObj = $null
}
if ($afterObj) {
    Add-Content -Path $log -Value "AFTER:"
    $afterObj | Format-List * | Out-String | Add-Content -Path $log
} else {
    Add-Content -Path $log -Value "AFTER: (no HKCU:\Environment key or access denied)"
}

Write-Host "HKCU environment cleanup complete; log: $log" 
