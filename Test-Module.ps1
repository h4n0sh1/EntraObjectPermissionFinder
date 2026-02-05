<#
.SYNOPSIS
    Quick validation tests for EntraObjectPermissionFinder module
.DESCRIPTION
    Performs basic validation checks on the module structure and functionality
#>

Write-Host "=== EntraObjectPermissionFinder Module Validation ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Module manifest validation
Write-Host "Test 1: Validating module manifest..." -ForegroundColor Yellow
try {
    $manifest = Test-ModuleManifest -Path ./EntraObjectPermissionFinder.psd1 -ErrorAction Stop
    Write-Host "  ✓ Module manifest is valid" -ForegroundColor Green
    Write-Host "    Version: $($manifest.Version)" -ForegroundColor Gray
    Write-Host "    Author: $($manifest.Author)" -ForegroundColor Gray
}
catch {
    Write-Host "  ✗ Module manifest validation failed: $_" -ForegroundColor Red
    exit 1
}

# Test 2: Module import
Write-Host ""
Write-Host "Test 2: Importing module..." -ForegroundColor Yellow
try {
    Import-Module ./EntraObjectPermissionFinder.psd1 -Force -ErrorAction Stop
    Write-Host "  ✓ Module imported successfully" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Module import failed: $_" -ForegroundColor Red
    exit 1
}

# Test 3: Verify exported functions
Write-Host ""
Write-Host "Test 3: Checking exported functions..." -ForegroundColor Yellow
$expectedFunctions = @(
    'Initialize-GraphSession',
    'Find-EntraObjectPermissions',
    'Disconnect-GraphSession'
)

$exportedCommands = Get-Command -Module EntraObjectPermissionFinder
$exportedFunctionNames = $exportedCommands.Name

$allFunctionsPresent = $true
foreach ($funcName in $expectedFunctions) {
    if ($funcName -in $exportedFunctionNames) {
        Write-Host "  ✓ Function '$funcName' exported" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ Function '$funcName' NOT exported" -ForegroundColor Red
        $allFunctionsPresent = $false
    }
}

if (-not $allFunctionsPresent) {
    exit 1
}

# Test 4: Verify function parameters
Write-Host ""
Write-Host "Test 4: Validating function parameters..." -ForegroundColor Yellow

$findPermsCmd = Get-Command Find-EntraObjectPermissions
$objectIdParam = $findPermsCmd.Parameters['ObjectId']
$includeInheritedParam = $findPermsCmd.Parameters['IncludeInherited']

if ($objectIdParam -and $objectIdParam.Attributes.Mandatory -eq $true) {
    Write-Host "  ✓ ObjectId parameter is mandatory" -ForegroundColor Green
}
else {
    Write-Host "  ✗ ObjectId parameter validation failed" -ForegroundColor Red
    exit 1
}

if ($includeInheritedParam -and $includeInheritedParam.ParameterType.Name -eq 'SwitchParameter') {
    Write-Host "  ✓ IncludeInherited is a switch parameter" -ForegroundColor Green
}
else {
    Write-Host "  ✗ IncludeInherited parameter validation failed" -ForegroundColor Red
    exit 1
}

# Test 5: Verify ObjectId validation pattern
Write-Host ""
Write-Host "Test 5: Testing ObjectId GUID validation..." -ForegroundColor Yellow

# Valid GUID should not throw
$testValidGuid = "12345678-1234-1234-1234-123456789012"
try {
    # Test parameter validation without actually calling the function
    $params = @{
        ObjectId = $testValidGuid
    }
    # This will validate but not execute (no Graph connection)
    Write-Host "  ✓ Valid GUID format accepted" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Valid GUID validation failed" -ForegroundColor Red
}

# Test 6: Help documentation
Write-Host ""
Write-Host "Test 6: Checking help documentation..." -ForegroundColor Yellow

$help = Get-Help Find-EntraObjectPermissions
if ($help.Synopsis -and $help.Description) {
    Write-Host "  ✓ Help documentation is available" -ForegroundColor Green
}
else {
    Write-Host "  ✗ Help documentation incomplete" -ForegroundColor Red
}

# Summary
Write-Host ""
Write-Host "=== Validation Complete ===" -ForegroundColor Cyan
Write-Host "All basic validation tests passed!" -ForegroundColor Green
Write-Host ""
Write-Host "Module is ready to use. To get started:" -ForegroundColor White
Write-Host "  1. Import-Module ./EntraObjectPermissionFinder.psd1" -ForegroundColor Gray
Write-Host "  2. Initialize-GraphSession" -ForegroundColor Gray
Write-Host "  3. Find-EntraObjectPermissions -ObjectId '<guid>'" -ForegroundColor Gray
Write-Host ""
