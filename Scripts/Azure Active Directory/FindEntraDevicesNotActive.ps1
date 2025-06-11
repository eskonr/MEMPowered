<#
.SYNOPSIS
The script is will connect to Microsoft Graph to fetch the devices based on the criteria used in the script below.
The script requires the following scoped permissions and also the module "Microsoft.Graph.
Scopes:
Device.Read.All

Author: Eswar Koneti
Date: 04-Jun-2025
#>

# Get the script location and execution date
$scriptpath = $MyInvocation.MyCommand.Path
$directory = Split-Path $scriptpath
$date = (Get-Date -Format 'ddMMyyyy-HHmmss')

# Output file for storing the Azure AD device info and logging
$OutputCsv = "$directory\FindEntraDevicesNotActive_$date.csv"

# Check if the Microsoft Graph module is installed, if not, install it
$moduleName = 'Microsoft.Graph'
if (-not (Get-Module -ListAvailable -Name $moduleName)) {
	Write-Host 'Microsoft Graph module not found. Installing...' -ForegroundColor Yellow
	try
	{
	Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber
		# Import the module
		Import-Module $moduleName
	}
	catch {
		Write-Host "Failed to install 'Microsoft Graph' module. Install Manually." -ForegroundColor Red
		Exit 1
	}
}

# Connect to Microsoft Graph
Write-Host 'Connecting to Microsoft Graph...' -ForegroundColor Yellow
Connect-MgGraph -Scopes 'Device.Read.All'

# Define the threshold date for ApproximateLastSignInDateTime (Entra ID)
$thresholdDate = (Get-Date).AddMonths(-3)

# Known server version numbers to exclude from the report
<#The Server OS that are not managed by Defender (MDE), they appear as Windows for Operating system in Entra ID.
This windows OS is same for workstations and servers hence it is required to exclude server OS based on its version.
This will help us to exclude server OS versions from the list and focus primarily on windows workstations.
Considering the servers are only hybrid joined support (sync from AD), 'OnPremisesSyncEnabled' criteria is used to exclude devices that are syncing from on-prem.
#>

$serverVersionPrefixes = @(
	'10.0.14393', # Windows Server 2016
	'10.0.17763', # Windows Server 2019
	'10.0.20348'  # Windows Server 2022
	# Update this list as new server versions are released
)

# Create a regex pattern for server versions
$serverVersionRegex = '^(' + ($serverVersionPrefixes -join '|') + ')'

Write-Host "Server Version Regex: $serverVersionRegex" -ForegroundColor Yellow

# Fetch all devices
$devices = Get-MgDevice -All

# Filter devices based on specified criteria
$filteredDevices = $devices | Where-Object {
	$_.OperatingSystem -eq 'Windows' -and #Include Windows devices only
	$_OperatingSystemVersion -notmatch $serverVersionRegex -and #Exclude Known Server OS versions
    ($_.OperatingSystemVersion -like '10.0.1*' -or $_.OperatingSystemVersion -like '10.0.2*') -and #Include Windows 10 or windows 11
	$_.ApproximateLastSignInDateTime -lt $thresholdDate -and #Include last logon timestamp is within 90 days
    ([string]::IsNullOrEmpty($_.EnrollmentProfileName)) -and #Autoprofile is not assgined
    ([string]::IsNullOrEmpty($_.OnPremisesSyncEnabled)) -and #Device is not synced fron AD
    ([string]::IsNullOrEmpty($_.ManagementType)) -and # Management type such as MDE or MDM or SCCM is blank
		$_.TrustType -ne "ServerAd" #device is not hybrid, only BYOD/workplace join or Entra joined/registered.
}

# Select the desired properties for export
$exportDevices = $filteredDevices | Select-Object DisplayName, OperatingSystem, OperatingSystemVersion, ApproximateLastSignInDateTime, Id, ManagementType, TrustType

# Export to CSV
$exportDevices | Export-Csv -Path $OutputCsv -NoTypeInformation
Write-Host "Script execution is completed. See file '$OutputCsv' for status." -ForegroundColor Green
