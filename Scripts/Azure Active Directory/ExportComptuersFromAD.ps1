<#
Export the list of computer objetcs from specific OU to CSV file from Active directory.
Supply the OU CN name
#>
#define variables
$scriptpath = $script:MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$date = Get-Date -f dd-MM-yyyy-hhmmss
$Logfile="$dir\ExportedADComputers_$($date).csv"
# Get all computer objects from the specified OU
$computers = Get-ADComputer -Filter * -SearchBase -SearchBase 'OU=OU Name,DC=Domain,DC=com' -Property Name, Operatingsystem, OperatingSystemVersion, LastLogonTimeStamp, pwdLastSet, DistinguishedName -ErrorAction SilentlyContinue
# Create an array to store the output
$output = @()

# Loop through each computer object
foreach ($computer in $computers) {
	$computerName = $computer.Name
	$os = $computer.OperatingSystem
	$lastLogon1 = [datetime]::FromFileTime($computer.LastLogonTimestamp)
	$pwdLastSet1 = [datetime]::FromFileTime($computer.pwdLastSet)

	# Convert the DateTime to the "dd-mm-yyyy" format
	$lastLogon = $lastLogon1.ToString('dd-MM-yyyy')
	$pwdLastSet = $pwdLastSet1.ToString('dd-MM-yyyy')
	$ou = $computer.DistinguishedName -replace "^CN=$computerName,", ''

	# Create an object with the required properties
	$computerInfo = New-Object PSObject -Property @{
		Computername       = $computerName
		OS                 = $os
		Lastlogontimestamp = $lastLogon
		OU                 = $ou
		LastPwdSet         = $pwdLastSet
	}

	# Add the object to the output array
	$output += $computerInfo
}

# Export the output to a CSV file
$output | Select-Object Computername, OS, OU, Lastlogontimestamp, LastPwdSet | Export-Csv -Path $Logfile -NoTypeInformation