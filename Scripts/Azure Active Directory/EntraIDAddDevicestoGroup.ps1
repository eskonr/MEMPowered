<#
Description: This script read the device's from the text file and adds to the Entra Group if found.
Author:Eswar Koneti (@eskonr)
Date:15-Jul-2022
Create txt file somedevices.txt and place it in the folder where the script resides..
#>

#define variables
#Get the script location
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$date = (Get-Date -f dd-MM-yyyy-hhmmss)
$Output = "$dir\ObjectIDinfo.csv"
$LogFile = "$dir\Add-devices-EntraGroup.log"


#Define functions

# Log Output to a File
function Write-Log {
	param (
		[string]$Message,
		[string]$LogFile = 'C:\Logs\ScriptLog.txt'
	)
	$timestamp = Get-Date -Format 'dd-MM-yyyy HH:mm:ss'
	Add-Content -Path $LogFile -Value "$timestamp > $Message"
}

# Create an Event Log Entry
function Write-EventLogEntry {
	param (
		[string]$Message,
		[string]$Source = 'CustomScript',
		[string]$LogName = 'Application',
		[string]$EntryType = 'Information'  # Options: Information, Warning, Error
	)

	if (-not [System.Diagnostics.EventLog]::SourceExists($Source)) {
		New-EventLog -LogName $LogName -Source $Source
	}
    
	Write-EventLog -LogName $LogName -Source $Source -EntryType $EntryType -EventId 1985 -Message $Message
}
# Read and Write to the Registry
function Set-RegistryValue {
	param (
		[string]$Path,
		[string]$Name,
		[string]$Value,
		[string]$Type = 'String'
	)
	if (-not (Test-Path -Path $Path)) {
		New-Item -Path $Path -Force | Out-Null
	}
	Set-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type
}

function Get-RegistryValue {
	param (
		[string]$Path,
		[string]$Name
	)
	try {
		return (Get-ItemProperty -Path $Path -Name $Name).$Name
	} catch {
		return $null
	}
}

#Check if a Process is Running

function Is-ProcessRunning {
	param (
		[string]$ProcessName
	)
	return Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $ProcessName }
}

#Restart a Service
function Restart-ServiceByName {
	param (
		[string]$ServiceName
	)
	try {
		Restart-Service -Name $ServiceName -Force -ErrorAction Stop
		Write-Host "Service '$ServiceName' restarted successfully."
	} catch {
		Write-Host "Failed to restart service '$ServiceName': $_"
	}
}

#remove if the output file (CSV) already exist with old content
if (Test-Path $Output -ErrorAction SilentlyContinue) {
	Remove-Item $Output -ErrorAction SilentlyContinue
}
#Check the Azure AD module
if (!(Get-Module -ListAvailable *AzureAD*)) {
	Write-Host 'Azure AD module not installed, installing now' -BackgroundColor Red
	Install-Module -Name AzureAD

	$Modules = Get-Module -ListAvailable *AzureAD*
	if ($Modules.count -eq 0) {
		Write-Host 'Unable to install the required modules, please install and run the script again' -BackgroundColor Red
		exit
	}
}
$azureADConnected = $false
if ( Get-AzureADTenantDetail -ErrorAction Stop) #if already connected
{	$azureADConnected = $true }

if (!$azureADConnected) {
	try {
		if (Connect-AzureAD -ErrorAction SilentlyContinue)
		{ $azureADConnected = $true }
	} catch {
		Write-Host 'Unable to connect to Azure AD.Please try again.' -ForegroundColor Red
		Write-Host -Message $_
		Read-Host -Prompt "When ready, press 'Enter' to exit..."
		exit
	}
}

if ($azureADConnected) {

	Write-Log -Message '' -LogFile $LogFile

	Write-Log -Message '***Execution started' -LogFile $LogFile
	
	Write-Host "To add devices to Entra group, enter either the name of the device or a filename (e.g. 'Somedevices.txt') in this script's folder containing multiple Azure AD devices: " -ForegroundColor Yellow
	$DeviceName = Read-Host
	#What was provided?
	if ($DeviceName.EndsWith('.txt', 'CurrentCultureIgnoreCase')) {

		if (!(Test-Path -Path "$Dir\$DeviceName")) {

			Write-Host ''
			Write-Host "The filename '$dir\$DeviceName' not found.Try again." -ForegroundColor Red
			Write-Host ''
			Read-Host -Prompt "When ready, press 'Enter' to exit..."
			exit
		} else {
			#File exists - get data into an array
			$a_DeviceNames = Get-Content "$Dir\$DeviceName"
			if ($a_DeviceNames.count -eq 0) {
				#No data in file
				Write-Host ''
				Write-Host "The given file name '$dir\$DeviceName' is empty. Try again." -ForegroundColor Red
				Write-Host ''
				#Wait for the user...
				Read-Host -Prompt "When ready, press 'Enter' to exit..."
				exit
			} elseif ($a_DeviceNames.count -eq 1) {
				#It's a single device
				#No need to pause
				$b_Pause = $false
			}
		}
	} else {
		#It's a single device
		$a_DeviceNames = @($DeviceName)

		#No need to pause
		$b_Pause = $false
	}
	Write-Host ''

	Clear-Host
	$i_TotalDevices = $a_DeviceNames.count
	Write-Host ''
	Write-Host "Total devices found : $i_TotalDevices . Press 'Enter' to process '$i_TotalDevices' devices, or type 'n' then press 'Enter' to exit the script: " -ForegroundColor Yellow -NoNewline
	$Scope = Read-Host
	if ($Scope -ieq 'n') {
		$b_ScopeAll = $false
	} else {
		$b_ScopeAll = $true
	}
	Write-Host ''

	#Continue to report the data for all device objects
	if ($b_ScopeAll) {
		Write-Host 'Recieved the confirmation to proceed, Script execution is in progress...' -ForegroundColor green

		Write-Host ''

		foreach ($DeviceName in $a_DeviceNames) {

			$cleanDeviceName = $DeviceName.Trim()

			Get-AzureADDevice -SearchString $cleanDeviceName | Select-Object DisplayName, ObjectID | Export-Csv $Output -Append -NoTypeInformation
		}

		#Add the devices to the AAD group.
		$groupName = Read-Host -Prompt 'Enter the Entra Group to add devices'

		if (!(Get-AzureADGroup -SearchString $groupName)) {
			Write-Host "Entra Group  '$Groupname' not found, exit script" -BackgroundColor Red
			Write-Host ''
			Write-Log -Message "Entra Group '$Groupname' not found " -LogFile $LogFile
			Write-Log -Message "*** Execution ended " -LogFile $LogFile
			Write-Log -Message '' -LogFile $LogFile
			exit
		}

		$groupObj = Get-AzureADGroup -SearchString $groupName
		# Check the number of groups found
		if ($groupObj.Count -gt 1) {
			# More than one group found, list their names
			$groupNames = $groupObj | ForEach-Object { $_.DisplayName }
			$groupNamesString = $groupNames -join ','
			Write-Log -Message "Multiple groups found starting with '$groupName': $groupNamesString" -LogFile $LogFile
		 Write-Log -Message '*** Execution ended ' -LogFile $LogFile
		Write-Log -Message '' -LogFile $LogFile
			exit
		} elseif ($groupObj.Count -eq 1) {
			$deviceList = Import-Csv -Path $Output
			if ( $($deviceList.DisplayName).count -eq 0) {
    Write-Host ''
				Write-Log -Message "No devices found in Entra with the input provided. Please check if the devicename's are correct" -LogFile $LogFile
				}

			else {
				Write-Log -Message "We have found $($deviceList.count) device objects in Entra to add to group '$groupName'" -LogFile $LogFile
     		$successCount = 0
				$failureCount = 0
				foreach ($dev in $deviceList) {
					$Computer = $dev.DisplayName
					$ObjID = $dev.ObjectId
					try {
						Add-AzureADGroupMember -ObjectId $groupObj.ObjectId -RefObjectId $ObjID
						$successCount++
					} catch {
						Write-Log -Message "Failed to add device $Computer to Entra group '$groupName'" -LogFile $LogFile
						$failureCount++
					}

				}
				Write-Log -Message "Summary" -LogFile $LogFile
				Write-Log -Message " Successfully added '$successCount' devices" -LogFile $LogFile
				Write-Log -Message " Failed to add '$failureCount' devices" -LogFile $LogFile
				}

		}

		Write-Host "Script execution is completed. See file `'$LogFile`' for details." -ForegroundColor Green

	} else {
		Write-Host '  User had cancelled the script due to revalidation of the input data  ' -ForegroundColor Red
		Write-Log -Message 'User had cancelled the script due to revalidation of the input data' -LogFile $LogFile
		Write-Log -Message '** Execution ended' -LogFile $LogFile
		Write-Log -Message '' -LogFile $LogFile
		exit
	}
	Write-Log -Message '** Execution ended' -LogFile $LogFile
	Write-Log -Message '' -LogFile $LogFile
	
}

