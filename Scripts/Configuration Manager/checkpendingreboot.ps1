<#
Description: use this script to check if the device is pending for reboot and if pending, reboot the device or use the output as ts variable in SCCM.
#>
If ((Get-ChildItem "REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue) -ne $null) {  
      $a="Reboot pending" 
 #Windows Update Reboot  
 } elseif ((Get-Item -Path "REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue) -ne $null) {  
      $b="Reboot pending"
 #Pending Files Rename Reboot  
 } elseif ((Get-ItemProperty -Path "REGISTRY::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -ErrorAction SilentlyContinue) -ne $null) {  
      $c="Reboot pending"
 #Pending SCCM Reboot  
 } elseif ((([wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities").DetermineIfRebootPending().RebootPending) -eq $true) {  
      $d="Reboot pending"
 }
 If (($a -eq "Reboot pending") -or ($b -eq "Reboot pending") -or ($c -eq "Reboot pending") -or ($d -eq "Reboot pending"))
 {
 #shutdown -r -f -t 60 
 write-host "Yes"
 }