<#
Description: Install Configmgr client via intune using the offline source files.
#>
Copy-Item -Path ".\Client" -Destination "c:\windows\temp\intunetemp" -Recurse
#pls read the blog post to get the client installation switches used here http://eskonr.com/2020/05/how-to-prepare-sccm-cmg-client-installation-switches-for-internet-based-client/
c:\windows\temp\intunetemp\ccmsetup.exe /source:c:\windows\temp\intunetemp /nocrlcheck CCMHTTPSSTATE=31 CCMHOSTNAME=CMGcloudname SMSSiteCode=P01 AADTENANTID=xxxxxxx-xxxxx-44E9-AFEB-CDB37C8F5D07 AADCLIENTAPPID=xxxxxxx-xxxxx-459c-8f9c-xxxxx AADRESOURCEURI=https://ConfigMgrService
$retry = 0
while($retry -lt 5)
     {
$service= get-service -name CcmExec
if($service)
           {
exit 0
           }
else
           {
start-sleep -s 30
$retry ++
write-output "Retrying $retry"
           }
          }
exit 1