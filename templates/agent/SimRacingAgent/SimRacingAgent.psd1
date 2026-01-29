@{
    GUID = 'd3a1f0e2-6a8b-4b2b-9c2f-1234567890ab'
    ModuleVersion = '0.1.0'
    Author = 'AILocalModelLibrary'
    CompanyName = ''
    Copyright = '(c) 2026'
    Description = 'SimRacingAgent library module (template) — exposes core APIs for importing as a library.'
    PowerShellVersion = '5.1'
    FileList = @(
        'SimRacingAgent.psm1',
        'Core\ConfigManager.psm1',
        'Core\AgentCore.psm1',
        'Modules\USBMonitor.psm1',
        'Modules\ProcessManager.psm1'
    )
    FunctionsToExport = @('*')
    NestedModules = @()
    RequiredModules = @()
    PrivateData = @{
        PSData = @{
            Tags = @('agent','simracing','library')
            LicenseUri = ''
            ProjectUri = ''
            ReleaseNotes = 'Initial template module manifest.'
        }
    }
}
