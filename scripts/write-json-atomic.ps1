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
Write-Output $Path
