$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
## Refactored: point to TemplateAgent.Tests instead of legacy SimRacingAgent.Tests
$modulePath = Join-Path $scriptRoot 'TemplateAgent.Tests\Unit\AgentCoreTests.ps1'
Import-Module $modulePath -Force
$res = Invoke-AgentCoreTests -StopOnFirstFailure
Write-Host '--- JSON RESULT ---'
$res | ConvertTo-Json -Depth 5
