<#
.SYNOPSIS
    Get Intune Application Name based on the AppID
.DESCRIPTION
    This script performs the following actions:
    1. Checks for and installs the required Microsoft.Graph.Beta module if needed
    2. Connects to Microsoft Graph with required permissions
    3. Prompt for Intune appID 
    4. Checks win32 app and provides the App details
    
.NOTES
    File Name      : GetApplicationDetailsBasedonAppID.ps1
    Author        : Eswar Koneti
    Prerequisite  : PowerShell 5.1 or later
    Modules: Microsoft.Graph.Beta.Devices.CorporateManagement
    Scopes:DeviceManagementApps.Read.All
#>


#region Module Check and Installation
$moduleName = 'Microsoft.Graph.Beta.Devices.CorporateManagement'

try {
    # Check if module is installed
    if (-not (Get-Module -ListAvailable -Name $moduleName -ErrorAction SilentlyContinue)) {
        Write-Host "Module $moduleName not found. Installing..." -ForegroundColor 'Yellow'

        # Install the module
        Install-Module -Name $moduleName -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
        Write-Host "Successfully installed $moduleName module" -ForegroundColor 'Green'
    }

    # Import the module
    Import-Module $moduleName -ErrorAction Stop
} catch {
    Write-Host "Failed to install or import $moduleName module: $_" -ForegroundColor 'Red'
    exit 1
}
#endregion

# Required permissions
$scopes = @(
    'DeviceManagementApps.Read.All'
)

try {
    Connect-MgGraph -Scopes $scopes -ErrorAction Stop -NoWelcome
    Write-Host 'Successfully connected to Microsoft Graph' -ForegroundColor 'Green'
    Write-Host ''
} catch {
    Write-Host "Failed to connect to Microsoft Graph: $_" -ForegroundColor 'Red'
    exit 1
}
#endregion

$Appid=Read-Host " Enter the Intune Application ID and press enter"
#region Main Processing
Write-Host 'Checking the Application Name based on '$Appid', please wait....' -ForegroundColor Cyan

try {
    $win32App = Get-MgBetaDeviceAppManagementMobileApp -MobileAppId $Appid -ErrorAction Stop
    Write-Host "App Name:$($win32App.DisplayName) (ID:$Appid)"

    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    
} catch {
    Write-Host "Failed to retrieve Win32 app for AppID '$Appid': $_" -Color 'Red'
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    exit 1
}