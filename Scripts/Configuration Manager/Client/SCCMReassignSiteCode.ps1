
$DesiredSiteCode = 'XXX'
$smsClient = New-Object -ComObject Microsoft.SMS.Client
$Result = $smsClient.GetAssignedSite()

if ($Result -eq $DesiredSiteCode){Exit #site code doesnt need to change}

Else {
$smsClient.SetAssignedSite($DesiredSiteCode) 
$registryPath = 'HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client'

    If (Get-ItemProperty -Path $registryPath -Name GPRequestedSiteAssignmentCode -ErrorAction SilentlyContinue -OutVariable outvar) 

        {   #Cleans hardcoded SiteCode entries from the registry if found
            Get-Item -Path $registryPath | Remove-ItemProperty -Name 'GPRequestedSiteAssignmentCode' -Force -ErrorAction SilentlyContinue
            Get-Item -Path $registryPath | Remove-ItemProperty -Name 'GPSiteAssignmentRetryInterval(Min)' -Force -ErrorAction SilentlyContinue
            Get-Item -Path $registryPath | Remove-ItemProperty -Name 'GPSiteAssignmentRetryDuration(Hour)' -Force -ErrorAction SilentlyContinue
            $RegistryRemediated = 'TRUE'
        }
 
    Else {$RegistryRemediated = 'FALSE'}

$date = Get-Date -Format dd-MM-yy:HH:mm:ss
Write-Output "$env:COMPUTERNAME : Site code changed from $result > $DesiredSiteCode | Registry Remediated = $RegistryRemediated | $date"  | Out-File .\SiteReassign.log -Append
}
  