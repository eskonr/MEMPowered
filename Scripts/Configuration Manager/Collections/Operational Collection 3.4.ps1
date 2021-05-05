#############################################################################
# Author  : Benoit Lecours 
# Website : www.SystemCenterDudes.com
# Twitter : @scdudes
#
# Version : 3.4
# Created : 2014/07/17
# Modified : 
# 2014/08/14 - Added Collection 34,35,36
# 2014/09/23 - Changed collection 4 to CU3 instead of CU2
# 2015/01/30 - Improve Android collection
# 2015/02/03 - Changed collection 4 to CU4 instead of CU3
# 2015/05/06 - Changed collection 4 to CU5 instead of CU4
# 2015/05/06 - Changed collection 4 to SP1 instead of CU5
#            - Add collections 37 to 42
# 2015/08/04 - Add collection 43,44
#            - Changed collection 4 to SP1 CU1 instead of SP1
# 2015/08/06 - Change collection 22 query
# 2015/08/12 - Added Windows 10 - Collection 45
# 2015/11/10 - Changed collection 4 to SP1 CU2 instead of CU1, Add collection 46
# 2015/12/04 - Changed collection 4 to SCCM 1511 instead of CU2, Add collection 47
# 2016/02/16 - Add collection 48 and 49. Complete Revamp of Collections naming. Comment added on all collections
# 2016/03/03 - Add collection 51
# 2016/03/14 - Add collection 52
# 2016/03/15 - Added Error handling and better output
# 2016/08/08 - Add collection 53-56. Modification to collection 4,31,32,33
# 2016/09/14 - Add collection 57
# 2016/10/03 - Add collection 58 to 63
# 2016/10/14 - Add collection 64 to 67
# 2016/10/28 - Bug fixes and updated collection 50
# 2016/11/18 - Add collection 68
# 2017/02/03 - Corrected collection 39 and 68
# 2017/03/27 - Add collection 69,70,71
# 2017/08/25 - Add collection 72
# 2017/11/21 - Add collection 73
# 2018/02/12 - Add collection 74-76. Changed "=" instead of like for OS Build Collections
# 2018/03/27 - Add collection 77-81. Corrected Collection 75,76 to limit to Workstations only. Collection 73 updated to include 1710 Hotfix
# 2018/07/04 - Version 3.0
#            - Add Collection 82-87
#            - Optimized script to run with objects, extended options for replacing existing collections, and collection folder creation when not on site server.
# 2018/08/01 - Add Collection 88
# 2019/04/04 - Add Collection 89-91
# 2019/09/17 - Add Collection 92-94, Windows 2019, Updated Windows 2016
# 2020/01/09 - Add Collection 95-100
#            
# Purpose : This script create a set of SCCM collections and move it in an "Operational" folder
# Special Thanks to Joshua Barnette for V3.0
#
#############################################################################

#Load Configuration Manager PowerShell Module
Import-module ($Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5)+ '\ConfigurationManager.psd1')

#Get SiteCode
$SiteCode = Get-PSDrive -PSProvider CMSITE
Set-location $SiteCode":"

#Error Handling and output
Clear-Host
$ErrorActionPreference= 'SilentlyContinue'

#Create Default Folder 
$CollectionFolder = @{Name ="Operational"; ObjectType =5000; ParentContainerNodeId =0}
Set-WmiInstance -Namespace "root\sms\site_$($SiteCode.Name)" -Class "SMS_ObjectContainerNode" -Arguments $CollectionFolder -ComputerName $SiteCode.Root
$FolderPath =($SiteCode.Name +":\DeviceCollection\" + $CollectionFolder.Name)

#Set Default limiting collections
$LimitingCollection ="All Systems"

#Refresh Schedule
$Schedule =New-CMSchedule –RecurInterval Days –RecurCount 1


#Find Existing Collections
$ExistingCollections = Get-CMDeviceCollection -Name "* | *" | Select-Object CollectionID, Name

#List of Collections Query
$DummyObject = New-Object -TypeName PSObject 
$Collections = @()

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients | All"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.Client = 1"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All devices detected by SCCM"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients | No"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.Client = 0 OR SMS_R_System.Client is NULL"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All devices without SCCM client installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | Not Latest (1910)"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion not like '5.00.8913.100%'"}},@{L="LimitingCollection"
; E={"Clients | All"}},@{L="Comment"
; E={"All devices without SCCM client version 1910"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | R2 CU1"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion = '5.00.7958.1203'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version R2 CU1 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | R2 CU2"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion = '5.00.7958.1303'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version R2 CU2 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | R2 CU3"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion like '5.00.7958.14%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version R2 CU3 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | R2 CU4"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion = '5.00.7958.1501'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version R2 CU4 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | R2 CU5"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion = '5.00.7958.1604'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version R2 CU5 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | R2 CU0"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion = '5.00.7958.1000'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version R2 CU0 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | R2 SP1"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion = '5.00.8239.1000'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version R2 SP1 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | R2 SP1 CU1"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion = '5.00.8239.1203'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version R2 SP1 CU1 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | R2 SP1 CU2"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion = '5.00.8239.1301'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version R2 SP1 CU2 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | R2 SP1 CU3"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion = '5.00.8239.1403'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version R2 SP1 CU3 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1511"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion = '5.00.8325.1000'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1511 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1602"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion = '5.00.8355.1000'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1602 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1606"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion like '5.00.8412.100%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1606 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1610"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion like '5.00.8458.100%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1610 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1702"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion like '5.00.8498.100%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1702 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1706"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion like '5.00.8540.100%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1706 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1710"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ClientVersion like '5.00.8577.100%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1710 installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Hardware Inventory | Clients Not Reporting since 14 Days"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where ResourceId in (select SMS_R_System.ResourceID from SMS_R_System inner join SMS_G_System_WORKSTATION_STATUS on SMS_G_System_WORKSTATION_STATUS.ResourceID = SMS_R_System.ResourceId where DATEDIFF(dd,SMS_G_System_WORKSTATION_STATUS.LastHardwareScan,GetDate())
 > 14)"}},@{L="LimitingCollection" 
; E={"Clients | All"}},@{L="Comment"
; E={"All devices with SCCM client that have not communicated with hardware inventory over 14 days"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Laptops | All"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System
 inner join SMS_G_System_SYSTEM_ENCLOSURE on SMS_G_System_SYSTEM_ENCLOSURE.ResourceID = SMS_R_System.ResourceId where SMS_G_System_SYSTEM_ENCLOSURE.ChassisTypes in ('8', '9', '10', '11', '12', '14', '18', '21')"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All laptops"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Laptops | Dell"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_G_System_COMPUTER_SYSTEM.Manufacturer like '%Dell%'"}},@{L="LimitingCollection"
; E={"Laptops | All"}},@{L="Comment"
; E={"All laptops with Dell manufacturer"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Laptops | HP"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_G_System_COMPUTER_SYSTEM.Manufacturer like '%HP%' or SMS_G_System_COMPUTER_SYSTEM.Manufacturer like '%Hewlett-Packard%'"}},@{L="LimitingCollection"
; E={"Laptops | All"}},@{L="Comment"
; E={"All laptops with HP manufacturer"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Laptops | Lenovo"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_G_System_COMPUTER_SYSTEM.Manufacturer like '%Lenovo%'"}},@{L="LimitingCollection"
; E={"Laptops | All"}},@{L="Comment"
; E={"All laptops with Lenovo manufacturer"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Mobile Devices | All"}},@{L="Query"
; E={"select * from SMS_R_System where SMS_R_System.ClientType = 3"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All Mobile Devices"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Mobile Devices | Android"}},@{L="Query"
; E={"SELECT SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client FROM SMS_R_System
 INNER JOIN SMS_G_System_DEVICE_OSINFORMATION ON SMS_G_System_DEVICE_OSINFORMATION.ResourceID = SMS_R_System.ResourceId WHERE SMS_G_System_DEVICE_OSINFORMATION.Platform like 'Android%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All Android mobile devices"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Mobile Devices | iPhone"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_DEVICE_COMPUTERSYSTEM on SMS_G_System_DEVICE_COMPUTERSYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_G_System_DEVICE_COMPUTERSYSTEM.DeviceModel like '%Iphone%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All iPhone mobile devices"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Mobile Devices | iPad"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_DEVICE_COMPUTERSYSTEM on SMS_G_System_DEVICE_COMPUTERSYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_G_System_DEVICE_COMPUTERSYSTEM.DeviceModel like '%Ipad%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All iPad mobile devices"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Mobile Devices | Windows Phone 8"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System
 inner join SMS_G_System_DEVICE_OSINFORMATION on SMS_G_System_DEVICE_OSINFORMATION.ResourceID = SMS_R_System.ResourceId where SMS_G_System_DEVICE_OSINFORMATION.Platform = 'Windows Phone' and SMS_G_System_DEVICE_OSINFORMATION.Version like '8.0%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All Windows 8 mobile devices"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Mobile Devices | Windows Phone 8.1"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System
 inner join SMS_G_System_DEVICE_OSINFORMATION on SMS_G_System_DEVICE_OSINFORMATION.ResourceID = SMS_R_System.ResourceId where SMS_G_System_DEVICE_OSINFORMATION.Platform = 'Windows Phone' and SMS_G_System_DEVICE_OSINFORMATION.Version like '8.1%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All Windows 8.1 mobile devices"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Mobile Devices | Windows Phone 10"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System
 inner join SMS_G_System_DEVICE_OSINFORMATION on SMS_G_System_DEVICE_OSINFORMATION.ResourceID = SMS_R_System.ResourceId where SMS_G_System_DEVICE_OSINFORMATION.Platform = 'Windows Phone' and SMS_G_System_DEVICE_OSINFORMATION.Version like '10%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All Windows Phone 10"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Mobile Devices | Microsoft Surface"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System
 inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_G_System_COMPUTER_SYSTEM.Model like '%Surface%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All Windows RT mobile devices"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Mobile Devices | Microsoft Surface 3"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System
 inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_G_System_COMPUTER_SYSTEM.Model = 'Surface Pro 3' OR SMS_G_System_COMPUTER_SYSTEM.Model = 'Surface 3'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All Microsoft Surface 3"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Mobile Devices | Microsoft Surface 4"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System
 inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_G_System_COMPUTER_SYSTEM.Model = 'Surface Pro 4'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All Microsoft Surface 4"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Others | Linux Devices"}},@{L="Query"
; E={"select * from SMS_R_System where SMS_R_System.ClientEdition = 13"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with Linux"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Others | MAC OSX Devices"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 WHERE OperatingSystemNameandVersion LIKE 'Apple Mac OS X%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All workstations with MAC OSX"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"SCCM | Console"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_ADD_REMOVE_PROGRAMS on SMS_G_System_ADD_REMOVE_PROGRAMS.ResourceID = SMS_R_System.ResourceId where SMS_G_System_ADD_REMOVE_PROGRAMS.DisplayName like '%Configuration Manager Console%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM console installed"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"SCCM | Site Servers"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System
 where SMS_R_System.SystemRoles = 'SMS Site Server'"}},@{L="LimitingCollection"
; E={"Servers | All"}},@{L="Comment"
; E={"All systems that is SCCM site server"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"SCCM | Site Systems"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System
 where SMS_R_System.SystemRoles = 'SMS Site System' or SMS_R_System.ResourceNames in (Select ServerName FROM SMS_DistributionPointInfo)"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems that is SCCM site system"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"SCCM | Distribution Points"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from SMS_R_System
 where SMS_R_System.ResourceNames in (Select ServerName FROM SMS_DistributionPointInfo)"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems that is SCCM distribution point"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Servers | All"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where OperatingSystemNameandVersion like '%Server%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All servers"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Servers | Active"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_CH_ClientSummary on SMS_G_System_CH_ClientSummary.ResourceId = SMS_R_System.ResourceId where SMS_G_System_CH_ClientSummary.ClientActiveStatus = 1 and SMS_R_System.Client = 1 and SMS_R_System.Obsolete = 0"}},@{L="LimitingCollection"
; E={"Servers | All"}},@{L="Comment"
; E={"All servers with active state"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Servers | Physical"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.ResourceId not in (select SMS_R_SYSTEM.ResourceID from SMS_R_System inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceId = SMS_R_System.ResourceId where SMS_R_System.IsVirtualMachine = 'True') and SMS_R_System.OperatingSystemNameandVersion
 like 'Microsoft Windows NT%Server%'"}},@{L="LimitingCollection"
; E={"Servers | All"}},@{L="Comment"
; E={"All physical servers"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Servers | Virtual"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.IsVirtualMachine = 'True' and SMS_R_System.OperatingSystemNameandVersion like 'Microsoft Windows NT%Server%'"}},@{L="LimitingCollection"
; E={"Servers | All"}},@{L="Comment"
; E={"All virtual servers"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Servers | Windows 2003 and 2003 R2"}},@{L="Query"
; E={"select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System
 where OperatingSystemNameandVersion like '%Server 5.2%'"}},@{L="LimitingCollection"
; E={"Servers | All"}},@{L="Comment"
; E={"All servers with Windows 2003 or 2003 R2 operating system"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Servers | Windows 2008 and 2008 R2"}},@{L="Query"
; E={"select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System
 where OperatingSystemNameandVersion like '%Server 6.0%' or OperatingSystemNameandVersion like '%Server 6.1%'"}},@{L="LimitingCollection"
; E={"Servers | All"}},@{L="Comment"
; E={"All servers with Windows 2008 or 2008 R2 operating system"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Servers | Windows 2012 and 2012 R2"}},@{L="Query"
; E={"select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System
 where OperatingSystemNameandVersion like '%Server 6.2%' or OperatingSystemNameandVersion like '%Server 6.3%'"}},@{L="LimitingCollection"
; E={"Servers | All"}},@{L="Comment"
; E={"All servers with Windows 2012 or 2012 R2 operating system"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Servers | Windows 2016"}},@{L="Query"
; E={"select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System inner join SMS_G_System_OPERATING_SYSTEM on SMS_G_System_OPERATING_SYSTEM.ResourceId = SMS_R_System.ResourceId where OperatingSystemNameandVersion like '%Server 10%' and SMS_G_System_OPERATING_SYSTEM.BuildNumber = '14393'"}},@{L="LimitingCollection"
; E={"Servers | All"}},@{L="Comment"
; E={"All Servers with Windows 2016"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Servers | Windows 2019"}},@{L="Query"
; E={"select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System inner join SMS_G_System_OPERATING_SYSTEM on SMS_G_System_OPERATING_SYSTEM.ResourceId = SMS_R_System.ResourceId where OperatingSystemNameandVersion like '%Server 10%' and SMS_G_System_OPERATING_SYSTEM.BuildNumber = '17763'"}},@{L="LimitingCollection"
; E={"Servers | All"}},@{L="Comment"
; E={"All Servers with Windows 2019"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Software Inventory | Clients Not Reporting since 30 Days"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where ResourceId in (select SMS_R_System.ResourceID from SMS_R_System inner join SMS_G_System_LastSoftwareScan on SMS_G_System_LastSoftwareScan.ResourceId = SMS_R_System.ResourceId where DATEDIFF(dd,SMS_G_System_LastSoftwareScan.LastScanDate,GetDate()) > 30)"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All devices with SCCM client that have not communicated with software inventory over 30 days"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"System Health | Clients Active"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_CH_ClientSummary on SMS_G_System_CH_ClientSummary.ResourceId = SMS_R_System.ResourceId where SMS_G_System_CH_ClientSummary.ClientActiveStatus = 1 and SMS_R_System.Client = 1 and SMS_R_System.Obsolete = 0"}},@{L="LimitingCollection"
; E={"Clients | All"}},@{L="Comment"
; E={"All devices with SCCM client state active"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"System Health | Clients Inactive"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_CH_ClientSummary on SMS_G_System_CH_ClientSummary.ResourceId = SMS_R_System.ResourceId where SMS_G_System_CH_ClientSummary.ClientActiveStatus = 0 and SMS_R_System.Client = 1 and SMS_R_System.Obsolete = 0"}},@{L="LimitingCollection"
; E={"Clients | All"}},@{L="Comment"
; E={"All devices with SCCM client state inactive"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"System Health | Disabled"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.UserAccountControl ='4098'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with client state disabled"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"System Health | Obsolete"}},@{L="Query"
; E={"select * from SMS_R_System where SMS_R_System.Obsolete = 1"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All devices with SCCM client state obsolete"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Systems | x86"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceID = SMS_R_System.ResourceId where SMS_G_System_COMPUTER_SYSTEM.SystemType = 'X86-based PC'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with 32-bit system type"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Systems | x64"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_COMPUTER_SYSTEM on SMS_G_System_COMPUTER_SYSTEM.ResourceID = SMS_R_System.ResourceId where SMS_G_System_COMPUTER_SYSTEM.SystemType = 'X64-based PC'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with 64-bit system type"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Systems | Created Since 24h"}},@{L="Query"
; E={"select SMS_R_System.Name, SMS_R_System.CreationDate FROM SMS_R_System WHERE DateDiff(dd,SMS_R_System.CreationDate, GetDate()) <= 1"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems created in the last 24 hours"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Windows Update Agent | Outdated Version Win7 RTM and Lower"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_WINDOWSUPDATEAGENTVERSION on SMS_G_System_WINDOWSUPDATEAGENTVERSION.ResourceID = SMS_R_System.ResourceId inner join SMS_G_System_OPERATING_SYSTEM on SMS_G_System_OPERATING_SYSTEM.ResourceID = SMS_R_System.ResourceId where SMS_G_System_WINDOWSUPDATEAGENTVERSION.Version
 < '7.6.7600.256' and SMS_G_System_OPERATING_SYSTEM.Version <= '6.1.7600'"}},@{L="LimitingCollection"
; E={"Workstations | All"}},@{L="Comment"
; E={"All systems with windows update agent with outdated version Win7 RTM and lower"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Windows Update Agent | Outdated Version Win7 SP1 and Higher"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_WINDOWSUPDATEAGENTVERSION on SMS_G_System_WINDOWSUPDATEAGENTVERSION.ResourceID = SMS_R_System.ResourceId inner join SMS_G_System_OPERATING_SYSTEM on SMS_G_System_OPERATING_SYSTEM.ResourceID = SMS_R_System.ResourceId where SMS_G_System_WINDOWSUPDATEAGENTVERSION.Version
 < '7.6.7600.320' and SMS_G_System_OPERATING_SYSTEM.Version >= '6.1.7601'"}},@{L="LimitingCollection"
; E={"Workstations | All"}},@{L="Comment"
; E={"All systems with windows update agent with outdated version Win7 SP1 and higher"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | All"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where OperatingSystemNameandVersion like '%Workstation%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All workstations"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Active"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 inner join SMS_G_System_CH_ClientSummary on SMS_G_System_CH_ClientSummary.ResourceId = SMS_R_System.ResourceId where (SMS_R_System.OperatingSystemNameandVersion like 'Microsoft Windows NT%Workstation%' or SMS_R_System.OperatingSystemNameandVersion = 'Windows 7 Entreprise 6.1') and SMS_G_System_CH_ClientSummary.ClientActiveStatus = 1 and SMS_R_System.Client = 1 and SMS_R_System.Obsolete = 0"}},@{L="LimitingCollection"
; E={"Workstations | All"}},@{L="Comment"
; E={"All workstations with active state"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 7"}},@{L="Query"
; E={"select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System
 where OperatingSystemNameandVersion like '%Workstation 6.1%'"}},@{L="LimitingCollection"
; E={"Workstations | All"}},@{L="Comment"
; E={"All workstations with Windows 7 operating system"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 8"}},@{L="Query"
; E={"select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System
 where OperatingSystemNameandVersion like '%Workstation 6.2%'"}},@{L="LimitingCollection"
; E={"Workstations | All"}},@{L="Comment"
; E={"All workstations with Windows 8 operating system"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 8.1"}},@{L="Query"
; E={"select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System
 where OperatingSystemNameandVersion like '%Workstation 6.3%'"}},@{L="LimitingCollection"
; E={"Workstations | All"}},@{L="Comment"
; E={"All workstations with Windows 8.1 operating system"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows XP"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where OperatingSystemNameandVersion like '%Workstation 5.1%' or OperatingSystemNameandVersion like '%Workstation 5.2%'"}},@{L="LimitingCollection"
; E={"Workstations | All"}},@{L="Comment"
; E={"All workstations with Windows XP operating system"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10"}},@{L="Query"
; E={"select SMS_R_System.ResourceID,SMS_R_System.ResourceType,SMS_R_System.Name,SMS_R_System.SMSUniqueIdentifier,SMS_R_System.ResourceDomainORWorkgroup,SMS_R_System.Client from SMS_R_System
 where OperatingSystemNameandVersion like '%Workstation 10.0%'"}},@{L="LimitingCollection"
; E={"Workstations | All"}},@{L="Comment"
; E={"All workstations with Windows 10 operating system"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 v1507"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.Build = '10.0.10240'"}},@{L="LimitingCollection"
; E={"Workstations | Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 operating system v1507"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 v1511"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.Build = '10.0.10586'"}},@{L="LimitingCollection"
; E={"Workstations | Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 operating system v1511"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 v1607"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.Build = '10.0.14393'"}},@{L="LimitingCollection"
; E={"Workstations | Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 operating system v1607"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 v1703"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.Build = '10.0.15063'"}},@{L="LimitingCollection"
; E={"Workstations | Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 operating system v1703"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 v1709"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.Build = '10.0.16299'"}},@{L="LimitingCollection"
; E={"Workstations | Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 operating system v1709"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 Current Branch (CB)"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.OSBranch = '0'"}},@{L="LimitingCollection"
; E={"Workstations | Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 CB"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 Current Branch for Business (CBB)"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.OSBranch = '1'"}},@{L="LimitingCollection"
; E={"Workstations | Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 CBB"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 Long Term Servicing Branch (LTSB)"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 where SMS_R_System.OSBranch = '2'"}},@{L="LimitingCollection"
; E={"Workstations | Windows 10"}},@{L="Comment"
; E={"All workstations with Windows 10 LTSB"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 Support State - Current"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 LEFT OUTER JOIN SMS_WindowsServicingStates ON SMS_WindowsServicingStates.Build = SMS_R_System.build01 AND SMS_WindowsServicingStates.branch = SMS_R_System.osbranch01 where SMS_WindowsServicingStates.State = '2'"}},@{L="LimitingCollection"
; E={"Workstations | All"}},@{L="Comment"
; E={"Windows 10 Support State - Current"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 Support State - Expired Soon"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 LEFT OUTER JOIN SMS_WindowsServicingStates ON SMS_WindowsServicingStates.Build = SMS_R_System.build01 AND SMS_WindowsServicingStates.branch = SMS_R_System.osbranch01 where SMS_WindowsServicingStates.State = '3'"}},@{L="LimitingCollection"
; E={"Workstations | All"}},@{L="Comment"
; E={"Windows 10 Support State - Expired Soon"}}

$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 Support State - Expired"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System
 LEFT OUTER JOIN SMS_WindowsServicingStates ON SMS_WindowsServicingStates.Build = SMS_R_System.build01 AND SMS_WindowsServicingStates.branch = SMS_R_System.osbranch01 where SMS_WindowsServicingStates.State = '4'"}},@{L="LimitingCollection"
; E={"Workstations | All"}},@{L="Comment"
; E={"Windows 10 Support State - Expired"}}

##Collection 77
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1802"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.8634.10%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1802 installed"}}

##Collection 78
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Build Version | 1802"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceId = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.VersionToReport like '16.0.9029.%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Build Version | 1802"}}

##Collection 79
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Build Version | 1803"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceId = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.VersionToReport like '16.0.9126.%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Build Version | 1803"}}

##Collection 80
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Build Version | 1708"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceId = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.VersionToReport like '16.0.8431.%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Build Version | 1708"}}

##Collection 81
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Build Version | 1705"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceId = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.VersionToReport like '16.0.8201.%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Build Version | 1705"}}

##Collection 82
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"System Health | Clients Online"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ResourceId in (select resourceid from SMS_CollectionMemberClientBaselineStatus where SMS_CollectionMemberClientBaselineStatus.CNIsOnline = 1)"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"System Health | Clients Online"}}

##Collection 83
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 v1803"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Build = '10.0.17134'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Workstations | Windows 10 v1803"}}

##Collection 84
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Channel | Monthly"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from  SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceID = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.cfgUpdateChannel = 'http://officecdn.microsoft.com/pr/492350f6-3a01-4f97-b9c0-c7c6ddf67d60'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Channel | Monthly"}}

##Collection 85
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Channel | Monthly (Targeted)"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from  SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceID = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.cfgUpdateChannel = 'http://officecdn.microsoft.com/pr/64256afe-f5d9-4f86-8936-8840a6a4f5be'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Channel | Monthly (Targeted)"}}

##Collection 86
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Channel | Semi-Annual (Targeted)"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceID = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.cfgUpdateChannel = 'http://officecdn.microsoft.com/pr/b8f9b850-328d-4355-9145-c59439a0c4cf'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Channel | Semi-Annual (Targeted)"}}

##Collection 87
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Channel | Semi-Annual"}},@{L="Query"
; E={"select SMS_R_System.ResourceId, SMS_R_System.ResourceType, SMS_R_System.Name, SMS_R_System.SMSUniqueIdentifier, SMS_R_System.ResourceDomainORWorkgroup, SMS_R_System.Client from  SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceID = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.cfgUpdateChannel = 'http://officecdn.microsoft.com/pr/7ffbc6bf-bc32-4f92-8982-f9dd17fd3114'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Channel | Semi-Annual"}}

##Collection 88
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1806"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.8692.10%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"All systems with SCCM client version 1806 installed"}}

##Collection 89
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1810"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.8740.10%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"; E={"All systems with SCCM client version 1810 installed"}}

##Collection 90
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1902"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.8790.10%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"; E={"All systems with SCCM client version 1902 installed"}}

##Collection 91
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"System Health | Duplicate Device Name"}},@{L="Query"
; E={"select R.ResourceID,R.ResourceType,R.Name,R.SMSUniqueIdentifier,R.ResourceDomainORWorkgroup,R.Client from SMS_R_System as r   full join SMS_R_System as s1 on s1.ResourceId = r.ResourceId   full join SMS_R_System as s2 on s2.Name = s1.Name   where s1.Name = s2.Name and s1.ResourceId != s2.ResourceId"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"; E={"All systems having a duplicate device record"}}

##Collection 92
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1906"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.8853.10%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"; E={"All systems with SCCM client version 1906 installed"}}

##Collection 93
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 v1809"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Build = '10.0.17763'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Workstations | Windows 10 v1809"}}

##Collection 94
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 v1903"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Build = '10.0.18362'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Workstations | Windows 10 v1903"}}

##Collection 95
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Clients Version | 1910"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion like '5.00.8913.10%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"; E={"All systems with SCCM client version 1910 installed"}}

##Collection 96
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Build Version | 1808"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceId = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.VersionToReport like '16.0.10730.%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Build Version | 1808"}}

##Collection 97
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Build Version | 1902"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceId = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.VersionToReport like '16.0.11328.%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Build Version | 1902"}}

##Collection 98
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Build Version | 1908"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceId = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.VersionToReport like '16.0.11929.%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Build Version | 1908"}}

##Collection 99
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Office 365 Build Version | 1912"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceId = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.VersionToReport like '16.0.12325.%'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Office 365 Build Version | 1912"}}

##Collection 100
$Collections +=
$DummyObject |
Select-Object @{L="Name"
; E={"Workstations | Windows 10 v1909"}},@{L="Query"
; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.Build = '10.0.18363'"}},@{L="LimitingCollection"
; E={$LimitingCollection}},@{L="Comment"
; E={"Workstations | Windows 10 v1909"}}

#Check Existing Collections
$Overwrite = 1
$ErrorCount = 0
$ErrorHeader = "The script has already been run. The following collections already exist in your environment:`n`r"
$ErrorCollections = @()
$ErrorFooter = "Would you like to delete and recreate the collections above? (Default : No) "
$ExistingCollections | Sort-Object Name | ForEach-Object {If($Collections.Name -Contains $_.Name) {$ErrorCount +=1 ; $ErrorCollections += $_.Name}}

#Error
If ($ErrorCount -ge1) 
    {
    Write-Host $ErrorHeader $($ErrorCollections | ForEach-Object {(" " + $_ + "`n`r")}) $ErrorFooter -ForegroundColor Yellow -NoNewline
    $ConfirmOverwrite = Read-Host "[Y/N]"
    If ($ConfirmOverwrite -ne "Y") {$Overwrite =0}
    }

#Create Collection And Move the collection to the right folder
If ($Overwrite -eq1) {
$ErrorCount =0

ForEach ($Collection
In $($Collections | Sort-Object LimitingCollection -Descending))

{
If ($ErrorCollections -Contains $Collection.Name)
    {
    Get-CMDeviceCollection -Name $Collection.Name | Remove-CMDeviceCollection -Force
    Write-host *** Collection $Collection.Name removed and will be recreated ***
    }
}

ForEach ($Collection In $($Collections | Sort-Object LimitingCollection))
{

Try 
    {
    New-CMDeviceCollection -Name $Collection.Name -Comment $Collection.Comment -LimitingCollectionName $Collection.LimitingCollection -RefreshSchedule $Schedule -RefreshType 2 | Out-Null
    Add-CMDeviceCollectionQueryMembershipRule -CollectionName $Collection.Name -QueryExpression $Collection.Query -RuleName $Collection.Name
    Write-host *** Collection $Collection.Name created ***
    }

Catch {
        Write-host "-----------------"
        Write-host -ForegroundColor Red ("There was an error creating the: " + $Collection.Name + " collection.")
        Write-host "-----------------"
        $ErrorCount += 1
        Pause
}

Try {
        Move-CMObject -FolderPath $FolderPath -InputObject $(Get-CMDeviceCollection -Name $Collection.Name)
        Write-host *** Collection $Collection.Name moved to $CollectionFolder.Name folder***
    }

Catch {
        Write-host "-----------------"
        Write-host -ForegroundColor Red ("There was an error moving the: " + $Collection.Name +" collection to " + $CollectionFolder.Name +".")
        Write-host "-----------------"
        $ErrorCount += 1
        Pause
      }

}

If ($ErrorCount -ge1) {

        Write-host "-----------------"
        Write-Host -ForegroundColor Red "The script execution completed, but with errors."
        Write-host "-----------------"
        Pause
}

Else{
        Write-host "-----------------"
        Write-Host -ForegroundColor Green "Script execution completed without error. Operational Collections created sucessfully."
        Write-host "-----------------"
        Pause
    }
}

Else {
        Write-host "-----------------"
        Write-host -ForegroundColor Red ("The following collections already exist in your environment:`n`r" + $($ErrorCollections | ForEach-Object {(" " +$_ + "`n`r")}) + "Please delete all collections manually or rename them before re-executing the script! You can also select Y to do it automaticaly")
        Write-host "-----------------"
        Pause
}
