function Test-LoadJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        throw "File not found: $Path"
    }

    $text = Get-Content -Raw -Encoding UTF8 -Path $Path

    # Coerce arrays to single string (robust across PS versions)
    if ($text -is [object[]]) { $text = $text -join "`n" }

    if ($null -eq $text -or $text -eq '') { return $null }

    # Strip Markdown fences if present
    $text = $text -replace "^\s*```(?:json)?\s*",""
    $text = $text -replace "\s*```\s*$",""

    # Trim trailing garbage after the last JSON bracket/brace
    $lastBrace = $text.LastIndexOf('}')
    $lastBracket = $text.LastIndexOf(']')
    $endPos = [Math]::Max($lastBrace, $lastBracket)
    if ($endPos -ge 0 -and $endPos -lt $text.Length - 1) {
        $text = $text.Substring(0, $endPos + 1)
    }

    try {
        return $text | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "ConvertFrom-Json failed for '$Path' : $($_.Exception.Message)"
    }
}

function Test-WriteJsonAtomic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][object]$Object
    )

    $dir = Split-Path -Path $Path -Parent
    if (-not (Test-Path -Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $temp = [System.IO.Path]::Combine($dir, ([System.IO.Path]::GetRandomFileName() + ".tmp"))
    $json = $Object | ConvertTo-Json -Depth 10
    Set-Content -Path $temp -Value $json -Encoding UTF8
    Move-Item -Force -Path $temp -Destination $Path
    return $Path
}

function Load-JsonDefensive {
    param(
        [Parameter(Mandatory=$true)] [string] $Path
    )

    if (-not (Test-Path $Path)) { return $null }

    $raw = Get-Content $Path -Raw -ErrorAction Stop

    # strip common markdown/json fences
    if ($raw -match '```json') {
        $raw = $raw -replace '```json', ''
        $raw = $raw -replace '```', ''
    }

    # try normal parse first
    try {
        return $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        # attempt to extract the first JSON object/array present in the raw text
        $firstCurly = $raw.IndexOf('{')
        $firstSquare = $raw.IndexOf('[')
        if ($firstCurly -eq -1 -and $firstSquare -eq -1) { return $null }
        if ($firstCurly -eq -1) { $start = $firstSquare } elseif ($firstSquare -eq -1) { $start = $firstCurly } else { $start = [Math]::Min($firstCurly, $firstSquare) }

        $lastCurly = $raw.LastIndexOf('}')
        $lastSquare = $raw.LastIndexOf(']')
        $end = [Math]::Max($lastCurly, $lastSquare)
        if ($end -le $start) { return $null }

        $candidate = $raw.Substring($start, $end - $start + 1)
        try {
            return $candidate | ConvertFrom-Json -ErrorAction Stop
        } catch {
            return $null
        }
    }
}
