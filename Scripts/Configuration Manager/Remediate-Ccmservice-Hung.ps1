#Kill the service if running
taskkill /im ccmexec.exe /f
#remove any backlog files
Get-ChildItem 'C:\WINDOWS\CCM\ServiceData\Messaging\EndpointQueues' -Include *.msg,*.que -Recurse | foreach ($_) {Remove-Item $_.FullName -Force}
#start the service
net start ccmexec
#reset the policy processing
([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000112}')
Start-Sleep -Seconds 15
#Force hardware inventory
([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000001}')
