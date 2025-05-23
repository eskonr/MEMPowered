<#
<#
Script:Generate New GUID for MachineID (s:id)
Description: AVD devices are not reporting to wufb service. Post investigation with MS, these problematic devices are sharing the same s:Id value hence the devices failed to report to wufb.
the fix is to generate the new guid and restart the device. wait for 3-4 days and check wufb reporting.
Date: 05-01-2024
#>

#specify the registry path and value name
$RegPath="HKLM:\SOFTWARE\Microsoft\SQMClient"
$valuename="MachineId"

#Specific the new value name to set
$newguidid=(New-Guid).guid
$newvalue="{$newguidid}"

#set the registry key value
try
{
Set-ItemProperty -path $RegPath -name $valuename -Value $newvalue
Write-Host "New s:id value set $(Get-ItemPropertyValue -path $RegPath -name $valuename)"
}
catch
{
Write-Host "Failed to set New s:id value"
}
