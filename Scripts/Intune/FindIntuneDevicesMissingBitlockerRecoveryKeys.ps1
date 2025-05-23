<#
.SYNOPSIS
    This script identifies Intune-managed Windows devices missing BitLocker keys.

.DESCRIPTION
    The script connects to Microsoft Graph to retrieve data on managed devices and BitLocker recovery keys. 
    It filters out devices that are virtual or managed by non-Intune methods and then checks for devices that 
    do not have associated BitLocker recovery keys. The results are exported to a CSV file for further analysis.

    The script requires the installation of the Microsoft.Graph and Microsoft.Graph.DeviceManagement modules.
    It connects to Microsoft Graph using the necessary scopes to retrieve and manage device information.

.PARAMETER None
    This script does not take any parameters. It will automatically determine the output path based on the script's location.

.EXAMPLE
    .\FindDevicesMissingBitLockerKeys.ps1
    This command runs the script and outputs the results to a CSV file in the same directory as the script.

.NOTES
    Author: Eswar Koneti
    Date: 25-May-2025
    Requires: Microsoft.Graph, Microsoft.Graph.DeviceManagement PowerShell modules

#>

# Get the script location and execution date
$scriptpath = $MyInvocation.MyCommand.Path
$directory = Split-Path $scriptpath
$date = (Get-Date -Format "ddMMyyyy-HHmmss")

# Output file for storing the Azure AD device info and logging
$OutputCsv =Join-Path -Path $directory -ChildPath "IntuneDevicesMissingBitlockerkeys_$date.csv"

# Define the module names
$modulesToCheck = @('Microsoft.Graph.DeviceManagement')
foreach ($moduleName in $modulesToCheck) {
    # Check if the module is installed
    if (-not (Get-Module -ListAvailable -Name $moduleName)) {
       Write-host "Module '$moduleName' not found. Installing..." -ForegroundColor yellow
        try {
            Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber
        } catch {
            Write-host "Failed to install module '$moduleName'. Error: $_" -ForegroundColor red
            exit
        }
    }

    # Import the required modules
    try {
        Import-Module -Name $moduleName -Force
    } catch {
        Write-host "Failed to import module '$moduleName'. Error: $_" -ForegroundColor red
        exit
    }
}

$GraphConnected = $false

try {
    $tenant = Get-MgContext -ErrorAction Stop
    $GraphConnected = $true
} catch {
    Write-host "Unable to retrieve Microsoft Graph details." -ForegroundColor red
}

if (!$GraphConnected) {
    try {
        Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All","BitLockerKey.Read.All" -NoWelcome -ErrorAction Stop
        $GraphConnected = $true
    } catch {
       write-host "Unable to connect to Microsoft Graph. Please investigate." -ForegroundColor Red
       Exit
    }
}
if ($GraphConnected) 
{

   Write-Host "Retrieving the BitLocker information." -ForegroundColor Green

    # Attempt to retrieve BitLocker recovery keys
    try {
        $allRecoveryKeys = Get-MgInformationProtectionBitlockerRecoveryKey -All -ErrorAction Stop
    } catch {
        Write-Host "Error retrieving BitLocker recovery keys: $_" -ForegroundColor Red
        exit
    }

    # Check if recovery keys were retrieved
    if ($null -eq $allRecoveryKeys -or $allRecoveryKeys.Count -eq 0) {
        Write-Host "No BitLocker recovery keys found." -ForegroundColor Yellow
        exit
    }

# Group by DeviceId and select the latest record for each device. If a device has multiple bitlocker keys, the latest will be retrived only.
$latestRecoveryKeys = $allRecoveryKeys |
    Group-Object -Property DeviceId |
    ForEach-Object {
        $_.Group | Sort-Object -Property CreatedDateTime -Descending | Select-Object -First 1
    }


Write-Host "Retriving Intune device data for physical devices ." -ForegroundColor Green
# define days for last sync with intune
$Daysolder = (Get-Date).AddDays(-30)
$Intunedevices=Get-MgDeviceManagementManagedDevice -All

#Filter the intune data by omitting virtual devices and MDE managed devices. That means it picks only windows with intune or co-managed devices.
$FilteredIntunedevices=$Intunedevices | Where-Object {
    ($_.LastSyncDateTime -ge $Daysolder) -and
    ($_.ManagementAgent -eq 'MDM' -or $_.ManagementAgent -eq 'configurationManagerClientMdm') -and ($_.OperatingSystem -eq 'Windows') -and ($_.Model -notlike '*Virtual*' ) -and ($_.Model -notlike '*Vmware*' )
    }

$latestRecoveryKeyDeviceIds = [System.Collections.Generic.HashSet[string]]::new()
$latestRecoveryKeys | ForEach-Object { $null = $latestRecoveryKeyDeviceIds.Add($_.DeviceId) }

# Find devices in intune that don't have a bitlocker recovery keys/missing
$devicesWithoutKeys = $FilteredIntunedevices | Where-Object {
    -not $latestRecoveryKeyDeviceIds.Contains($_.AzureAdDeviceId)
}

if ($devicesWithoutKeys.Count -gt 1) {
Write-Host "Total devices found In Intune without Bitlocker keys:$($devicesWithoutKeys.count)." -ForegroundColor Yellow
# Output detailed information about devices without BitLocker keys for investigation purpose
$devicesWithoutKeys | Select-Object AzureAdDeviceId,DeviceName,UserPrincipalName,EmailAddress,EnrolledDateTime,LastSyncDateTime,Id,ManagementAgent,Model,OSVersion,SerialNumber | Export-Csv -Path $OutputCsv -NoTypeInformation
 Write-Host "Script execution is completed. See file '$OutputCsv' for status." -ForegroundColor Green
}
else
{
Write-Host "No devices found that are missing bitlocker keys, YOU ARE GOOD TO GO." -ForegroundColor Green
}

 } else {
    Write-Host "Failed to connect to Microsoft Graph.." -ForegroundColor Red
    }