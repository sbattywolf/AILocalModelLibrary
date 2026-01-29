<#
.continue/tool/pull-model.ps1

Pull a model into the local runtime (ollama) or show instructions. Dry-run by default.

Usage:
  .\pull-model.ps1 -Model local-qwen-a:1.0 -DryRun
  .\pull-model.ps1 -Model qwen2.5-coder:1.5b -DryRun:$false
#>

param(
    [Parameter(Mandatory=$true)][string]$Model,
    [ValidateSet('ollama','docker','manual')][string]$Runtime = 'ollama',
    [switch]$DryRun = $true,
    [string]$StorePath = 'E:\\llm-models',
    [int]$MaxModelSizeGB = 10
)

Write-Host "pull-model: Model=$Model Runtime=$Runtime DryRun=$DryRun StorePath=$StorePath MaxModelSizeGB=$MaxModelSizeGB"

# Ensure store path exists (dry-run reports)
if ($DryRun) {
    Write-Host "Dry-run: ensure path $StorePath exists and has at least $MaxModelSizeGB GB free"
} else {
    if (-not (Test-Path $StorePath)) { New-Item -ItemType Directory -Path $StorePath -Force | Out-Null }
}

# Determine free space on store drive
try {
    $driveRoot = [System.IO.Path]::GetPathRoot($StorePath)
    $di = New-Object System.IO.DriveInfo($driveRoot)
    $freeBytes = $di.AvailableFreeSpace
    $freeGB = [math]::Round($freeBytes / 1GB,2)
} catch {
    Write-Warning "Unable to determine drive free space for ${StorePath}: ${_}"
    $freeGB = 0
}

if ($freeGB -lt $MaxModelSizeGB) {
    Write-Error "Insufficient free space on ${driveRoot}: ${freeGB} GB available, require at least ${MaxModelSizeGB} GB. Aborting."
    exit 4
}

if ($Runtime -eq 'ollama') {
    if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
        Write-Warning "ollama not found. See .continue/tool/install-deps.ps1 for suggestions."; exit 2
    }
    $cmd = @('pull', $Model)
    if ($DryRun) {
        Write-Host "Dry-run: would run: ollama pull $Model";
        Write-Host "Note: ollama stores models in its own data directory; to control final location, configure ollama per its docs or move/backup models into $StorePath after pull.";
        exit 0
    }
    try {
        & ollama @cmd
        Write-Host "Pulled $Model via ollama"
        # record model metadata in .continue/models.json (robustly handle existing formats)
        $metaPath = Join-Path (Get-Location) '.continue\models.json'
        $entry = [PSCustomObject]@{
            model = $Model
            runtime = 'ollama'
            store = $StorePath
            pulledAt = (Get-Date).ToString('o')
        }
        try {
            if (-not (Test-Path $metaPath)) {
                $out = @($entry)
            } else {
                $raw = Get-Content -Path $metaPath -Raw -ErrorAction Stop
                $existing = $raw | ConvertFrom-Json -ErrorAction Stop
                if ($existing -is [System.Array]) {
                    $out = $existing
                    $out += $entry
                } elseif ($existing -ne $null -and $existing.psobject.Properties.Name -contains 'models') {
                    # object with models array
                    $existing.models += $entry
                    $existing | ConvertTo-Json -Depth 5 | Set-Content -Path $metaPath -Encoding UTF8
                    Write-Host "Recorded model metadata to $metaPath"
                    exit 0
                } else {
                    # wrap existing content into an array and append
                    $out = @($existing)
                    $out += $entry
                }
            }
            $out | ConvertTo-Json -Depth 5 | Set-Content -Path $metaPath -Encoding UTF8
            Write-Host "Recorded model metadata to $metaPath"
        } catch {
            Write-Warning "Failed to record model metadata: $_"
        }
    } catch { Write-Error "Failed to pull model: $_"; exit 3 }
} elseif ($Runtime -eq 'docker') {
    Write-Host "Docker runtime selected: please use your container spec to pull/pull+extract model images. Example: docker pull <image>"; exit 0
} else {
    Write-Host "Manual runtime: download model from vendor and import into your runtime as documented."; exit 0
}
