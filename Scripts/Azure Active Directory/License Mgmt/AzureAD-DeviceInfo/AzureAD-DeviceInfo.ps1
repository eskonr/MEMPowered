<#
Title:Get list of All windows devices registerd in Azure AD
Author:Eswar Koneti
Date:26-Aug-2018
#>

#Read-Host -Prompt "Enter your tenant password" -AsSecureString | ConvertFrom-SecureString | Out-File "C:\Temp\eswar\Scripts\Automation\eswaro365.key"

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$date = (get-date -f dd-MM-yyyy-hhmmss)
$Outfile = "$dir\AzureADDevices-"+$date+".csv"
    $TenantUname = "keswar@eswar.com"
    $TenantPass = cat "C:\Temp\eswar\Scripts\Automation\eswaro365.key" | ConvertTo-SecureString
    $TenantCredentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $TenantUname, $TenantPass

Connect-MsolService -Credential $TenantCredentials


$Devices = Get-MsolDevice -All -ReturnRegisteredOwners -IncludeSystemManagedDevices
#(Get-MsolDevice -All -ReturnRegisteredOwners -IncludeSystemManagedDevices).count
$DeviceInfo = @()

foreach ($Device in $Devices) {
    $DeviceInfo += [PSCustomObject]@{
        "DisplayName" = $Device.DisplayName
        "DeviceTrustType" = $Device.DeviceTrustType
        "DeviceTrustLevel" = $Device.DeviceTrustLevel
        "DeviceOS" = $Device.DeviceOsType
        "DeviceVersion" = $Device.DeviceOsVersion
        "RegisteredOwner" = $($Device.RegisteredOwners)
        "LastLogon" = $Device.ApproximateLastLogonTimestamp
        "LastDirSync" = $Device.LastDirSyncTime
        "DeviceID" = $Device.DeviceId
        "ObjectID" = $Device.ObjectId
    }
}
$DeviceInfo | Export-Csv $Outfile