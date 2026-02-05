#Requires -Version 5.1

<#
.SYNOPSIS
    EntraObjectPermissionFinder - Discover permissions assigned to Entra ID objects
.DESCRIPTION
    This module queries Microsoft Graph to identify all permissions assigned to any Entra ID object
    including app registrations, users, groups, and managed identities using their object ID.
#>

# Module-level variables for session state
$script:GraphConnection = $null
$script:CurrentTenantId = $null

function Initialize-GraphSession {
    <#
    .SYNOPSIS
        Establishes connection to Microsoft Graph API
    .PARAMETER TenantId
        The Azure AD tenant identifier
    .PARAMETER UseDeviceCode
        Use device code flow for authentication
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$TenantId,
        
        [Parameter(Mandatory = $false)]
        [switch]$UseDeviceCode
    )
    
    try {
        $requiredScopes = @(
            'Directory.Read.All',
            'Application.Read.All',
            'RoleManagement.Read.All',
            'Policy.Read.All'
        )
        
        $connectionParams = @{
            Scopes = $requiredScopes
        }
        
        if ($TenantId) {
            $connectionParams['TenantId'] = $TenantId
            $script:CurrentTenantId = $TenantId
        }
        
        if ($UseDeviceCode) {
            $connectionParams['UseDeviceAuthentication'] = $true
        }
        
        Connect-MgGraph @connectionParams -ErrorAction Stop
        $script:GraphConnection = Get-MgContext
        
        Write-Verbose "Successfully connected to tenant: $($script:GraphConnection.TenantId)"
        return $true
    }
    catch {
        Write-Error "Failed to establish Graph connection: $_"
        return $false
    }
}

function Find-EntraObjectPermissions {
    <#
    .SYNOPSIS
        Retrieves all permissions for an Entra ID object
    .DESCRIPTION
        Queries Microsoft Graph to find permissions assigned to any object type in Entra ID
        Supports app registrations, service principals, users, groups, and managed identities
    .PARAMETER ObjectId
        The unique identifier (Object ID) of the Entra object
    .PARAMETER IncludeInherited
        Include permissions inherited from group memberships
    .EXAMPLE
        Find-EntraObjectPermissions -ObjectId "12345678-1234-1234-1234-123456789012"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
        [string]$ObjectId,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeInherited
    )
    
    begin {
        if (-not $script:GraphConnection) {
            Write-Warning "No active Graph session. Attempting to connect..."
            if (-not (Initialize-GraphSession)) {
                throw "Unable to establish Graph connection. Please run Initialize-GraphSession first."
            }
        }
    }
    
    process {
        try {
            Write-Verbose "Analyzing object: $ObjectId"
            
            # Determine object type
            $objectDetails = Get-ObjectTypeAndDetails -ObjectId $ObjectId
            
            if (-not $objectDetails) {
                Write-Error "Object $ObjectId not found or inaccessible"
                return
            }
            
            # Build permission report
            $permissionReport = [PSCustomObject]@{
                ObjectId = $ObjectId
                ObjectType = $objectDetails.Type
                DisplayName = $objectDetails.Name
                DirectPermissions = @()
                RoleAssignments = @()
                GroupMemberships = @()
                AppRoles = @()
                OAuth2Permissions = @()
                InheritedPermissions = @()
            }
            
            # Collect permissions based on object type
            switch ($objectDetails.Type) {
                'ServicePrincipal' {
                    $permissionReport = Collect-ServicePrincipalPermissions -ObjectId $ObjectId -Report $permissionReport
                }
                'Application' {
                    $permissionReport = Collect-ApplicationPermissions -ObjectId $ObjectId -Report $permissionReport
                }
                'User' {
                    $permissionReport = Collect-UserPermissions -ObjectId $ObjectId -Report $permissionReport -IncludeInherited:$IncludeInherited
                }
                'Group' {
                    $permissionReport = Collect-GroupPermissions -ObjectId $ObjectId -Report $permissionReport
                }
                'ManagedIdentity' {
                    $permissionReport = Collect-ManagedIdentityPermissions -ObjectId $ObjectId -Report $permissionReport
                }
                default {
                    Write-Warning "Unknown object type: $($objectDetails.Type)"
                }
            }
            
            return $permissionReport
        }
        catch {
            Write-Error "Error processing object $ObjectId : $_"
        }
    }
}

function Get-ObjectTypeAndDetails {
    [CmdletBinding()]
    param([string]$ObjectId)
    
    # Try to identify object as ServicePrincipal first
    try {
        $sp = Invoke-MgGraphRequest -Method GET -Uri "v1.0/servicePrincipals/$ObjectId" -ErrorAction SilentlyContinue
        if ($sp) {
            $isManagedIdentity = $sp.servicePrincipalType -eq 'ManagedIdentity'
            return @{
                Type = if ($isManagedIdentity) { 'ManagedIdentity' } else { 'ServicePrincipal' }
                Name = $sp.displayName
                RawObject = $sp
            }
        }
    }
    catch { }
    
    # Try Application
    try {
        $app = Invoke-MgGraphRequest -Method GET -Uri "v1.0/applications/$ObjectId" -ErrorAction SilentlyContinue
        if ($app) {
            return @{
                Type = 'Application'
                Name = $app.displayName
                RawObject = $app
            }
        }
    }
    catch { }
    
    # Try User
    try {
        $user = Invoke-MgGraphRequest -Method GET -Uri "v1.0/users/$ObjectId" -ErrorAction SilentlyContinue
        if ($user) {
            return @{
                Type = 'User'
                Name = $user.displayName
                RawObject = $user
            }
        }
    }
    catch { }
    
    # Try Group
    try {
        $group = Invoke-MgGraphRequest -Method GET -Uri "v1.0/groups/$ObjectId" -ErrorAction SilentlyContinue
        if ($group) {
            return @{
                Type = 'Group'
                Name = $group.displayName
                RawObject = $group
            }
        }
    }
    catch { }
    
    return $null
}

function Collect-ServicePrincipalPermissions {
    [CmdletBinding()]
    param(
        [string]$ObjectId,
        [PSCustomObject]$Report
    )
    
    # Get app role assignments (application permissions)
    try {
        $appRoleAssignments = Invoke-MgGraphRequest -Method GET -Uri "v1.0/servicePrincipals/$ObjectId/appRoleAssignments"
        foreach ($assignment in $appRoleAssignments.value) {
            $Report.AppRoles += [PSCustomObject]@{
                ResourceName = $assignment.resourceDisplayName
                ResourceId = $assignment.resourceId
                Permission = $assignment.principalDisplayName
                AppRoleId = $assignment.appRoleId
                AssignedDate = $assignment.createdDateTime
            }
        }
    }
    catch {
        Write-Verbose "Could not retrieve app role assignments: $_"
    }
    
    # Get OAuth2 permission grants (delegated permissions)
    try {
        $oauth2Grants = Invoke-MgGraphRequest -Method GET -Uri "v1.0/servicePrincipals/$ObjectId/oauth2PermissionGrants"
        foreach ($grant in $oauth2Grants.value) {
            $Report.OAuth2Permissions += [PSCustomObject]@{
                ResourceId = $grant.resourceId
                Scope = $grant.scope
                ConsentType = $grant.consentType
                ExpiryTime = $grant.expiryTime
                GrantedBy = $grant.principalId
            }
        }
    }
    catch {
        Write-Verbose "Could not retrieve OAuth2 grants: $_"
    }
    
    # Get directory role assignments
    try {
        $roleAssignments = Invoke-MgGraphRequest -Method GET -Uri "v1.0/roleManagement/directory/roleAssignments?`$filter=principalId eq '$ObjectId'"
        foreach ($role in $roleAssignments.value) {
            $roleDefinition = Invoke-MgGraphRequest -Method GET -Uri "v1.0/roleManagement/directory/roleDefinitions/$($role.roleDefinitionId)"
            $Report.RoleAssignments += [PSCustomObject]@{
                RoleName = $roleDefinition.displayName
                RoleId = $role.roleDefinitionId
                Scope = $role.directoryScopeId
                AssignmentId = $role.id
            }
        }
    }
    catch {
        Write-Verbose "Could not retrieve role assignments: $_"
    }
    
    return $Report
}

function Collect-ApplicationPermissions {
    [CmdletBinding()]
    param(
        [string]$ObjectId,
        [PSCustomObject]$Report
    )
    
    # Get required resource access (API permissions requested by the app)
    try {
        $app = Invoke-MgGraphRequest -Method GET -Uri "v1.0/applications/$ObjectId"
        
        foreach ($resourceAccess in $app.requiredResourceAccess) {
            foreach ($permission in $resourceAccess.resourceAccess) {
                $Report.DirectPermissions += [PSCustomObject]@{
                    ResourceAppId = $resourceAccess.resourceAppId
                    PermissionId = $permission.id
                    PermissionType = $permission.type
                    Status = 'Requested'
                }
            }
        }
    }
    catch {
        Write-Verbose "Could not retrieve application permissions: $_"
    }
    
    # Also check the associated service principal if it exists
    try {
        $spFilter = "appId eq '$($app.appId)'"
        $servicePrincipals = Invoke-MgGraphRequest -Method GET -Uri "v1.0/servicePrincipals?`$filter=$spFilter"
        if ($servicePrincipals.value -and $servicePrincipals.value.Count -gt 0) {
            $spObjectId = $servicePrincipals.value[0].id
            $Report = Collect-ServicePrincipalPermissions -ObjectId $spObjectId -Report $Report
        }
    }
    catch {
        Write-Verbose "Could not retrieve associated service principal: $_"
    }
    
    return $Report
}

function Collect-UserPermissions {
    [CmdletBinding()]
    param(
        [string]$ObjectId,
        [PSCustomObject]$Report,
        [switch]$IncludeInherited
    )
    
    # Get direct role assignments
    try {
        $roleAssignments = Invoke-MgGraphRequest -Method GET -Uri "v1.0/roleManagement/directory/roleAssignments?`$filter=principalId eq '$ObjectId'"
        foreach ($role in $roleAssignments.value) {
            $roleDefinition = Invoke-MgGraphRequest -Method GET -Uri "v1.0/roleManagement/directory/roleDefinitions/$($role.roleDefinitionId)"
            $Report.RoleAssignments += [PSCustomObject]@{
                RoleName = $roleDefinition.displayName
                RoleId = $role.roleDefinitionId
                Scope = $role.directoryScopeId
                AssignmentId = $role.id
                AssignmentType = 'Direct'
            }
        }
    }
    catch {
        Write-Verbose "Could not retrieve user role assignments: $_"
    }
    
    # Get group memberships
    try {
        $groups = Invoke-MgGraphRequest -Method GET -Uri "v1.0/users/$ObjectId/memberOf"
        foreach ($group in $groups.value) {
            $Report.GroupMemberships += [PSCustomObject]@{
                GroupId = $group.id
                GroupName = $group.displayName
                GroupType = $group.'@odata.type'
            }
            
            # If IncludeInherited, get permissions from groups
            if ($IncludeInherited) {
                $groupRoles = Invoke-MgGraphRequest -Method GET -Uri "v1.0/roleManagement/directory/roleAssignments?`$filter=principalId eq '$($group.id)'"
                foreach ($role in $groupRoles.value) {
                    $roleDefinition = Invoke-MgGraphRequest -Method GET -Uri "v1.0/roleManagement/directory/roleDefinitions/$($role.roleDefinitionId)"
                    $Report.InheritedPermissions += [PSCustomObject]@{
                        RoleName = $roleDefinition.displayName
                        RoleId = $role.roleDefinitionId
                        InheritedFrom = $group.displayName
                        InheritedFromId = $group.id
                    }
                }
            }
        }
    }
    catch {
        Write-Verbose "Could not retrieve group memberships: $_"
    }
    
    return $Report
}

function Collect-GroupPermissions {
    [CmdletBinding()]
    param(
        [string]$ObjectId,
        [PSCustomObject]$Report
    )
    
    # Get role assignments for the group
    try {
        $roleAssignments = Invoke-MgGraphRequest -Method GET -Uri "v1.0/roleManagement/directory/roleAssignments?`$filter=principalId eq '$ObjectId'"
        foreach ($role in $roleAssignments.value) {
            $roleDefinition = Invoke-MgGraphRequest -Method GET -Uri "v1.0/roleManagement/directory/roleDefinitions/$($role.roleDefinitionId)"
            $Report.RoleAssignments += [PSCustomObject]@{
                RoleName = $roleDefinition.displayName
                RoleId = $role.roleDefinitionId
                Scope = $role.directoryScopeId
                AssignmentId = $role.id
            }
        }
    }
    catch {
        Write-Verbose "Could not retrieve group role assignments: $_"
    }
    
    # Get group members count
    try {
        $members = Invoke-MgGraphRequest -Method GET -Uri "v1.0/groups/$ObjectId/members?`$count=true" -Headers @{ConsistencyLevel = 'eventual' }
        $Report | Add-Member -NotePropertyName 'MemberCount' -NotePropertyValue $members.'@odata.count' -Force
    }
    catch {
        Write-Verbose "Could not retrieve group members: $_"
    }
    
    return $Report
}

function Collect-ManagedIdentityPermissions {
    [CmdletBinding()]
    param(
        [string]$ObjectId,
        [PSCustomObject]$Report
    )
    
    # Managed identities are service principals, so use that collector
    $Report = Collect-ServicePrincipalPermissions -ObjectId $ObjectId -Report $Report
    
    return $Report
}

function Disconnect-GraphSession {
    <#
    .SYNOPSIS
        Disconnects from Microsoft Graph
    #>
    [CmdletBinding()]
    param()
    
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        $script:GraphConnection = $null
        $script:CurrentTenantId = $null
        Write-Verbose "Disconnected from Microsoft Graph"
    }
    catch {
        Write-Warning "Error disconnecting: $_"
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Initialize-GraphSession',
    'Find-EntraObjectPermissions',
    'Disconnect-GraphSession'
)
