On Error Resume Next
set oSMSClient = CreateObject ("Microsoft.SMS.Client")
'if Err.Number <>0 then
'wscript.echo "Could not create SMS Client Object - quitting"
'end if
'Assign client to Servername
oSMSClient.SetAssignedSite "P02",0
set oSMSClient=nothing
