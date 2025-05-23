<#
Script Name: Publish - StateMsg WMI Status
Description: Before a device process any workloads from sccm, device basically checks if "CoMgmtAlow" and "AutoEnroll" settings are already compliant (settingsagent.log).
This data is stored in the statemsg in wmi. In our case, the wmi statemsg is corrupted hence the wufb workload will not be processed.

#>
#WMI query to statemsg namespace
$wmiObject = Get-WmiObject -Namespace root\ccm\StateMsg -Query "SELECT * FROM CCM_StateMsg WHERE TopicType='401'"
# Check if the query was successful
if ($wmiObject) {
    # Query was successful
    Write-Host "StateMsg is working"
}
else {
    # Query failed
    #Write-Host "StateMsg not working,ccmrepair"
    try
    {
    # Run ccmrepair.exe
    Start-Process -FilePath "C:\windows\ccm\ccmrepair.exe"
    Write-Host "StateMsg not working,ccmrepair.exe success"
    }
    catch
    {
    Write-Host "StateMsg not working,ccmrepair.exe failed"
    }
}