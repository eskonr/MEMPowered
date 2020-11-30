#Read-Host -Prompt "Enter your tenant password" -AsSecureString | ConvertFrom-SecureString | Out-File "C:\Temp\Scripts\Automation\o365.key"
$scriptPath = $script:MyInvocation.MyCommand.Path
$CD = Split-Path $scriptpath
$date = (get-date -f dd-MM-yyyy-hhmmss)
Import-Module MSOnline
$TenantUname = "keswar@eswar.com"
$TenantPass = cat "C:\Temp\Scripts\Automation\o365.key" | ConvertTo-SecureString
$TenantCredentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $TenantUname, $TenantPass
Connect-MsolService -Credential $TenantCredentials
Get-MsolUser -All |Where {$_.IsLicensed -eq $true } |Select DisplayName,SigninName,Title,Department,UsageLocation,@{n="Licenses Type";e={$_.Licenses.AccountSKUid}} | Export-Csv -Path "$CD\O365UserLicenseInfo-$date.csv"  -NoTypeInformation
