param(
    [string]$Model = 'codellama/7b-instruct',
    [string]$Runtime = 'ollama',
    [string]$StorePath = 'E:\llm-models',
    [int]$MaxModelSizeGB = 10
)

Write-Host "pull-model-run: invoking pull-model.ps1 for $Model"

$scriptPath = Join-Path -Path $PSScriptRoot -ChildPath 'pull-model.ps1'
if (-not (Test-Path $scriptPath)) { Write-Error "Missing $scriptPath"; exit 2 }

& $scriptPath -Model $Model -Runtime $Runtime -DryRun:$false -StorePath $StorePath -MaxModelSizeGB $MaxModelSizeGB
exit $LASTEXITCODE
