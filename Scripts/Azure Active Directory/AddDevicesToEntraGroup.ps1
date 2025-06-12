<#
Description: This script read the device's from the text file and adds to the Entra Group if found.
Author:Eswar Koneti (@eskonr)
Date:15-Jul-2022
Create txt file somedevices.txt and place it in the folder where the script resides..
#>

#Get the script location
$scriptpath = $MyInvocation.MyCommand.Path
$directory = Split-Path $scriptpath
$dir = Split-Path $scriptpath
$date = (Get-Date -f dd-MM-yyyy-hhmmss)
$Output = "$directory\ObjectIDinfo.csv"
$log = "$directory\Add-devices-EntraGroup.log"
#remove if the output file already exist with old content
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
		if (Connect-AzureAD -ErrorAction Stop | Out-Null)
		{ $azureADConnected = $true }
	} catch {
		Write-Host 'Unable to connect to Azure AD.Please try again.' -ForegroundColor Red
		Write-Host -Message $_
		Read-Host -Prompt "When ready, press 'Enter' to exit..."
		exit
	}
}

if ($azureADConnected) {

	Write-Host "Script execution is completed.See file `'$log`' for failed status." -ForegroundColor Green

"----------------- script started at $date---------------------" | Out-File $log -Append
  
	Write-Host "To add devices to Entra group, enter either the name of the device or a filename (e.g. 'Somedevices.txt') in this script's folder containing multiple Azure AD devices: " -ForegroundColor Yellow
	$DeviceName = Read-Host
	#What was provided?
	if ($DeviceName.EndsWith('.txt', 'CurrentCultureIgnoreCase')) {
				
		if (!(Test-Path -Path "$Dir\$DeviceName")) {
			
			Write-Host ''
			Write-Host "The filename '$directory\$DeviceName' not found.Try again." -ForegroundColor Red
			Write-Host ''
		    Read-Host -Prompt "When ready, press 'Enter' to exit..."
			exit
		} else {
			#File exists - get data into an array
			$a_DeviceNames = Get-Content "$Dir\$DeviceName"
			if ($a_DeviceNames.count -eq 0) {
				#No data in file
				Write-Host ''
				Write-Host "The given file name '$directory\$DeviceName' is empty. Try again." -ForegroundColor Red
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
	}
 else {
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
           "Entra Group  '$Groupname' not found" | Out-File $log -Append
        $date2 = (Get-Date -f dd-MM-yyyy-hhmmss)
        "----------------- script ended at $date2---------------------" | Out-File $log -Append
			exit
		}

		$groupObj = Get-AzureADGroup -SearchString $groupName
			# Check the number of groups found
			if ($groupObj.Count -gt 1) {
    # More than one group found, list their names
    $groupNames = $groupObj | ForEach-Object { $_.DisplayName }
    $groupNamesString = $groupNames -join ','
    "Multiple groups found starting with '$groupName': $groupNamesString" | Out-File $log -Append
    Write-Output "Script stopped because multiple groups were found. Grounames $groupNamesString"

        $date2 = (Get-Date -f dd-MM-yyyy-hhmmss)
        "----------------- script ended at $date2---------------------" | Out-File $log -Append
			exit

    exit
			}
 elseif ($groupObj.Count -eq 1) {
    $deviceList = Import-Csv -Path $Output
    if ( $($deviceList.DisplayName).count -eq 0)
    {
    Write-Host ''
     "No devices found in Entra with the input provided. Please check if the devicename's are correct" | Out-File $log -Append 
     write-host "No devices found in Entra with the input provided. Please check if the devicename's are correct"
     }

else
{
    "We have found $($deviceList.DisplayName).count device objects in Entra to add to '$groupName'" | Out-File $log -Append
				$successCount = 0
				$failureCount = 0


				foreach ($dev in $deviceList) {
					$Computer = $dev.DisplayName
					$ObjID = $dev.ObjectId
					try {
						Add-AzureADGroupMember -ObjectId $groupObj.ObjectId -RefObjectId $ObjID
						$successCount++
					} catch {
						"Failed to add device $Computer to the group '$groupName'" | Out-File $log -Append
						$failureCount++
					}
				"Successfully added '$successCount' devices." | Out-File $log -Append
				"Failed to add '$failureCount' devices." | Out-File $log -Append
                Write-host "Successfully added '$successCount' devices."
                Write-host "Failed to add '$failureCount' devices."
				}

			}

}

    Write-Host "Script execution is completed. See file `'$log`' for details." -ForegroundColor Green
    
    		}
else
{
Write-Host "  User had cancelled the script due to revalidation of the input data  " -ForegroundColor Red
"User had cancelled the script due to revalidation of the input data" | Out-File $log -Append
exit
	}
$date2 = (Get-Date -f dd-MM-yyyy-hhmmss)
"----------------- script ended at $date2---------------------" | Out-File $log -Append
}

