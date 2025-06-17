<#
.SYNOPSIS
The script is used to send remote retire command to mobile devices managed by intune using the serial numbers in a text file.
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
$OutputCsv = "$directory\IntuneRetireStatus_$date.csv"
$LogFile = "$directory\IntuneRetireStatus_$date.log"

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
        Connect-MgGraph -Scopes "DeviceManagementManagedDevices.PrivilegedOperations.All","DeviceManagementConfiguration.Read.All","DeviceManagementManagedDevices.ReadWrite.All" -NoWelcome -ErrorAction Stop
        $GraphConnected = $true
    } catch {
        Log-Message "Unable to connect to Microsoft Graph. Please investigate."
        exit
    }

if ($GraphConnected) {
    Write-Host "To send Intune remote RETIRE command, enter the Serial number of the device OR a filename (e.g. 'Somedevices.txt') in this script's folder containing multiple Device serial numbers." -ForegroundColor Yellow
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
    Write-Host "Total Devices found: $i_TotalDevices. Press 'Enter' to send REMOTE RETIRE Command (unreversible), or type 'n' then press 'Enter' to exit the script: " -ForegroundColor Yellow -NoNewline
    $Scope = Read-Host
    if ($Scope -ieq "n") {
        Log-Message "User opted to exit the script."
        exit
    }

    Write-Host "Input data received, script execution is in progress..." -ForegroundColor Green
    Log-Message "Total Devices to process: $i_TotalDevices."

    # Initialize CSV output
    $OutputData = @()

   # Process each device name
foreach ($SerialNumber in $a_DeviceNames) {
    # Get the device details
    $details = Get-MgDeviceManagementManagedDevice -Filter "serialnumber eq '$SerialNumber'" | Select-Object AzureAdDeviceId,DeviceName,UserDisplayName,UserPrincipalName,EmailAddress,EnrolledDateTime,LastSyncDateTime,Id,ManagementAgent,Model,OSVersion,SerialNumber
    
        if ($details) {
        foreach ($Device in $details) {
            $deviceId = $Device.Id
            try {
                # Send the wipe command
                Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$deviceId')/retire"
                $status = "Success"
                $message = "Retire command sent successfully."
            } catch {
                $errorMessage = $_.Exception.Message
                Log-Message "Failed to send remote Retire command to $SerialNumber. Error: $errorMessage"
                $status = "Failed"
                $message = $errorMessage
            }

            $Device | Add-Member -MemberType NoteProperty -Name Status -Value $status
            $Device | Add-Member -MemberType NoteProperty -Name Message -Value $message
            $OutputData += $Device
        }
    } else {
        # Log-Message "No details found in Intune for Device: $SerialNumber."
        $OutputData += [PSCustomObject]@{
            DeviceName        = $SerialNumber
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
            SerialNumber      = $SerialNumber
            Status            = "Not found"
            Message           = "Not available"
        }
    }
}

# Export the results to CSV
$OutputData | Export-Csv -Path $OutputCsv -NoTypeInformation

Write-Host "Script execution is completed. See file '$OutputCsv' for status." -ForegroundColor Green
Log-Message "Script execution completed. Results exported to '$OutputCsv'."
}
 else {
    Write-Host "Unable to proceed as not connected to Microsoft Graph." -ForegroundColor Red
    Log-Message "Unable to proceed as connection to Microsoft Graph failed."
}

# Log script end
Log-Message "Script execution ended."