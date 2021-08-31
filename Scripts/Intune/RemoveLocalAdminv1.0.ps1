<#
Script: remove logged in user (if exist) from local admin group
Description: This script will perform a verification if the logged in user is member of local
administrators group or not. If part of local admin group, the user will be removed from it.
Deployment:When you deploy the script using intune, powershell scripts, make sure you target this to user group.
So every user who login to the device, will be removed from the local admin group incase added
This script is valid only for Azure AD joined devices.
You need to edit the $domain variable as per your domain, if user email id is eswar@eskonr.com then domain is eskonr.com
if it ends with onmicrosoft.com, you need to supply this.
Date:31-Aug-2021
Author: Eswar Koneti @eskonr
Website: https://www.eskonr.com/
#>
$dir="C:\ProgramData\IntuneLogs"
$domain="eskonr.com"
if(!(test-path $dir)) {new-item -ItemType Directory -Force -path $dir}
$device=$env:COMPUTERNAME
$date=Get-date -Format dd-MM-yyyy-hhmmss
"*********************** Removing user from local admin Script started at $date ******************"| Out-File "$dir\Localadmin.log" -Append
"Checking if any user loggedin currently on this PC:$device" | Out-File "$dir\Localadmin.log" -Append
	$ExplorerProcess = Get-WmiObject -class win32_process -computername $device  | where name -Match explorer
	if($ExplorerProcess -eq $null) {
     "No current user" | Out-File "$dir\Localadmin.log" -Append
	}
	elseif($ExplorerProcess.getowner().user.count -gt 1){
	    $LoggedOnUser = $ExplorerProcess.getowner().user[0]
	}
	else{
    	$LoggedOnUser = $ExplorerProcess.getowner().user
    "Found a user '$LoggedOnUser' logged in currently, proceed to check further"| Out-File "$dir\Localadmin.log" -Append
	}
if ($LoggedOnUser)
{
"Checking if '$LoggedOnUser' already member of local admin group or not" | Out-File "$dir\Localadmin.log" -Append
#$user = "$env:COMPUTERNAME\$env:USERNAME"
$user = "azuread\$LoggedOnUser"
$group = "Administrators"
$isInGroup = (net localgroup administrators) -contains $user
#(Get-LocalGroupMember $group).Name -contains $user
if ($isInGroup)
{
"User '$LoggedOnUser' is member of local administrators group, removing the user" | Out-File "$dir\Localadmin.log" -Append
$adduser=$user+$domain
try
{
Remove-LocalGroupMember -Group "Administrators" -Member $adduser -ErrorAction Stop
if (!((net localgroup administrators) -contains $user) )
{
"'$LoggedOnUser' removed succesfully from local administrator group" | Out-File "$dir\Localadmin.log" -Append
}
}
catch [system.exception]
{
"Failed to add $LoggedOnUser to local administrator group" | Out-File "$dir\Localadmin.log" -Append
#$errormsg=$error[1] | Select-Object * | Format-List -Force
"An error occured.The error is $error[1].Exception " | Out-File "$dir\Localadmin.log" -Append
}
}
else
{
" User '$LoggedOnUser' not member of local administrators group,exit" | Out-File "$dir\Localadmin.log" -Append
}
}
$date1=Get-date -Format dd-MM-yyyy-hhmmss
"*********************** Removing user from local admin script ended at $date1 ******************"| Out-File "$dir\Localadmin.log" -Append




