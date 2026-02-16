<#
The script is will connect to Microsoft Graph to fetch all iOS and iPad mobile devices for specific applicatio and its version.
It following scoped permissions and also the module "Microsoft.Graph.
Scopes:
DeviceManagementManagedDevices.Read.All

Author: Eswar Koneti
Date: 05-Nov-2025
#>

# ===== Start time tracking =====
$scriptStart = Get-Date

# Define script location and execution date
$scriptPath = $MyInvocation.MyCommand.Path
$directory = Split-Path $scriptPath
$date = (Get-Date -Format 'ddMMyyyy-HHmmss')
# Output file for storing the Azure AD device info and logging
$outputCsv = "$directory\ExportAppForListOfMobileDevicesUsingID_$date.csv"

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

function Get-ManagedDevices {
    try {
        Write-Host "Reading managed device IDs from $directory" -ForegroundColor Cyan
        $filePath = "$directory\somedevices.txt"
        if (-not (Test-Path $filePath)) {
            Write-Host "File not found: $filePath" -ForegroundColor Red
            exit 1
        }
        $deviceIds = Get-Content -Path $filePath | Where-Object { $_ -and $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }
        if ($deviceIds.Count -gt 0) {
            Write-Host "Found $($deviceIds.Count) device IDs." -ForegroundColor Green
            return $deviceIds
        } else {
            Write-Host "No device IDs found in file." -ForegroundColor Yellow
            exit 0
        }
    } catch {
        Write-Host "Failed to read device IDs from file." -ForegroundColor Red
        exit 1
    }
}

# Function to collect device data with full app inventory (no Company Portal filter)
function Collect-DeviceData {
    param (
        [array]$devices
    )
    $results = @()
    foreach ($deviceId in $devices) {
        try {
            # Get device details and detected apps
            $device = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $deviceId
            $detectedAppsResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$deviceId')/detectedApps"
            $detectedApps = $detectedAppsResponse.value

            foreach ($app in $detectedApps) {
                $results += [pscustomobject]@{
                    DeviceName        = $device.DeviceName
                    #EnrollmentType    = $device.DeviceEnrollmentType
                    #ComplianceState   = $device.ComplianceState
                    Email             = $device.EmailAddress
                    LastSyncTime      = $device.LastSyncDateTime
                    Model             = $device.Model
                    OS                = $device.OperatingSystem
                    OSVersion         = $device.OSVersion
                    Supervised        =$device.IsSupervised
                    DeviceId          = $device.Id
                    UserPrincipalName = $device.UserPrincipalName
                    AppDisplayName    = $app.displayName
                    #AppVersion        = $app.version

                }
            }
        } catch {
            Write-Host "Failed to retrieve data for device ID $deviceId." -ForegroundColor Red
        }
    }

    if ($results.Count -gt 0) {
        Write-Host "Collected app inventory for supplied devices. Preparing to export data." -ForegroundColor Green
        return $results
    } else {
        Write-Host "No app inventory data found for supplied devices." -ForegroundColor Yellow
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
$results = $results |
    Sort-Object DeviceId, AppDisplayName |
    Select-Object DeviceId, AppDisplayName, DeviceName, Email, LastSyncTime, Model, OS, OSVersion, Supervised, UserPrincipalName -Unique
    $results | Export-Csv -Path $outputCsv -NoTypeInformation
    Write-Host "Exported app inventory data to $outputCsv" -ForegroundColor Green
} else {
    Write-Host "No data to export." -ForegroundColor Yellow
}
# ===== End time tracking and report =====
$scriptEnd = Get-Date
$elapsedSeconds = [math]::Round(($scriptEnd - $scriptStart).TotalSeconds, 2)
$elapsedMinutes = [math]::Round(($scriptEnd - $scriptStart).TotalMinutes, 2)
Write-Host "Total time taken: $elapsedSeconds seconds ($elapsedMinutes minutes)" -ForegroundColor Cyan