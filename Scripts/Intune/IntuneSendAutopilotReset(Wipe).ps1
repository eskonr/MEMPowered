<#
.SYNOPSIS
The script is used to send remote wipe command from Intune to the selected devices.
The script requires the following scoped permissions and also the module "Microsoft.Graph.DeviceManagement" and "Microsoft.graph"
Scopes:
DeviceManagementManagedDevices.PrivilegedOperations.All
DeviceManagementConfiguration.Read.All
DeviceManagementManagedDevices.ReadWrite.All

Author: Eswar Koneti
Date: 17-Apr-2025
#>

# Get the script location and execution date
$scriptpath = $MyInvocation.MyCommand.Path
$directory = Split-Path $scriptpath
$date = (Get-Date -Format "ddMMyyyy-HHmmss")

# Output file for storing the Azure AD device info and logging
$OutputCsv = "$directory\IntuneRemoteWipeStatus_$date.csv"
$LogFile = "$directory\IntuneRemoteWipeStatus_$date.log"

# Function to log messages
function Log-Message {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "dd-MM-yyyy HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $LogFile -Append
}

# Log script start
Log-Message "Script execution started."

# Define the module names
$modulesToCheck = @('Microsoft.Graph.DeviceManagement')
foreach ($moduleName in $modulesToCheck) {
    # Check if the module is installed
    if (-not (Get-Module -ListAvailable -Name $moduleName)) {
        Log-Message "Module '$moduleName' not found. Installing..."
        try {
            Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber
        } catch {
            Log-Message "Failed to install module '$moduleName'. Error: $_"
            exit
        }
    }

    # Import the required modules
    try {
        Import-Module -Name $moduleName -Force
    } catch {
        Log-Message "Failed to import module '$moduleName'. Error: $_"
        exit
    }
}


$GraphConnected = $false

try {
    $context = Get-MgContext -ErrorAction Stop
    if ($context -and $context.TenantId) {
        $GraphConnected = $true
    } else {
        Log-Message "Microsoft Graph context is empty or invalid."
    }
} catch {
    Log-Message "Unable to retrieve Microsoft Graph details."
}


if (!$GraphConnected) {
    try {
        Connect-MgGraph -Scopes "DeviceManagementManagedDevices.PrivilegedOperations.All","DeviceManagementConfiguration.Read.All","DeviceManagementManagedDevices.ReadWrite.All" -NoWelcome
        $GraphConnected = $true
    } catch {
        Log-Message "Unable to connect to Microsoft Graph. Please investigate."
    }
}

if ($GraphConnected) {
    Write-Host "To send Intune remote wipe command, enter the Device Name OR a filename (e.g. 'Somedevices.txt') in this script's folder containing multiple Device Names." -ForegroundColor Yellow
    $DeviceName = Read-Host
    # Check what was provided
    if ($DeviceName.EndsWith(".txt", "CurrentCultureIgnoreCase")) {
        # It's a file
        if (!(Test-Path -Path "$directory\$DeviceName")) {
            Write-Host "Provided filename of 'DeviceName' cannot be found in the script folder. Try again." -ForegroundColor Red
            Log-Message "Provided filename of 'DeviceName' cannot be found in the script folder."
            exit
        } else {
            $a_DeviceNames = Get-Content "$directory\$DeviceName"
            if ($a_DeviceNames.count -eq 0) {
                Write-Host "Provided filename of 'DeviceName' is empty. Try again." -ForegroundColor Red
                Log-Message "Provided filename of 'DeviceName' is empty."
                exit
            }
        }
    } else {
        $a_DeviceNames = @($DeviceName)
    }

    $i_TotalDevices = $a_DeviceNames.count
    Write-Host "Total Devices found: $i_TotalDevices. Press 'Enter' to send REMOTE WIPE Command (unreversible), or type 'n' then press 'Enter' to exit the script: " -ForegroundColor Yellow -NoNewline
    $Scope = Read-Host
    if ($Scope -ieq "n") {
        Log-Message "User opted to exit the script."
        exit
    }

    Write-Host "Input data received, script execution is in progress..." -ForegroundColor Green
    Log-Message "Total Devices to process: $i_TotalDevices."

# Retrieve all devices that meet the criteria and store them in a hash table for quick lookup
$allWindowsDevices = @{}
$devices = Get-MgDeviceManagementManagedDevice -All | Where-Object {
    ($_.ManagementAgent -eq "configurationManagerClientMdm" -or $_.ManagementAgent -eq "mdm") -and
    ($_.DeviceName -like "SG*" -or $_.DeviceName -like "HK*" -or $_.DeviceName -like "CN*") -and
    ($_.OperatingSystem -like "Windows*")
}

# Populate the hash table with devices using DeviceName as the key
foreach ($device in $devices) {
    if (-not $allWindowsDevices.ContainsKey($device.DeviceName)) {
        $allWindowsDevices[$device.DeviceName] = $device
    }
}

# Initialize output data
$OutputData = @()

# Process each device name
foreach ($DeviceName in $a_DeviceNames) {
    $deviceDetails = $allWindowsDevices[$DeviceName]
    if ($deviceDetails) {
        $deviceId = $deviceDetails.Id
        try {
            # Send the wipe command
            Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$deviceId')/wipe"
            $status = "Success"
            $message = "Wipe command sent successfully."
        } catch {
            $errorMessage = $_.Exception.Message
            Log-Message "Failed to send remote wipe command to $DeviceName. Error: $errorMessage"
            $status = "Failed"
            $message = $errorMessage
        }

        # Constructing output data
        $OutputData += [PSCustomObject]@{
            DeviceName        = $deviceDetails.DeviceName
            AzureAdDeviceId   = $deviceDetails.AzureAdDeviceId
            Id                = $deviceDetails.Id
            UserDisplayName   = $deviceDetails.UserDisplayName
            UserPrincipalName = $deviceDetails.UserPrincipalName
            EmailAddress      = $deviceDetails.EmailAddress
            EnrolledDateTime  = $deviceDetails.EnrolledDateTime
            LastSyncDateTime  = $deviceDetails.LastSyncDateTime
            ManagementAgent   = $deviceDetails.ManagementAgent
            Model             = $deviceDetails.Model
            OSVersion         = $deviceDetails.OSVersion
            SerialNumber      = $deviceDetails.SerialNumber
            Status            = $status
            Message           = $message
        }
    } else {
        # Log-Message "No details found in Intune for Device: $DeviceName."
        $OutputData += [PSCustomObject]@{
            DeviceName        = $DeviceName
            AzureAdDeviceId   = "Not available"
            Id                = "Not available"
            UserDisplayName   = "Not available"
            UserPrincipalName = "Not available"
            EmailAddress      = "Not available"
            EnrolledDateTime  = "Not available"
            LastSyncDateTime  = "Not available"
            ManagementAgent   = "Not available"
            Model             = "Not available"
            OSVersion         = "Not available"
            SerialNumber      = "Not available"
            Status            = "Not found"
            Message           = "Not available"
        }
    }
}

$UniqueOutputData = $OutputData | Select-Object -Unique DeviceName, AzureAdDeviceId, Id, UserDisplayName, UserPrincipalName, EmailAddress, EnrolledDateTime, LastSyncDateTime, ManagementAgent, Model, OSVersion, SerialNumber, Status, Message

    # Export the results to CSV
    $UniqueOutputData | Export-Csv -Path $OutputCsv -NoTypeInformation
    Write-Host "Script execution is completed. See file '$OutputCsv' for status." -ForegroundColor Green
    Log-Message "Script execution completed. Results exported to '$OutputCsv'."
} else {
    Write-Host "Unable to proceed as not connected to Microsoft Graph." -ForegroundColor Red
    Log-Message "Unable to proceed as connection to Microsoft Graph failed."
}

# Log script end
Log-Message "Script execution ended."