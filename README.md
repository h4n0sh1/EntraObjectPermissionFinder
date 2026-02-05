# EntraObjectPermissionFinder

PowerShell module to discover and analyze all active permissions assigned to any Entra ID object including app registrations, service principals, users, groups, and managed identities.

## Features

- **Universal Object Support**: Query permissions using Object ID across all Entra ID object types
- **Comprehensive Permission Discovery**: Finds directory roles, app roles, OAuth2 grants, and API permissions
- **Inherited Permissions**: Optional analysis of permissions inherited through group memberships
- **Multiple Object Types**:
  - Application Registrations
  - Service Principals
  - Managed Identities (System & User-assigned)
  - User Accounts
  - Security Groups and Microsoft 365 Groups

## Prerequisites

- PowerShell 5.1 or higher
- Microsoft.Graph.Authentication module (version 2.0.0+)
- Appropriate permissions to query Microsoft Graph API:
  - `Directory.Read.All`
  - `Application.Read.All`
  - `RoleManagement.Read.All`
  - `Policy.Read.All`

## Installation

### Install Required Dependencies

```powershell
Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser
```

### Import the Module

```powershell
Import-Module ./EntraObjectPermissionFinder.psd1
```

## Usage

### Connect to Microsoft Graph

```powershell
# Connect with interactive browser
Initialize-GraphSession

# Connect to specific tenant
Initialize-GraphSession -TenantId "your-tenant-id"

# Use device code authentication
Initialize-GraphSession -UseDeviceCode
```

### Query Object Permissions

```powershell
# Find permissions for an application
Find-EntraObjectPermissions -ObjectId "12345678-1234-1234-1234-123456789012"

# Find permissions for a user with inherited permissions from groups
Find-EntraObjectPermissions -ObjectId "user-object-id" -IncludeInherited

# Pipeline support
"app-id-1", "app-id-2", "user-id-1" | Find-EntraObjectPermissions
```

### Disconnect from Graph

```powershell
Disconnect-GraphSession
```

## Output Structure

The module returns a detailed permission report containing:

- **ObjectId**: The queried object's unique identifier
- **ObjectType**: Detected type (Application, ServicePrincipal, User, Group, ManagedIdentity)
- **DisplayName**: Friendly name of the object
- **DirectPermissions**: Permissions directly assigned to the object
- **RoleAssignments**: Azure AD directory roles assigned
- **GroupMemberships**: Groups the object belongs to (for users)
- **AppRoles**: Application permissions (for service principals)
- **OAuth2Permissions**: Delegated permissions granted
- **InheritedPermissions**: Permissions from group memberships (when -IncludeInherited is used)

## Examples

### Example 1: Analyze App Registration Permissions

```powershell
$permissions = Find-EntraObjectPermissions -ObjectId "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
$permissions | Format-List
```

### Example 2: Export User Permissions to JSON

```powershell
$userPermissions = Find-EntraObjectPermissions -ObjectId "user-guid" -IncludeInherited
$userPermissions | ConvertTo-Json -Depth 5 | Out-File "user-permissions.json"
```

### Example 3: Bulk Analysis

```powershell
$objectIds = Get-Content "objects.txt"
$results = $objectIds | ForEach-Object {
    Find-EntraObjectPermissions -ObjectId $_ -Verbose
}
$results | Export-Csv "permission-report.csv" -NoTypeInformation
```

## Troubleshooting

### Authentication Issues

If you encounter authentication errors:
1. Ensure you have the required Graph scopes
2. Try using `-UseDeviceCode` for non-interactive environments
3. Verify your account has permissions to read directory objects

### Missing Permissions in Output

Some permission types may not appear if:
- Your account lacks sufficient privileges to read them
- The object type doesn't support that permission category
- No permissions of that type are assigned

## License

Copyright (c) 2026. All rights reserved.

## Contributing

Contributions are welcome! Please submit issues or pull requests on GitHub.
