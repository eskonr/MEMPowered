<#
.Synopsis
   Get the status for list of devices from Microsoft Intune using Graph.
.DESCRIPTION
    For a given Intune device names (or file name of device names) connects to Mg Graph and Azure AD and:
        - Validates that each device is in Azure AD and is Windows based (else skip)
        - Finds the information of the device such as user name, OS and last intune contact date.
 
      .Requires installation of Powershell modules Microsoft.Graph.Devicemanagement (handled by this script)
      . Reqires the user to have access to Microsoft Graph powershell application with DeviceManagementConfiguration.Read.All and DeviceManagementManagedDevices.Read.All scoped permissions.
 
      Author: Eswar Koneti
      Dated: 26-Oct-2023
      -Running the script will ask for a device or list of devices from txt file.
      - Script will create folder with current date and create csv file for the list of devices with output.
#>
 
#Define variables
#Get the current script directory
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
#Get the script execution date                  
$date = (Get-Date -f ddMMyyyy_hhmmss)
$ScriptLaunchTime = Get-Date
$Year = [string]($ScriptLaunchTime.Year)
$Month = [string]($o_ScriptLaunchTime.Month)
if ($Month.Length -eq 1) { $Month = "0$Month" }
$Day = [string]($ScriptLaunchTime.Day)
if ($Day.Length -eq 1) { $Day = "0$Day" }
 
#Dont modify anything below this section unless you know what you are doing.
 
#######################################################################
 
 
function ConnectToGraph
{
  if (Get-Module -ListAvailable -Name Microsoft.Graph.Devicemanagement)
  {
  }
  else {
    Write-Host "Microsoft.Graph.Devicemanagement  Module does not exist, installing..."
    Install-Module Microsoft.Graph -Scope CurrentUser
  }
 
  Connect-MgGraph -Scopes "DeviceManagementConfiguration.Read.All","DeviceManagementManagedDevices.Read.All"
 
}
 
#######################################################################
 
 
if (!(Get-MgContext)) {
try
{
ConnectToGraph
}
catch
{
  Write-Host ""
  Write-Host "Unable to make connection to MG Graph, please try again.." -ForegroundColor Red
  exit
}
}
 
###############################
  Write-Host "To search Intune for assigned objects, enter either the full name of an Intune device or a filename (e.g. 'Somedevices.txt') in this script's folder containing multiple Intune devices: " -ForegroundColor Yellow
  $DeviceName = Read-Host
  #What was provided?
  if ($DeviceName.EndsWith(".txt","CurrentCultureIgnoreCase"))
  {
    #It's a file
    #Confirm the file exists
    if (!(Test-Path -Path "$Dir\$DeviceName"))
    {
      #File does not exist
      Write-Host ""
      Write-Host "Provided filename of devices cannot be found.  Try again." -ForegroundColor Red
      Write-Host ""
      #Wait for the user...
      Read-Host -Prompt "When ready, press 'Enter' to exit..."
      exit
    }
    else
    {
      #File exists - get data into an array
      $a_DeviceNames = Get-Content "$Dir\$DeviceName"
      if ($a_DeviceNames.count -eq 0)
      {
        #No data in file
        Write-Host ""
        Write-Host "Provided filename of devices is empty.  Try again." -ForegroundColor Red
        Write-Host ""
        #Wait for the user...
        Read-Host -Prompt "When ready, press 'Enter' to exit..."
        exit
      }
      elseif ($a_DeviceNames.count -eq 1)
      {
        #It's a single device
        #No need to pause
        $b_Pause = $false
      }
    }
  }
  else
  {
    #It's a single device
    $a_DeviceNames = @($DeviceName)
 
    #No need to pause
    $b_Pause = $false
  }
  Write-Host ""
 
  #Ensure output folder is created
  $Folder = "$Dir\" + "$Year$Month$Day"
  if (!(Test-Path -Path $Folder))
  {
    #Folder does not exist
    New-Item $Folder -Type directory
  }
 
  Clear-Host
  Write-Host "Data validation is in progress ..." -ForegroundColor Green
  $i_TotalDevices = $a_DeviceNames.count
  Write-Host ""
  Write-Host "Total devices found : $i_TotalDevices . Press 'Enter' to report on all objects, or type 'n' then press 'Enter' exit the script: " -ForegroundColor Yellow -NoNewline
  $Scope = Read-Host
  if ($Scope -ieq "n")
  {
    $ScopeAll = $false
  }
  else
  {
    $ScopeAll = $true
  }
  Write-Host ""
 
  #Continue to report the data for all device objects
  if ($ScopeAll)
  {
    # Create an array to store the results
    $results = @()
    # Loop through each device
 
    foreach ($DeviceName in $a_DeviceNames)
    {
      #Clear-Host
 
    $deviceInfo = Get-MgDeviceManagementManagedDevice -Filter "devicename eq '$deviceName'" | Select-Object DeviceName, AzureAdDeviceId, AzureAdRegistered, ComplianceState, DeviceEnrollmentType, EmailAddress,UserPrincipalName, EnrolledDateTime, LastSyncDateTime, Manufacturer, Model, OSVersion, OperatingSystem, SerialNumber,TotalStorageSpaceInBytes,FreeStorageSpaceInBytes
      if ($deviceInfo)
      {
    $results += $deviceInfo
    } else {
    #if device is not found in intune
        $notFoundDevice = [PSCustomObject]@{
            AzureAdDeviceId = "Not Found"
            AzureAdRegistered = "Not Found"
            ComplianceState = "Not Found"
            DeviceEnrollmentType = "Not Found"
            DeviceName = $deviceName
            EmailAddress = "Not Found"
            EnrolledDateTime = "Not Found"
            LastSyncDateTime = "Not Found"
            Manufacturer = "Not Found"
            Model = "Not Found"
            OSVersion = "Not Found"
            OperatingSystem = "Not Found"
            SerialNumber = "Not Found"
            UserPrincipalName = "Not Found"
        }
        $results += $notFoundDevice
    }
}
# Export the results to a CSV file
$results | Export-Csv -Path "$Folder\IntuneDevicedata_$($date).csv" -NoTypeInformation
}
else
  {
  #User has stopped the script due to revalidation of the input
    Write-Host "User has stopped the script due to revalidation of the input objects.." -ForegroundColor Red
    exit
  }
write-host "Execution of the script is completed. For output, please check '$Folder' " -ForegroundColor Green