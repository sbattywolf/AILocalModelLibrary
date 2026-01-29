# Quick repo secret scanner (working tree + history)
# Quick repo secret scanner (working tree + history)
# This scanner ignores the repository-local ".private/" folder so personal
# configs stored there are not flagged.
# Quick repo secret scanner (working tree + history)
# This scanner ignores the repository-local ".private/" folder so personal
# configs stored there are not flagged.

$ignorePatterns = @('.private/')

$patterns = @(
    'ghp_[A-Za-z0-9_]{36}',        # GitHub PAT
    'AKIA[0-9A-Z]{16}',           # AWS access key id
    '(?i)\b(token|secret|password|api[_-]?key|access[_-]?token)\b',
    '-----BEGIN (RSA )?PRIVATE KEY-----',
    '-----BEGIN OPENSSH PRIVATE KEY-----'
)

Write-Host '--- Working tree scan ---'
$repoRoot = (Get-Location).Path
Get-ChildItem -Path . -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $p = $_.FullName
    foreach ($ig in $ignorePatterns) {
        $pat = "$repoRoot\$ig*"
        if ($p -like $pat) { return $false }
    }
    return $true
} | ForEach-Object {
    try {
        Select-String -Path $_.FullName -Pattern $patterns -AllMatches -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host ("WT:{0}:{1}:{2}" -f $_.Path, $_.LineNumber, ($_.Line.Trim()))
        }
    } catch {}
}

Write-Host '--- Git history scan (this may take a while) ---'
$revs = git rev-list --all 2>$null
foreach ($p in $patterns) {
    Write-Host "Searching history for pattern: $p"
    foreach ($r in $revs) {
        try {
            $out = git grep -n --no-color -E $p $r 2>$null
            if ($out) {
                $out -split "`n" | ForEach-Object { Write-Host ("HIST:{0}:{1}" -f $r, $_) }
            }
        } catch {}
    }
}

Write-Host '--- Scan complete ---'