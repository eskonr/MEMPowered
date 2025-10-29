<#
Description:
This script is designed to connect to Azure Log analytics and fetch the newly enrolled devices  Hello compatible devices to the Windows hello policy.
The newly enrolled hello comptible devices are being checked against the the Entra ID group "Intune - Windows Computers - Windows Hello - Asia" if already added or not.
If not, it will add only the difference of the devices that helps user to setup windows hello configuration part of user authentication journey.
This script will exclude any devices with model 'Dell pro' as these devices by default support hello when purchased from Dell and part of the Entra ID dynamic group "Intune - Dynamically Added Windows Computers - Hello Hardware Supported"

This script has dependency on custom remediation script 'Windows Device Inventory Ver 3' to be targetted to physical devices to know the biometrics stauts for Hello.

This script requires Az.Accounts and Az.OperationalInsights and Microsoft.Graph powershell moduel to be installed prior to run the script.

Author: Eswar Koneti
Dated: 22-Sep-2025
#>

#define the variables
$scriptpath = $script:MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$s_LAWorkspaceID = 'your workspace ID' # Log Analytics Workspace ID
$s_SubscriptionID = 'Your subscription ID'
$s_TenantID = 'Your tenant ID'
$Timespan = (New-TimeSpan -Days 30)
$todayDate = Get-Date -Format 'dd-MM-yyyy'

# Define the log file path
$logFile = "$dir\IntuneAddBiometricsDevicestoHellogroup.log"

# Combine the base directory and today's date to form the full path
$folderPath = Join-Path -Path $dir -ChildPath $todayDate

# Check if the folder already exists
if (-not (Test-Path -Path $folderPath)) {
	# Create the folder if it doesn't exist
	New-Item -Path $folderPath -ItemType Directory
}

$NewlyenrolledDevices = "$folderPath\NewlyEnrolledBiometricDevices_$todayDate.csv"

# Log Output to a File
function Write-Log {
	param (
		[string]$Message,
		[string]$LogFile = 'C:\Logs\ScriptLog.txt'
	)
	$timestamp = Get-Date -Format 'dd-MM-yyyy HH:mm:ss'
	Add-Content -Path $LogFile -Value "$timestamp > $Message"
}

# Define the module names
$modulesToCheck = @('Az.Accounts', 'Az.OperationalInsights', 'Microsoft.Graph')

foreach ($moduleName in $modulesToCheck) {
	# Check if the module is installed
	if (-not (Get-Module -ListAvailable -Name $moduleName)) {
		Write-Host "Module '$moduleName' not found. Installing..."
		try {
			Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber
			#Write-Host "Module '$moduleName' installed successfully."
		} catch {
			Write-Error "Failed to install module '$moduleName'. Error: $_"
			exit
		}
	} else {
		# Write-Host "Module '$moduleName' is already installed." -ForegroundColor Green
	}

	# Check if the module is already loaded
	if (-not (Get-Module -Name $moduleName)) {
		# If not loaded, import the module
		try {
			#	Import-Module -Name $moduleName -Force
			# Write-Host "Module '$moduleName' imported successfully."
		} catch {
			Write-Error "Failed to import module '$moduleName'. Error: $_"
			exit
		}
	} else {
		# Write-Host "Module '$moduleName' is already loaded." -ForegroundColor Green
	}
}

#Begin

try {
	Connect-AzAccount –ServicePrincipal –Credential $o_ClientSecretCredential -Subscription $s_SubscriptionID –Tenant $s_TenantID
    #$credential = Get-Credential
	#Connect-AzAccount -Subscription $s_SubscriptionID –Tenant $s_TenantID -Credential $credential
	if (-not $?) {
		Write-Host "Failed to connect to Azure, When ready, press 'Enter' to exit..." -ForegroundColor Red
		exit
	}
	Write-Host 'Connected to Azure successfully.' -ForegroundColor Green
} catch {
	Write-Host "Failed to connect to Azure. Error: $_" -ForegroundColor Red
	exit
}

Write-Log -Message '' -LogFile $LogFile
Write-Log -Message '***Execution Started' -LogFile $logFile
#If here, download the data
Write-Host 'Downloading the newly provisioned Biometrics supported devices in the last 3 days...please wait' -ForegroundColor Green

# Define the query with single quotes to allow embedded double quotes

#Adjust the KQL query according to your requirements...do not run the query directly.
$query = @'
IntuneDevices | summarize arg_max(TimeGenerated,*) by SerialNumber
|where OS=="Windows" and not(DeviceName has_any("#")) and isnotempty(DeviceName) and ManagedBy != "MDE" and CompliantState !="ConfigManager" and DeviceName !startswith "MTR"
and Model !startswith "Surface Hub" and todatetime(CreatedDate) between  (ago(7d) .. now()) and not((DeviceName matches regex "^AZVD...M.*$"))
| extend Country=
            iff(DeviceName startswith "df","Cambodia",iff(DeviceName startswith "df","Taiwan",iff(DeviceName startswith "df","HongKong",iff(DeviceName startswith "df","Indonesia",
            iff(DeviceName startswith "hj","Singapore",    iff(DeviceName startswith "gh","Malaysia",iff(DeviceName startswith "df","Vietnam",iff(DeviceName startswith "JP","Japan",
            iff(DeviceName startswith "hjhj","China",iff(DeviceName startswith "hjhjj","Myanmar",iff(DeviceName startswith "hjh","Philippines",iff(DeviceName startswith "hjhjhj","Citrix",
            iff(DeviceName startswith "hjhj" or DeviceName startswith "hjhjhj","AVD",iff(DeviceName startswith "hjhj" or DeviceName startswith "hjhj","Europe",
            iff(DeviceName startswith "hjhj","United States",iff(DeviceName startswith "hjhj" or DeviceName startswith "hjhj","Canada","Unknown"))))))))))))))))
| extend Region1=
    iff(DeviceName startswith "hjhj" or DeviceName startswith "hjhjj" or DeviceName startswith "hjhj",
       iif(DeviceName startswith "ghgh","United States",iff(DeviceName startswith "ghghh" or DeviceName startswith "gghhgh", "Europe","Unknown")))
| extend Chassis = iff( (Model startswith "Virtual"), "Virtual", "Physical")
| extend LastCheckin=format_datetime(todatetime(LastContact), 'dd/M/yyyy')
| extend EnrollmentDate=format_datetime(todatetime(CreatedDate), 'dd/M/yyyy')
| extend lowerdevicename = tolower(DeviceName)
| where Region1 =="Asia" and Chassis =="Physical" and Model !contains "Dell Pro"
and Country !in~ ("China","Vietnam","HongKong","Philippines")
| join kind=leftouter  (DeviceInventory_CL | summarize arg_max(TimeGenerated,*) by ComputerName_s | extend lowercomputername = tolower(ComputerName_s))
on $left.lowerdevicename==$right.lowercomputername
| where WindowsHello_s =="Hello Supported"
|project TimeGenerated,DeviceName,PrimaryUser=UserEmail,Country,Region1,EnrollmentDate,LastCheckin,Model,SerialNumber,["Hello Compatible"]=WindowsHello_s
'@

# Execute the query
try {
	$Results = Invoke-AzOperationalInsightsQuery -WorkspaceId $s_LAWorkspaceID -Query $query -Timespan $Timespan

	if (!$Results) {
		Write-Host 'Failed to connect to Log Analytics, check the KQL syntax..' -ForegroundColor Red
		Write-Log -Message '*** Execution ended ' -LogFile $LogFile
		Write-Log -Message '' -LogFile $LogFile
		exit
	}

	# Create a new DataTable
	$DataTable = New-Object System.Data.DataTable

	# Check if there are results
	if (($Results.Results | Measure-Object).Count -gt 0) {
		$DataTable = $Results.Results
		$TotalDevices = ($Results.Results | Measure-Object).Count
		$DataTable | Export-Csv $NewlyenrolledDevices -NoTypeInformation -Force
		Write-Log -Message "Found '$TotalDevices' newly enrolled biometric devices. Please refer '$NewlyenrolledDevices' for complete list" -LogFile $logFile
write-host ""
		Write-Host "Found '$TotalDevices' newly enrolled biometric devices. Press 'Enter' to process '$TotalDevices' devices, or type 'n' then press 'Enter' to exit the script:" -ForegroundColor Yellow -NoNewline
		$Scope = Read-Host
		if ($Scope -ieq 'n') {
			$b_ScopeAll = $false
		} else {
			$b_ScopeAll = $true
		}
		Write-Host ''
		if ($b_ScopeAll) {
			Write-Host 'Recieved the confirmation to proceed, Please wait...' -ForegroundColor green

			Write-Host ''

			#Define the Entra ID Group to add newly found biometric devices
			$groupName = 'Intune - Windows Computers - Windows Hello - Asia'

			# Connect to Microsoft Graph
			Connect-MgGraph -Scopes 'Group.ReadWrite.All', 'Directory.Read.All' -NoWelcome

			# Get the group ID from the group name
			$group = Get-MgGroup -Filter "displayName eq '$groupName'" -ConsistencyLevel eventual

			if (-not $group) {
    Write-Host "Group '$groupName' not found." -ForegroundColor Red
    Write-Log -Message "Group '$groupName' not found" -LogFile $LogFile
    Write-Log -Message '*** Execution ended ' -LogFile $LogFile
				Write-Log -Message '' -LogFile $LogFile
				exit
			}

			$groupId = $group.Id

# Retrieve all transitive device members of the group

$existingDevices = Get-MgGroupTransitiveMember -GroupId $group.id -All | Select-Object @{Name='Id'; Expression={$_.additionalProperties['deviceId']}},@{Name='DisplayName'; Expression={$_.additionalProperties['displayName']}}

# Read the CSV file
$devices = Import-Csv -Path $NewlyenrolledDevices

# Prepare arrays for comparison
$existingDeviceNames = $existingDevices | Select-Object -ExpandProperty DisplayName
$csvDeviceNames = $devices | Select-Object -ExpandProperty DeviceName

# Find devices that are in the CSV but not in the existing group members
$devicesToAdd = Compare-Object -ReferenceObject $existingDeviceNames -DifferenceObject $csvDeviceNames -PassThru | Where-Object { $_.SideIndicator -eq "=>" }

If ($devicesToAdd)
{


			# Read the CSV file
#			$devices = Import-Csv -Path $NewlyenrolledDevices

			foreach ($device in $devicesToAdd) {
    try {
					$deviceName = $device.DeviceName

					# Find the device in Azure AD
					$deviceObject = Get-MgDevice -Filter "displayName eq '$deviceName'" -ConsistencyLevel eventual

					if (-not $deviceObject) {
						Write-Log -Message "Device '$deviceName' not found in Entra ID." -LogFile $LogFile
						continue
					}

					$deviceId = $deviceObject.Id

					# Add the device to the group
						Add-MgGroupMember -GroupId $groupId -DirectoryObjectId $deviceId
						Write-Log -Message "Device '$deviceName' added to the group" -LogFile $LogFile

    } catch {
					Write-Log Message "Failed to process device '$deviceName'. Error: $_" -LogFile $LogFile

    }
			}
}
else

{
        Write-Log -Message 'The newly found Biometrics devices are already member of the Entra ID group, all Good' -LogFile $LogFile
        write-host 'The newly found Biometrics devices are already member of the Entra ID group, all Good'
		Write-Log -Message '*** Execution ended ' -LogFile $LogFile
		Write-Log -Message '' -LogFile $LogFile
		exit
}
			#Write-Host "Completed. See file at '$NewlyenrolledDevices'." -ForegroundColor Yellow
		}

		else {
			Write-Host 'User had cancelled the script due to revalidation of the Biometric Supported Devices' -ForegroundColor Red
			Write-Log -Message 'User had cancelled the script due to revalidation of the Biometric Supported Devices' -LogFile $LogFile
			Write-Log -Message '** Execution ended' -LogFile $LogFile
			Write-Log -Message '' -LogFile $LogFile
			exit
		} else {
			Write-Host 'No results found with input KQL query' -ForegroundColor Yellow
			Write-Log -Message 'No Biometric devices enrolled' -LogFile $LogFile
			Write-Log -Message '*** Execution ended ' -LogFile $LogFile
			Write-Log -Message '' -LogFile $LogFile
			exit
		}
	}
}catch {
		Write-Host "Failed to connect to Azure Log analytics. Error: $_" -ForegroundColor Red
		Write-Log -Message 'Failed to connect to Log analytics' -LogFile $LogFile
		Write-Log -Message '*** Execution ended ' -LogFile $LogFile
		Write-Log -Message '' -LogFile $LogFile
		exit
	}

	#The End
	Write-Host ''
	Write-Host 'Completed.' -ForegroundColor Yellow
	Write-Host ''

	#Disconnect from Azure Account
	Disconnect-AzAccount | Out-Null

	#Disconnect from Graph
	Disconnect-MgGraph | Out-Null

	#Wait for the user if manual run...
	Read-Host -Prompt "When ready, press 'Enter' to exit..."
	Exit-Script -Now -Success
