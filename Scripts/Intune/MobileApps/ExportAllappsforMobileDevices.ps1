# Define script location and execution date
$scriptPath = $MyInvocation.MyCommand.Path
$directory = Split-Path $scriptPath
$date = (Get-Date -Format 'ddMMyyyy-HHmmss')

# Output file for storing the Azure AD device info and logging
$outputCsv = "$directory\ExportMobileDevicesWithAllApps_$date.csv"

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

# Function to get all detected apps for iOS/iPadOS devices
function Get-AllDetectedApps {
    try {
        Write-Host "Getting all Intune managed mobile devices, specifically iOS and iPadOS" -ForegroundColor Cyan
        $devices = Get-MgDeviceManagementManagedDevice -Filter "operatingSystem eq 'iOS' or operatingSystem eq 'iPadOS'" -All
        if ($devices.Count -gt 0) {
            Write-Host "Found $($devices.Count) devices in Intune. Retrieving detected apps..." -ForegroundColor Green
            $allApps = @()

            foreach ($device in $devices) {
                $detectedApps = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$($device.Id)')/detectedApps"

                foreach ($app in $detectedApps.value) {
                    $allApps += [PSCustomObject]@{
                        DeviceName = $device.DeviceName
                        EnrollmentType = $device.DeviceEnrollmentType
                        Email = $device.EmailAddress
                        LastSyncTime = $device.LastSyncDateTime
                        Model = $device.Model
                        OS = $device.OperatingSystem
                        OSVersion = $device.OSVersion
                        DeviceId = $device.Id
                        UserPrincipalName = $device.UserPrincipalName
                        AppDisplayName = $app.displayName
                        AppVersion = $app.version
                    }
                }
            }

            return $allApps
        } else {
            Write-Host "No iOS or iPadOS devices found in Intune." -ForegroundColor Yellow
            exit 0
        }
    } catch {
        Write-Host "Failed to retrieve detected apps." -ForegroundColor Red
        exit 1
    }
}

# Main script execution
Ensure-GraphModule
Authenticate-Graph
$allApps = Get-AllDetectedApps

# Export results to CSV if data exists
if ($allApps) {
    $allApps | Export-Csv -Path $outputCsv -NoTypeInformation
    Write-Host "Exported all app data to $outputCsv" -ForegroundColor Green
} else {
    Write-Host "No app data to export." -ForegroundColor Yellow
}