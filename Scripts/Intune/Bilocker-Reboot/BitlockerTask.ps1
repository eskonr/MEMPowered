<#
Description: This script will reboot the device upon the completion of the bitlocker encryption.
When we use intune device compliance policy, the DHA policy does require device reboot to successful compliance check.
https://techcommunity.microsoft.com/t5/intune-customer-success/support-tip-using-device-health-attestation-settings-as-part-of/ba-p/282643
#>
#Create a folder and copy the files
$scriptPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
#Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
#$script:MyInvocation.MyCommand.Path
$dir="C:\ProgramData\BitlockerCheck"
if(!(Test-Path -path $dir))  
{
New-Item -ItemType directory -Path $dir
Copy-Item -Path "$scriptPath\*" -Destination "$dir\" -Recurse
}
else
{
Copy-Item -Path "$scriptPath\*" -Destination "$dir\" -Recurse
}
$class = cimclass MSFT_TaskEventTrigger root/Microsoft/Windows/TaskScheduler
$Trigger_onEvent = $class | New-CimInstance -ClientOnly

$trigger_onEvent.Enabled = $true
$trigger_onEvent.Subscription = @"
<QueryList><Query Id="0" Path="System"><Select Path="System">*[System[EventID=24667]]</Select></Query></QueryList>
"@

$Trigger_atLogon = New-ScheduledTaskTrigger -AtLogOn

#The action to execute
$action = New-ScheduledTaskAction -Execute "C:\ProgramData\BitlockerCheck\Restart.bat"

#Default settings
$settings = New-ScheduledTaskSettingsSet

#$task = New-ScheduledTask -Trigger $Trigger_atLogon, $Trigger_onEvent -Action $action -Settings $settings -Description "System will reboot after the bitlocker completion'"
$task = New-ScheduledTask -Trigger $Trigger_onEvent -Action $action -Settings $settings -Description "System will reboot after the bitlocker completion with event viewer 24667"

#Register-ScheduledTask -TaskName "reBoot-BL" -InputObject $task
Register-ScheduledTask -User "NT AUTHORITY\SYSTEM" -TaskName "Reboot-BitLocker" -InputObject $task

#Register-ScheduledTask -User "NT AUTHORITY\SYSTEM" -TaskName 'WSUS Clean UP TASK' -Trigger $T -Action $A