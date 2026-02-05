# Quick Start Guide

Get started with EntraObjectPermissionFinder in 5 minutes!

## Prerequisites

Ensure you have PowerShell 5.1+ and the Microsoft Graph module:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
```

## Basic Workflow

### Step 1: Import the Module

```powershell
Import-Module ./EntraObjectPermissionFinder.psd1
```

### Step 2: Connect to Microsoft Graph

```powershell
# Interactive browser authentication
Initialize-GraphSession

# Or specify your tenant
Initialize-GraphSession -TenantId "contoso.onmicrosoft.com"
```

You'll be prompted to sign in and consent to the required permissions:
- Directory.Read.All
- Application.Read.All
- RoleManagement.Read.All
- Policy.Read.All

### Step 3: Find Object Permissions

```powershell
# Get the Object ID from Azure Portal or using Graph API
$objectId = "12345678-1234-1234-1234-123456789012"

# Query permissions
$permissions = Find-EntraObjectPermissions -ObjectId $objectId

# Display results
$permissions | Format-List
```

### Step 4: Explore the Results

```powershell
# View app roles (application permissions)
$permissions.AppRoles | Format-Table ResourceName, Permission

# View directory roles
$permissions.RoleAssignments | Format-Table RoleName, Scope

# View OAuth2 grants (delegated permissions)
$permissions.OAuth2Permissions | Format-Table Scope, ConsentType

# For users: include inherited permissions from groups
$userPerms = Find-EntraObjectPermissions -ObjectId $userId -IncludeInherited
$userPerms.InheritedPermissions | Format-Table RoleName, InheritedFrom
```

### Step 5: Disconnect

```powershell
Disconnect-GraphSession
```

## Common Scenarios

### Find App Registration Permissions

```powershell
# Get app by name
$apps = Invoke-MgGraphRequest -Uri "v1.0/applications?`$filter=displayName eq 'MyApp'"
$appId = $apps.value[0].id

# Analyze permissions
Find-EntraObjectPermissions -ObjectId $appId
```

### Audit User Access

```powershell
# Get user
$user = Invoke-MgGraphRequest -Uri "v1.0/users/john@contoso.com"

# Check all permissions including inherited
Find-EntraObjectPermissions -ObjectId $user.id -IncludeInherited
```

### Check Managed Identity Permissions

```powershell
# List managed identities
$mis = Invoke-MgGraphRequest -Uri "v1.0/servicePrincipals?`$filter=servicePrincipalType eq 'ManagedIdentity'"

# Check each one
foreach ($mi in $mis.value) {
    Write-Host "Checking: $($mi.displayName)"
    Find-EntraObjectPermissions -ObjectId $mi.id
}
```

## Tips

1. **Pipeline Support**: You can pipe multiple Object IDs
   ```powershell
   @("guid1", "guid2", "guid3") | Find-EntraObjectPermissions
   ```

2. **Save Results**: Export to CSV or JSON
   ```powershell
   $permissions | ConvertTo-Json -Depth 5 | Out-File "report.json"
   ```

3. **Verbose Output**: Use `-Verbose` for detailed logging
   ```powershell
   Find-EntraObjectPermissions -ObjectId $id -Verbose
   ```

## Need Help?

- Run `Get-Help Find-EntraObjectPermissions -Full` for detailed documentation
- Check `EXAMPLES.md` for more complex scenarios
- See `README.md` for complete reference

## Troubleshooting

**Problem**: "No active Graph session"
**Solution**: Run `Initialize-GraphSession` first

**Problem**: "Insufficient privileges"
**Solution**: Ensure your account has appropriate read permissions in Entra ID

**Problem**: "Object not found"
**Solution**: Verify the Object ID is correct and you have access to view it
