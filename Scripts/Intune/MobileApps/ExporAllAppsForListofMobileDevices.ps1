# Define script location and execution date
$scriptPath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptPath
$date = (Get-Date -Format 'ddMMyyyy-HHmmss')

# Output file for storing the Azure AD device info and logging
$outputCsv = "$dir\AllAppsForDevices_$date.csv"

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

# Function to get all apps for a list of device IDs
function Get-AllAppsForDevices {
    param (
        [string[]]$deviceIds
    )

    $results = @()
    
    foreach ($deviceId in $deviceIds) {
        try {
            # Retrieve detected apps for each device ID
            $detectedApps = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$deviceId')/detectedApps"
            
            # Fetch device information
            $device = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $deviceId

            foreach ($app in $detectedApps.value) {
                $results += [PSCustomObject]@{
                    DeviceName = $device.DeviceName
                    EnrollmentType = $device.DeviceEnrollmentType
                    ComplianceState = $device.ComplianceState
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
        } catch {
            Write-Host "Failed to retrieve data for device ID $deviceId." -ForegroundColor Red
        }
    }

    return $results
}

# Main script execution
Ensure-GraphModule
if (Authenticate-Graph) {
    # Prompt user for the device ID file
    Write-Host "Type the txt file name located in the script folder (e.g someDevices.txt) containing device IDs and then press Enter: " -ForegroundColor Yellow
    $deviceNameFile = Read-Host
    
    # Validate the input file
    if ($deviceNameFile.EndsWith(".txt", "CurrentCultureIgnoreCase")) {
        # Check if the file exists
        if (!(Test-Path -Path "$dir\$deviceNameFile")) {
            Write-Host "Input filename of devices cannot be found. Try again." -ForegroundColor Red
            Read-Host -Prompt "When ready, press 'Enter' to exit..."
            exit
        } else {
            # Read device IDs from file
            $a_DeviceNames = Get-Content -Path "$dir\$deviceNameFile"
            if ($a_DeviceNames.Count -eq 0) {
                Write-Host "Input filename of devices is empty. Try again." -ForegroundColor Red
                Read-Host -Prompt "When ready, press 'Enter' to exit..."
                exit
            }
        }
    } else {
        Write-Host "Input filename is not correct. Please check the filename extension and try again." -ForegroundColor Red
        Read-Host -Prompt "When ready, press 'Enter' to exit..."
        exit
    }

    Write-Host "Data validation is in progress ..." -ForegroundColor Green
    $i_TotalDevices = $a_DeviceNames.Count
    Write-Host "Total devices found: $i_TotalDevices. Press 'Enter' to process the devices or type 'n' then press 'Enter' to exit the script: " -ForegroundColor Yellow -NoNewline
    $scope = Read-Host

    if ($scope -ieq "n") {
        Write-Host "User has stopped the script execution." -ForegroundColor Red
        exit
    }

    Write-Host "Processing devices..." -ForegroundColor Green

    # Process and export data for all devices
    $results = Get-AllAppsForDevices -deviceIds $a_DeviceNames

    # Export results to CSV if data exists
    if ($results) {
        $results | Export-Csv -Path $outputCsv -NoTypeInformation
        Write-Host "Exported all app data to $outputCsv" -ForegroundColor Green
    } else {
        Write-Host "No app data to export." -ForegroundColor Yellow
    }
}