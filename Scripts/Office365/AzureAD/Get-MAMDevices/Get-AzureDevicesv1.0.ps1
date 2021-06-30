
<#
Title:Get list of All Azure AD devices (registered and hybrid azure AD join and enrolled)
Author:Eswar Koneti
Date:26-Aug-2018
#>


$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$date = (get-date -f dd-MM-yyyy-hhmmss)
$Outfile = "$dir\AzureADDevices-"+$date+".csv"
Connect-AzureAD

$aadDevices = Get-AzureADDevice -All $true | Where-Object {$_.DeviceOSType -notlike "Windows*"}

$aadDevices | Get-Member

$aadDevices.count

$DeviceInfo = @()

ForEach ($aadDevice in $aadDevices) {

    $device = New-Object -TypeName PSObject
   $device | Add-Member -Type NoteProperty -Name ObjectId -Value $aadDevice.ObjectId

    $device | Add-Member -Type NoteProperty -Name DeviceOSType -Value $aadDevice.DeviceOSType
    $device | Add-Member -Type NoteProperty -Name DeviceOSVersion -Value $aadDevice.DeviceOSVersion
   
    $device | Add-Member -Type NoteProperty -Name DisplayName -Value $aadDevice.DisplayName
    $device | Add-Member -Type NoteProperty -Name IsCompliant -Value $aadDevice.IsCompliant
    $device | Add-Member -Type NoteProperty -Name IsManaged -Value $aadDevice.IsManaged
   
    If ($aadDevice.ApproximateLastLogonTimeStamp) {$device | Add-Member -Type NoteProperty -Name ApproximateLastLogonTimeStamp -Value ([datetime]$aadDevice.ApproximateLastLogonTimeStamp) }
        $deviceOwner = Get-AzureADDeviceRegisteredOwner -ObjectId $aadDevice.ObjectId
    If ($deviceOwner) {     #   Write-Host $aadDevice.DisplayName $deviceOwner.DisplayName -ForegroundColor Yellow
  
     $device | Add-Member -Type NoteProperty -Name OwnerUserPrincipalName -Value $deviceOwner.UserPrincipalName
    }

    $deviceUser = Get-AzureADDeviceRegisteredUser -ObjectId $aadDevice.ObjectId
    If ($deviceUser) {
   
        $device | Add-Member -Type NoteProperty -Name RegisteredUserUserPrincipalName -Value $deviceUser.UserPrincipalName
    }

    $DeviceInfo += $device

}

$DeviceInfo | Select ObjectId,DeviceOSType,DeviceOSVersion,DisplayName,IsCompliant,IsManaged,ApproximateLastLogonTimeStamp,OwnerUserPrincipalName,RegisteredUserUserPrincipalName | Export-Csv $Outfile -Encoding UTF8 -NoTypeInformation -Delimiter ";"


#>
