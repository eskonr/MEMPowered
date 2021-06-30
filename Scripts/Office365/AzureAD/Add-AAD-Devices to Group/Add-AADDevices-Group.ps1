<#
Title:Add Azure AD join devices to AD group as alternative approach. There is limitation adding devices to group using dynamic query in portal.
Author:Eswar Koneti
Date:17-Aug-2019
#>

#Read-Host -Prompt "Enter your tenant password" -AsSecureString | ConvertFrom-SecureString | Out-File "C:\Temp\eswar\Scripts\Automation\eswaro365.key"

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$date = (get-date -f dd-MM-yyyy-hhmmss)
$inputfile = "$dir\AADDevices.txt"
$Outfile = "$dir\o365licenseremoval-Direct-"+$date+".csv"
$TenantUname = "eswar@xxxxx.com"
$TenantPass = cat "C:\Temp\eswar\Scripts\Automation\eswaro365.key" | ConvertTo-SecureString
$TenantCredentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $TenantUname, $TenantPass

#connect to AzureAD module
Connect-AzureAD #-Credential $TenantCredentials

#get a list of all device members which already in group AzureADJoin:
#f9eaed44-f34a-4931-b8e0-a41f7f8454ba=All AAD Devices
$members=Get-AzureADGroupMember -ObjectId "f9eaed44-f34a-4931-b8e0-a41f7f8454ba" | Where-Object {$_.ObjectType -eq "Device"}

#get a list of all Azure AD joined devices:
$devices=Get-AzureADDevice -All $true | Where-Object {$_.DeviceTrustType -eq "AzureAd"}
if ($Devices)
{ 
      foreach ($device in $devices)
      {
        #Check if the device is already a member of group AzureADjoin.
        #if not, add it to the group
             if ($members.ObjectId -notcontains $device.ObjectId)
             {
            
                   Add-AzureADGroupMember -ObjectId "f9eaed44-f34a-4931-b8e0-a41f7f8454ba" -RefObjectId $device.ObjectId
             }
      }
} 
