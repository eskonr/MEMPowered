
<#
Title:Get the license type either direct or group based

'.\all-users-with-license-type.ps1'  |Export-Csv  "C:\C:\Temp\eswar\Scripts\Automation\O365 License type Direct Groupbased\ExportAllUser.csv"  -NoTypeInformation  

  '.\all-users-with-license-type.ps1' | Where-Object {$_.UserPrincipalName -like  "Admin@modxxxxx.onmicrosoft.com"}

  '.\all-users-with-license-type.ps1' | Where-Object {$_.UserPrincipalName -like "Admin@modxxxxx.onmicrosoft.com"  -or $_.UserPrincipalName -like "testuser1@modxxxx.onmicrosoft.com"}

https://www.jijitechnologies.com/blogs/how-to-list-all-o365-users-with-license-type-using-powershell
Author:Eswar Koneti
Date:17-Aug-2019
#>

#Read-Host -Prompt "Enter your tenant password" -AsSecureString | ConvertFrom-SecureString | Out-File "C:\Temp\eswar\Scripts\Automation\o365.key"

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$date = (get-date -f dd-MM-yyyy-hhmmss)
$inputfile = "$dir\RemoveLicense.txt"
$Outfile = "$dir\licensetype-"+$date+".csv"
$TenantUname = "keswar@eswar.com"
$TenantPass = cat "C:\Temp\eswar\Scripts\Automation\o365.key" | ConvertTo-SecureString
$TenantCredentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $TenantUname, $TenantPass

  #  Connect-MsolService -Credential $TenantCredentials
    $Gplist= @{}
    $Group =Get-msolgroup -all
    # Get all groupname with group objectId
    foreach($gp in $Group)
    {
    $Gplist+=@{$gp.ObjectId.ToString() = $gp.DisplayName}
    }
    $users= Get-MsolUser -All
    $AllUser = @()
    # Find Users License Type 
    foreach($user in $users)
    {
        $UserList = "" | Select "UserPrincipalName","LicenseType"  
        $lic=$user.Licenses.GroupsAssigningLicense.Guid
        if($lic -ne $null)
        {
         $GpName = ''
         foreach($lc in $lic)
         {
            If($GpName) {
                         if($Gplist.Item($lc.ToString()) -ne $null)
                         {
                         $GpName=$GpName + ";" + $Gplist.Item($lc.ToString())
                         }
                     } 
                Else {
                        if($Gplist.Item($lc.ToString()) -ne $null)
                         {
                         $GpName=$Gplist.Item($lc.ToString())
                         }
                      }          
          }
          $UserList.UserPrincipalName = $user.UserPrincipalName
          $UserList.LicenseType = "Inherited("+$GpName+")"
          $AllUser+= $UserList
          $UserList =$null
 
        }
 
        Else
        {
        $UserList.UserPrincipalName = $user.UserPrincipalName
        $UserList.LicenseType = "Direct"
        $AllUser+= $UserList
        $UserList =$null
 
        }
    }
$AllUser | Out-File $Outfile -append
