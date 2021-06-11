'Set computer name to serial number
'Created by: Eswar koneti
'Creation Date:21-12-2016
'Set oTSEnv = CreateObject("Microsoft.SMS.TSEnvironment")
Set objWMISvc = GetObject( "winmgmts:\\.\root\cimv2" )
Set colItems = objWMISvc.ExecQuery( "Select * from Win32_bios", , 48 )
For Each objItem in colItems
strSerialNumber = objItem.SerialNumber
sn=Replace(strSerialNumber, " ", "")
Next
strMachineName = "ESK" & right(sn,6)
'oTSEnv("OSDComputerName") = UCase(strMachineName)
msgbox strMachineName