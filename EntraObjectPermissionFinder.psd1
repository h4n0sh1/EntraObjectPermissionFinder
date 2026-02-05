@{
    RootModule = 'EntraObjectPermissionFinder.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a7f3c9e2-4b8d-4e1a-9f5c-6d2e8a1b7c4f'
    Author = 'h4n0sh1'
    CompanyName = 'Unknown'
    Copyright = '(c) 2026. All rights reserved.'
    Description = 'PowerShell module to discover and analyze permissions assigned to any Entra ID object including app registrations, users, groups, and managed identities'
    
    PowerShellVersion = '5.1'
    
    RequiredModules = @(
        @{ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.0.0'}
    )
    
    FunctionsToExport = @(
        'Initialize-GraphSession',
        'Find-EntraObjectPermissions',
        'Disconnect-GraphSession'
    )
    
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    PrivateData = @{
        PSData = @{
            Tags = @('Entra', 'AzureAD', 'Permissions', 'Security', 'Graph', 'Identity')
            LicenseUri = ''
            ProjectUri = 'https://github.com/h4n0sh1/EntraObjectPermissionFinder'
            ReleaseNotes = 'Initial release - Support for querying permissions of app registrations, users, groups, and managed identities'
        }
    }
}
