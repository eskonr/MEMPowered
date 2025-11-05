<#
The script is will connect to Microsoft Graph to fetch all iOS and iPad mobile devices for specific applicatio and its version.
It following scoped permissions and also the module "Microsoft.Graph.
Scopes:
DeviceManagementManagedDevices.Read.All

Author: Eswar Koneti
Date: 05-Nov-2025
#>

# Define script location and execution date
$scriptPath = $MyInvocation.MyCommand.Path
$directory = Split-Path $scriptPath
$date = (Get-Date -Format 'ddMMyyyy-HHmmss')
$application = "Comp Portal"

# Output file for storing the Azure AD device info and logging
$outputCsv = "$directory\ExportMobileDevicesWithApplicationVersion_$date.csv"

# Function to check and install Microsoft Graph module
function Ensure-GraphModule {
    $moduleName = 'Microsoft.Graph'
    if (-not (Get-Module -ListAvailable -Name $moduleName)) {
        Write-Host 'Microsoft Graph module not found. Installing...' -ForegroundColor Yellow
        try {
            Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber
            Import-Module $moduleName
            Write-Host "Microsoft Graph module installed successfully." -ForegroundColor Green
        } catch {
            Write-Host "Failed to install 'Microsoft Graph' module. Please install it manually." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Microsoft Graph module is already installed." -ForegroundColor Green
    }
}

# Function to authenticate with Microsoft Graph
function Authenticate-Graph {
    try {
        Write-Host "Authenticating with Microsoft Graph, please look out for a pop-up window" -ForegroundColor Yellow
        Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All"
        Write-Host "Authentication successful." -ForegroundColor Green
    } catch {
        Write-Host "Failed to authenticate with Microsoft Graph." -ForegroundColor Red
        exit 1
    }
}

# Function to get iOS/iPadOS devices from Intune
function Get-ManagedDevices {
    try {
        Write-Host "Getting all Intune managed mobile devices, specifically iOS and iPadOS" -ForegroundColor Cyan
        $devices = Get-MgDeviceManagementManagedDevice -Filter "operatingSystem eq 'iOS' or operatingSystem eq 'iPadOS'" -All
        if ($devices.Count -gt 0) {
            Write-Host "Found $($devices.Count) devices in Intune." -ForegroundColor Green
            return $devices
        } else {
            Write-Host "No iOS or iPadOS devices found in Intune." -ForegroundColor Yellow
            exit 0
        }
    } catch {
        Write-Host "Failed to retrieve managed devices." -ForegroundColor Red
        exit 1
    }
}

# Function to collect device data with Company Portal version
function Collect-DeviceData {
    param (
        [array]$devices
    )
    $results = @()
    foreach ($device in $devices) {
        try {
            $detectedApps = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$($device.Id)')/detectedApps"
            $compPortalApp = $detectedApps.value | Where-Object { $_.displayName -eq $application }
            
            if ($compPortalApp) {
                $results += $device | Select-Object -Property @{
                    Name = 'DeviceName'; Expression = { $_.DeviceName }
                }, @{
                    Name = 'EnrollmentType'; Expression = { $_.DeviceEnrollmentType }
                }, @{
                    Name = 'ComplianceState'; Expression = { $_.ComplianceState }
                }, @{
                    Name = 'Email'; Expression = { $_.EmailAddress }
                }, @{
                    Name = 'LastSyncTime'; Expression = { $_.LastSyncDateTime }
                }, @{
                    Name = 'Model'; Expression = { $_.Model }
                }, @{
                    Name = 'OS'; Expression = { $_.OperatingSystem }
                }, @{
                    Name = 'OSVersion'; Expression = { $_.OSVersion }
                }, @{
                    Name = 'DeviceId'; Expression = { $_.Id }
                }, @{
                    Name = 'UserPrincipalName'; Expression = { $_.UserPrincipalName }
                }, @{
                    Name = 'CompPortalVersion'; Expression = { $compPortalApp.version }
                }
            }
        } catch {
            Write-Host "Failed to retrieve detected apps for device ID $($device.Id)." -ForegroundColor Red
        }
    }

    if ($results.Count -gt 0) {
        Write-Host "Found devices with '$application'. Preparing to export data." -ForegroundColor Green
        return $results
    } else {
        Write-Host "No devices with '$application' found." -ForegroundColor Yellow
        exit 0
    }
}

# Main script execution
Ensure-GraphModule
Authenticate-Graph
$managedDevices = Get-ManagedDevices
$results = Collect-DeviceData -devices $managedDevices

# Export results to CSV if data exists
if ($results) {
    $results | Export-Csv -Path $outputCsv -NoTypeInformation
    Write-Host "Exported '$application' data to $outputCsv" -ForegroundColor Green
} else {
    Write-Host "No data to export." -ForegroundColor Yellow
}