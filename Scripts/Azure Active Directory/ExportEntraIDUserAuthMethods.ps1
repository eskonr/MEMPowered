<#
.SYNOPSIS
    Exports Entra ID (Azure AD) user authentication method registration details to a CSV.

.DESCRIPTION
    This script connects to Microsoft Graph, retrieves authentication method registration details
    for all users in the tenant, and exports the results to a CSV file in the script's current directory.
    It will automatically install the Microsoft.Graph module if it’s not already installed.

.NOTES
    Author: Eswar Koneti
    Date: 13-Aug-2025
    Requirements: Microsoft.Graph PowerShell module and appropriate Graph API permissions (AuditLog.Read.All)
#>

# ========================
# Set the output CSV path to the script's directory
# ========================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$csvPath = Join-Path $ScriptDir "EntraID_UserAuthMethods.csv"

# Name of the module required for this script
$moduleName = "Microsoft.Graph"

# ========================
# Check if the Microsoft.Graph module is installed
# ========================
if (-not (Get-Module -ListAvailable -Name $moduleName)) {
    Write-Host "Microsoft Graph module not found. Attempting to install..." -ForegroundColor Yellow
    try {
        Install-Module -Name $moduleName -Scope CurrentUser -Force -ErrorAction Stop
        Write-Host "Module installed successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Failed to install the Microsoft Graph module automatically." -ForegroundColor Red
        Write-Host "Please install manually by running:" -ForegroundColor Yellow
        Write-Host "Install-Module -Name Microsoft.Graph -Scope CurrentUser" -ForegroundColor Cyan
        exit 1
    }
}

# ========================
# Remove existing CSV if it already exists
# ========================
if (Test-Path $csvPath) { 
    Remove-Item $csvPath -Force 
    Write-Host "Old CSV file removed." -ForegroundColor DarkGray
}

# ========================
# Connect to Microsoft Graph with required scope
# ========================
Write-Host "Signing in to Microsoft Graph..." -ForegroundColor Cyan
try {
    Connect-MgGraph -Scopes "AuditLog.Read.All" -ErrorAction Stop -NoWelcome
}
catch {
    Write-Host "ERROR: Unable to sign in. Please check your account and try again." -ForegroundColor Red
    exit 1
}

# ========================
# Retrieve all user registration details (with pagination)
# ========================
Write-Host "Fetching user registration details from Microsoft Graph...please wait" -ForegroundColor Cyan

$allUsers = @()
$pageSize = 999
$url = "https://graph.microsoft.com/beta/reports/authenticationMethods/userRegistrationDetails?`$top=$pageSize"

do {
    $response = Invoke-MgGraphRequest -Uri $url -Method GET
    $allUsers += $response.value
    $url = $response.'@odata.nextLink'
} while ($url)

Write-Host "Retrieved $($allUsers.Count) records from Graph API." -ForegroundColor Green

# ========================
# Format the results for CSV output
# ========================
$formattedResults = foreach ($user in $allUsers) {
    [PSCustomObject]@{
        id                                           = $user.id
        userPrincipalName                            = $user.userPrincipalName
        userDisplayName                              = $user.userDisplayName
        userType                                     = $user.userType
        isAdmin                                      = $user.isAdmin
        isSsprRegistered                             = $user.isSsprRegistered
        isSsprEnabled                                = $user.isSsprEnabled
        isSsprCapable                                = $user.isSsprCapable
        isMfaRegistered                              = $user.isMfaRegistered
        isMfaCapable                                 = $user.isMfaCapable
        isPasswordlessCapable                        = $user.isPasswordlessCapable
        methodsRegistered                            = $user.methodsRegistered -join ","
        isSystemPreferredAuthenticationMethodEnabled = $user.isSystemPreferredAuthenticationMethodEnabled
        systemPreferredAuthenticationMethods         = $user.systemPreferredAuthenticationMethods -join ","
        userPreferredMethodForSecondaryAuthentication = $user.userPreferredMethodForSecondaryAuthentication
        lastUpdatedDateTime                          = $user.lastUpdatedDateTime
        defaultMfaMethod                             = $user.defaultMfaMethod
    }
}

# ========================
# Export the results to CSV
# ========================
$formattedResults | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Successfully exported $($formattedResults.Count) records to file:" -ForegroundColor Green
Write-Host "   $csvPath" -ForegroundColor Cyan

# Optional: Disconnect from Graph
 Disconnect-MgGraph -ErrorAction SilentlyContinue
