
 #############################################################################
# Author  : Eswar Koneti 
# Website : www.eskonr.com
# Twitter : @eskonr
# Created : 22/June/2016
# Purpose : This script create software update deployments based on the information you provide in CSV file
#Supported on ConfigMgr 1702 and above versions due to change in powershell cmdlets
#
#############################################################################

Try
{
  import-module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1) #Import the powershell module . Make sure you have SCCM console installed on the PC that you run the script .
  $SiteCode=Get-PSDrive -PSProvider CMSITE #Get the sitecode 
  cd ((Get-PSDrive -PSProvider CMSite).Name + ':')
}
Catch
{
  Write-Host "[ERROR]`t SCCM Module couldn't be loaded. Script will stop!"
  Exit 1
}

# Determine script location
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
$LoadUsers  = "$ScriptDir\users.txt"
$log      = "$ScriptDir\Status.log"
$date     = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
"---------------------  Script started at $date (DD-MM-YYYY hh:mm:ss) ---------------------" + "`r`n" | Out-File $log -append
$domain = "pruasia" 
$collectionname = "Reset Office 365 Activation"  
 #Read list of users from the text file  
$Users = get-content $LoadUsers
foreach($user in $users) 
{  
Add-CMUserCollectionDirectMembershipRule -CollectionName $collectionname -ResourceId $(get-cmuser -Name "$domain\$user").ResourceID  

if ($error) {
Write-Host " " 
            "User $($user) not added to collection: $collectionname,Please check further: $error"| Out-File $log -append
            $error.Clear()
            }
    else {                    
    Write-Host " "
                 "User $($user) added to Collection: $collectionname "| Out-File $log -append
         }
 
}
  "---------------------  Script finished at $date (DD-MM-YYYY hh:mm:ss) ---------------------" + "`r`n" | Out-File $log -append