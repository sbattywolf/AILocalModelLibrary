param(
    [string]$Prompt = '',
    [string]$Agent = ''
)

# Simple agent stub used by tests: echoes a JSON object with basic fields
$out = [ordered]@{
    ok = $true
    agent = $Agent
    prompt = $Prompt
    response = "Stub response from $Agent"
}

ConvertTo-Json $out -Depth 3
