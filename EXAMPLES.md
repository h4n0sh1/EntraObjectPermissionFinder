# EntraObjectPermissionFinder - Usage Examples

This file contains practical examples for using the EntraObjectPermissionFinder module.

## Setup

```powershell
# Import the module
Import-Module ./EntraObjectPermissionFinder.psd1

# Connect to your tenant
Initialize-GraphSession -TenantId "your-tenant-id"
```

## Example 1: Check Service Principal Permissions

```powershell
# Find an app by name first
$apps = Invoke-MgGraphRequest -Method GET -Uri "v1.0/servicePrincipals?`$filter=startswith(displayName,'MyApp')"
$appObjectId = $apps.value[0].id

# Get all permissions
$permissions = Find-EntraObjectPermissions -ObjectId $appObjectId

# Display app roles
Write-Host "Application Permissions:" -ForegroundColor Cyan
$permissions.AppRoles | Format-Table ResourceName, Permission, AssignedDate

# Display delegated permissions
Write-Host "Delegated Permissions:" -ForegroundColor Cyan
$permissions.OAuth2Permissions | Format-Table ResourceId, Scope, ConsentType
```

## Example 2: Audit User Access

```powershell
# Get a user's object ID
$user = Invoke-MgGraphRequest -Method GET -Uri "v1.0/users/user@domain.com"
$userObjectId = $user.id

# Get comprehensive permission report including inherited
$userPerms = Find-EntraObjectPermissions -ObjectId $userObjectId -IncludeInherited

# Show direct roles
Write-Host "Direct Role Assignments:" -ForegroundColor Green
$userPerms.RoleAssignments | Where-Object { $_.AssignmentType -eq 'Direct' } | Format-Table RoleName, Scope

# Show inherited roles
Write-Host "Inherited Roles (from groups):" -ForegroundColor Yellow
$userPerms.InheritedPermissions | Format-Table RoleName, InheritedFrom
```

## Example 3: Managed Identity Analysis

```powershell
# Find managed identity by name
$mis = Invoke-MgGraphRequest -Method GET -Uri "v1.0/servicePrincipals?`$filter=servicePrincipalType eq 'ManagedIdentity' and displayName eq 'my-managed-identity'"
$miObjectId = $mis.value[0].id

# Analyze permissions
$miPerms = Find-EntraObjectPermissions -ObjectId $miObjectId

Write-Host "Managed Identity: $($miPerms.DisplayName)" -ForegroundColor Magenta
Write-Host "Granted App Roles:" -ForegroundColor Cyan
$miPerms.AppRoles | Format-Table ResourceName, Permission

Write-Host "Directory Roles:" -ForegroundColor Cyan
$miPerms.RoleAssignments | Format-Table RoleName, Scope
```

## Example 4: Bulk Permission Audit

```powershell
# Get all service principals with app role assignments
$allSPs = Invoke-MgGraphRequest -Method GET -Uri "v1.0/servicePrincipals?`$select=id,displayName,appId"

$auditResults = @()
foreach ($sp in $allSPs.value) {
    Write-Host "Analyzing: $($sp.displayName)"
    $perms = Find-EntraObjectPermissions -ObjectId $sp.id
    
    if ($perms.AppRoles.Count -gt 0 -or $perms.RoleAssignments.Count -gt 0) {
        $auditResults += [PSCustomObject]@{
            DisplayName = $sp.displayName
            AppId = $sp.appId
            ObjectId = $sp.id
            AppRoleCount = $perms.AppRoles.Count
            DirectoryRoleCount = $perms.RoleAssignments.Count
            OAuth2GrantCount = $perms.OAuth2Permissions.Count
        }
    }
}

# Export results
$auditResults | Export-Csv "tenant-permission-audit.csv" -NoTypeInformation
Write-Host "Audit complete. Results saved to tenant-permission-audit.csv"
```

## Example 5: Compare Permissions Between Objects

```powershell
# Compare two service principals
$sp1Perms = Find-EntraObjectPermissions -ObjectId "guid-1"
$sp2Perms = Find-EntraObjectPermissions -ObjectId "guid-2"

Write-Host "Comparing: $($sp1Perms.DisplayName) vs $($sp2Perms.DisplayName)" -ForegroundColor Cyan

# Compare app roles
$sp1Roles = $sp1Perms.AppRoles.Permission
$sp2Roles = $sp2Perms.AppRoles.Permission

$uniqueToSp1 = $sp1Roles | Where-Object { $_ -notin $sp2Roles }
$uniqueToSp2 = $sp2Roles | Where-Object { $_ -notin $sp1Roles }
$common = $sp1Roles | Where-Object { $_ -in $sp2Roles }

Write-Host "Unique to $($sp1Perms.DisplayName): $($uniqueToSp1 -join ', ')"
Write-Host "Unique to $($sp2Perms.DisplayName): $($uniqueToSp2 -join ', ')"
Write-Host "Common permissions: $($common -join ', ')"
```

## Example 6: Generate HTML Permission Report

```powershell
$objectId = "your-object-id"
$perms = Find-EntraObjectPermissions -ObjectId $objectId

$html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Permission Report - $($perms.DisplayName)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #0078d4; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th { background-color: #0078d4; color: white; padding: 10px; text-align: left; }
        td { border: 1px solid #ddd; padding: 8px; }
        tr:nth-child(even) { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Permission Report</h1>
    <p><strong>Object:</strong> $($perms.DisplayName)</p>
    <p><strong>Object ID:</strong> $($perms.ObjectId)</p>
    <p><strong>Type:</strong> $($perms.ObjectType)</p>
    
    <h2>App Roles</h2>
    <table>
        <tr><th>Resource</th><th>Permission</th><th>Assigned Date</th></tr>
        $(foreach ($role in $perms.AppRoles) { "<tr><td>$($role.ResourceName)</td><td>$($role.Permission)</td><td>$($role.AssignedDate)</td></tr>" })
    </table>
    
    <h2>Directory Roles</h2>
    <table>
        <tr><th>Role Name</th><th>Scope</th></tr>
        $(foreach ($role in $perms.RoleAssignments) { "<tr><td>$($role.RoleName)</td><td>$($role.Scope)</td></tr>" })
    </table>
</body>
</html>
"@

$html | Out-File "permission-report.html"
Write-Host "Report generated: permission-report.html"
Start-Process "permission-report.html"
```

## Cleanup

```powershell
# Disconnect when done
Disconnect-GraphSession
```
