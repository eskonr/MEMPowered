
<#
Title:Get list of All Azure AD devices (registered and hybrid azure AD join and enrolled)
Author:Eswar Koneti
Date:26-Aug-2018
#>

#Read-Host -Prompt "Enter your tenant password" -AsSecureString | ConvertFrom-SecureString | Out-File "C:\Temp\eswar\Scripts\Automation\o365.key"

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$date = (get-date -f dd-MM-yyyy-hhmmss)
$Outfile = "$dir\AzureADDevices-"+$date+".csv"
      $TenantUname = "keswar@eswar.com"
    $TenantPass = cat "C:\Temp\eswar\Scripts\Automation\o365.key" | ConvertTo-SecureString
    $TenantCredentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $TenantUname, $TenantPass
    Connect-AzureAD -Credential $TenantCredentials

# Get All Azure AD Devices
$aadDevices = Get-AzureADDevice -ObjectId "ff7a4bf7-3f34-4873-ba59-395f979bde38" #-All $true| Where-Object {$_.DeviceOSType -notlike "Windows*"}

# Explore Device Object
$aadDevices | Get-Member

# How many Devices did we get?
$aadDevices.count

# Create a custom Device object and start getting some details
$DeviceInfo = @()

ForEach ($aadDevice in $aadDevices) {

    $device = New-Object -TypeName PSObject

    $device | Add-Member -Type NoteProperty -Name ObjectId -Value $aadDevice.ObjectId
    #$device | Add-Member -Type NoteProperty -Name ObjectType -Value $aadDevice.ObjectType
    $device | Add-Member -Type NoteProperty -Name DeviceOSType -Value $aadDevice.DeviceOSType
    $device | Add-Member -Type NoteProperty -Name DeviceOSVersion -Value $aadDevice.DeviceOSVersion
    $device | Add-Member -Type NoteProperty -Name DeviceTrustType -Value $aadDevice.DeviceTrustType
    $device | Add-Member -Type NoteProperty -Name DisplayName -Value $aadDevice.DisplayName
    $device | Add-Member -Type NoteProperty -Name IsCompliant -Value $aadDevice.IsCompliant
    $device | Add-Member -Type NoteProperty -Name IsManaged -Value $aadDevice.IsManaged
    #If ($aadDevice.LastDirSyncTime) { $device | Add-Member -Type NoteProperty -Name LastDirSyncTime -Value ([datetime]$aadDevice.LastDirSyncTime) }
    If ($aadDevice.ApproximateLastLogonTimeStamp) {$device | Add-Member -Type NoteProperty -Name ApproximateLastLogonTimeStamp -Value ([datetime]$aadDevice.ApproximateLastLogonTimeStamp) }
        $deviceOwner = Get-AzureADDeviceRegisteredOwner -ObjectId $aadDevice.ObjectId
    If ($deviceOwner) {     #   Write-Host $aadDevice.DisplayName $deviceOwner.DisplayName -ForegroundColor Yellow
     #$device | Add-Member -Type NoteProperty -Name OwnerDisplayName -Value $deviceOwner.DisplayName
     $device | Add-Member -Type NoteProperty -Name OwnerUserPrincipalName -Value $deviceOwner.UserPrincipalName
    }

    $deviceUser = Get-AzureADDeviceRegisteredUser -ObjectId $aadDevice.ObjectId
    If ($deviceUser) {
     #   Write-Host $aadDevice.DisplayName $deviceOwner.DisplayName -ForegroundColor Green
      #  $device | Add-Member -Type NoteProperty -Name RegisteredUserDisplayName -Value $deviceUser.DisplayName
        $device | Add-Member -Type NoteProperty -Name RegisteredUserUserPrincipalName -Value $deviceUser.UserPrincipalName
    }

    $DeviceInfo += $device

}

# Export to CSV file
$DeviceInfo | Select ObjectId,DeviceOSType,DeviceOSVersion,DisplayName,IsCompliant,IsManaged,DeviceTrustType,ApproximateLastLogonTimeStamp,OwnerUserPrincipalName,RegisteredUserUserPrincipalName | Export-Csv $Outfile -Encoding UTF8 -NoTypeInformation -Delimiter ";"

# Explore some groupings of Devices

<#
$DeviceInfo | Group DeviceOSType
$DeviceInfo | Group DeviceTrustType
$DeviceInfo | Group DeviceOSVersion
$DeviceInfo | Group OwnerDisplayName
$DeviceInfo | Group RegisteredUserDisplayName
$DeviceInfo | Group IsCompliant
$DeviceInfo | Group IsManaged

#>
