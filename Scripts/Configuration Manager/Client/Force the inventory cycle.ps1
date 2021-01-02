$comp="localhost"

$HardwareInventoryID = '{00000000-0000-0000-0000-000000000001}'
$SoftwareInventoryID = '{00000000-0000-0000-0000-000000000002}'
$HeartbeatID = '{00000000-0000-0000-0000-000000000003}'
$FileCollectionInventoryID = '{00000000-0000-0000-0000-000000000010}'


Get-WmiObject -ComputerName $comp -Namespace   'Root\CCM\INVAGT' -Class 'InventoryActionStatus' -Filter "InventoryActionID='$HardwareInventoryID'" | Remove-WmiObject
Get-WmiObject -ComputerName $comp -Namespace   'Root\CCM\INVAGT' -Class 'InventoryActionStatus' -Filter "InventoryActionID='$SoftwareInventoryID'" | Remove-WmiObject
Get-WmiObject -ComputerName $comp -Namespace   'Root\CCM\INVAGT' -Class 'InventoryActionStatus' -Filter "InventoryActionID='$HeartbeatID'" | Remove-WmiObject
Get-WmiObject -ComputerName $comp -Namespace   'Root\CCM\INVAGT' -Class 'InventoryActionStatus' -Filter "InventoryActionID='$FileCollectionInventoryID'" | Remove-WmiObject

Start-Sleep -s 5

Invoke-WmiMethod -computername $comp -Namespace root\CCM -Class SMS_Client -Name TriggerSchedule -ArgumentList $HeartbeatID
Invoke-WmiMethod -computername $comp -Namespace root\CCM -Class SMS_Client -Name TriggerSchedule -ArgumentList $HardwareInventoryID
Invoke-WmiMethod -computername $comp -Namespace root\CCM -Class SMS_Client -Name TriggerSchedule -ArgumentList $SoftwareInventoryID
Invoke-WmiMethod -computername $comp -Namespace root\CCM -Class SMS_Client -Name TriggerSchedule -ArgumentList $FileCollectionInventoryID