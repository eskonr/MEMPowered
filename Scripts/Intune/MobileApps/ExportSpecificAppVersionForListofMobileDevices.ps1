# Define script location and execution date
$scriptPath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptPath
$date = (Get-Date -Format 'ddMMyyyy-HHmmss')
$application = "Comp Portal"

# Output file for storing the Azure AD device info and logging
$outputCsv = "$dir\FilteredDevicesWithApp_$date.csv"

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

# Function to get a specific app for a list of device IDs
function Get-SpecificAppForDevices {
    param (
        [string[]]$deviceIds
    )

    $results = @()
    
    foreach ($deviceId in $deviceIds) {
        try {
          #  Write-Host "Retrieving detected apps for device ID $deviceId..." -ForegroundColor Cyan
            $detectedApps = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$deviceId')/detectedApps"

            $compPortalApp = $detectedApps.value | Where-Object { $_.displayName -eq $application }
            
            if ($compPortalApp) {
                # Fetch device information
                $device = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $deviceId

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
                    AppDisplayName = $compPortalApp.displayName
                    AppVersion = $compPortalApp.version
                }
            } else {
                Write-Host "No '$application' found for device ID $deviceId." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "Failed to retrieve data for device ID $deviceId." -ForegroundColor Red
        }
    }

    return $results
}

# Main script execution
Ensure-GraphModule
if(Authenticate-Graph)
{
# Read device IDs from a file

Write-Host "   Type the txt file name located in the script folder (e.g somedevices.txt) contain deviceID's and then press Enter: " -ForegroundColor Yellow
  $DeviceName = Read-Host
  #Read-Host
  #What was provided?
  if ($DeviceName.EndsWith(".txt", "CurrentCultureIgnoreCase")) {
    #It's a file
    #Confirm the file exists
    if (!(Test-Path -Path "$Dir\$DeviceName")) {
      #File does not exist
      Write-Host ""
      Write-Host "Input filename of devices cannot be found.  Try again." -ForegroundColor Red
      Write-Host ""
      #Wait for the user...
      Read-Host -Prompt "When ready, press 'Enter' to exit..."
      exit
    }
    else {
      #File exists - get data into an array
      $a_DeviceNames = Get-Content -Path "$Dir\$DeviceName"
      if ($a_DeviceNames.count -eq 0) {
        #No data in file
        Write-Host ""
        Write-Host "Input filename of devices is empty.  Try again." -ForegroundColor Red
        Write-Host ""
        #Wait for the user...
        Read-Host -Prompt "When ready, press 'Enter' to exit..."
        exit
      }
      elseif ($a_DeviceNames.count -ge 1) {
        # Device list exist in txt format , continue
        $b_Pause = $false
      }
    }
  }
  else {
Write-Host "Input filename is not correct. Please check the filename extension and try again." -ForegroundColor Red
        Write-Host ""
        #Wait for the user...
        Read-Host -Prompt "When ready, press 'Enter' to exit..."
        exit
        }
  Write-Host ""
  Write-Host "Data validation is in progress ..." -ForegroundColor Green
  $i_TotalDevices = ($a_DeviceNames.count)
  Write-Host ""
  Write-Host "Total devices found : $i_TotalDevices. Press 'Enter' to process the devices or type 'n' then press 'Enter' to exit the script: " -ForegroundColor Yellow -NoNewline
  $Scope = Read-Host
  Write-Host "Input file is recieved, Script execution is in progress..." -ForegroundColor green

  if ($Scope -ieq "n") {
    $b_ScopeAll = $false
  }
  else {
    $b_ScopeAll = $true
  }
  Write-Host ""

  #Continue to report the data for all device objects
  if ($b_ScopeAll) {

$results = Get-SpecificAppForDevices -deviceIds $a_DeviceNames

# Export results to CSV if data exists
if ($results) {
    $results | Export-Csv -Path $outputCsv -NoTypeInformation
    Write-Host "Exported filtered app data to $outputCsv" -ForegroundColor Green
} else {
    Write-Host "No app data to export." -ForegroundColor Yellow
}
}
  else {
    Write-Host "User has stopped the script execution due to revalide the input file." -ForegroundColor Red
    exit
  }
}