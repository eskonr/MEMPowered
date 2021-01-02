#Title:Install DP role on remeote computers.
#Author:Eswar Koneti
#dated:05-Jul-2017
#Contact via: www.eskonr.com

Try
{
#Import SCCM PowerShell Module
import-module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)  
}
Catch
{
  Write-Host "[ERROR]`t SCCM Module couldn't be loaded. Script will stop!"
  Exit 1
}
#Get SiteCode and change the to Drive
$SiteCode = (Get-PSDrive -PSProvider CMSITE).name
Set-location $SiteCode":"
$SMSProvider=$sitecode.SiteServer

# Determine script location
$ScriptDir = Split-Path $script:MyInvocation.MyCommand.Path
$log      = "$ScriptDir\DPStatus.log"
$date     = Get-Date -Format "dd-MM-yyyy hh:mm:ss"
#[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null
#$DPsite= [Microsoft.VisualBasic.Interaction]::InputBox("Enter sitecode that you wish DP to install ", "Sitecode")

"---------------------  Script started at $date (DD-MM-YYYY hh:mm:ss) ---------------------" + "`r`n" | Out-File $log -append
# Get list of computers from CSV file
ForEach ($cmp in Import-CSV "$ScriptDir\DPcomputers.csv")
{
$system=$cmp.Servername
$Description=$cmp.description
$TSite=$cmp.Sitecode
#Check if the computer exist in AD before installing the DP
    if (Get-ADComputer -filter {name -like $system})
    {
    # If computer found in AD ,check if the DP role already installed on the computer
             $DProle=gwmi -Namespace root\sms\site_$($SiteCode) -Class SMS_SCI_SysResUse | where {$_.NetworkOSPath -like "*$system*" -and $_.RoleName -eq "SMS Distribution Point"}
              if ($DProle) {"DP Role already installed on $system" | Out-File $log -append }
               else {
#If DP not installed ,procedd to install DP role on computer
New-CMSiteSystemServer -SiteSystemServerName "$system.$env:userdnsdomain" -AccountName "pruasia\srvsgrhosccm" -SiteCode $TSite
Add-CMDistributionPoint -CertificateExpirationTimeUtc "2120/07/05 9:45:00" `
                        -SiteSystemServerName "$system.$env:userdnsdomain" -InstallInternetServer -Description $Description `
                        -EnableAnonymous -EnableContentValidation -MinimumFreeSpaceMB 5000 -SiteCode $TSite
"DP Role installation initiated on $system, please Monitor the log" | Out-File $log -append 
                    }
      } 
     else {"$system doesnt exist in AD,Please Check" | Out-File $log -append }
          
}
"---------------------  Script ended at $date (DD-MM-YYYY hh:mm:ss) ---------------------" + "`r`n" | Out-File $log -append
