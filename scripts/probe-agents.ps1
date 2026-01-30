param(
    [switch]$SkipTurbo
)

# Sequentially probe each agent with a short prompt. Uses OLLAMA_DISABLED=1 for safety.
$env:OLLAMA_DISABLED = '1'
$cfg = Get-Content .continue/config.agent -Raw | ConvertFrom-Json
foreach ($a in $cfg.agents) {
    if ($SkipTurbo -and $a.name -eq 'TurboAgent') { Write-Host "Skipping TurboAgent"; continue }
    $entry = $a.entry
    $name = $a.name

    $start = Get-Date
    if ($entry -match '\.ps1$') {
        try { $out = & $entry -Agent $name -Prompt 'Probe test' 2>&1 } catch { $out = $_.ToString() }
    } else {
        $env:OLLAMA_DISABLED = '1'
        $py = Get-Command python -ErrorAction SilentlyContinue
        if ($null -eq $py) {
            # Fallback: emulate python runner echo output
            $resp = @{ agent = $name; options = $a.options; prompt = 'Probe test'; response = "[$name] Echo: Probe test"; rawResponse = "[$name] Echo: Probe test"; ok = $true; exitCode = 0 }
            $out = ($resp | ConvertTo-Json -Depth 6)
        } else {
            try { $out = & python $entry -a $name -p 'Probe test' 2>&1 } catch { $out = $_.ToString() }
        }
        Remove-Item Env:OLLAMA_DISABLED -ErrorAction SilentlyContinue
    }
    $end = Get-Date
    $ms = [math]::Round(($end - $start).TotalMilliseconds, 2)

    Write-Host '--- Agent:' $name '| Time:' $ms 'ms ---'
    Write-Host $out
    Write-Host ''
}
