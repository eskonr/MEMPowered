<#
Title:Remove direct license assignment using Graph.
https://docs.microsoft.com/en-us/office365/enterprise/powershell/remove-licenses-from-user-accounts-with-office-365-powershell
Before you remove ,make sure your users not using o365 services or they are assigned with group based license.
Author:Eswar Koneti
Date:17-Aug-2019
#>
#Read-Host -Prompt "Enter your tenant password" -AsSecureString | ConvertFrom-SecureString | Out-File "C:\Temp\Scripts\Automation\o365.key"
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$date = (get-date -f dd-MM-yyyy-hhmmss)
$inputfile = "$dir\RemoveLicense.txt"
$Outfile = "$dir\o365licenseremoval-Direct-"+$date+".csv"
$TenantUname = "keswar@eswar.com"
$TenantPass = cat "C:\Temp\Scripts\Automation\o365.key" | ConvertTo-SecureString
$TenantCredentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $TenantUname, $TenantPass

#Connect-MsolService -Credential $TenantCredentials
connect-AzureAD -Credential $TenantCredentials

$users = Get-Content -Path $inputfile
if($users)
{
foreach ($userUPN in $users)
{
$error.clear()
try {
$planName="ENTERPRISEPREMIUM"
#SPE_E5 
$license =  New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense
$licenses = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
$license.SkuId = (Get-AzureADSubscribedSku | Where-Object -Property SkuPartNumber -Value $planName -EQ).SkuID
$licenses.AddLicenses = $license
Set-AzureADUserLicense -ObjectId $userUPN -AssignedLicenses $licenses
$Licenses.AddLicenses = @()

$Licenses.RemoveLicenses =  (Get-AzureADSubscribedSku | Where-Object -Property SkuPartNumber -Value $planName -EQ).SkuID
Set-AzureADUserLicense -ObjectId $userUPN -AssignedLicenses $licenses
"Removed License for $UserUPN from $planName" | Out-File $Outfile -append
}
catch 
{
"FailedTo remove License for $UserUPN from $planName" | Out-File $Outfile -append
}
}
}

#Set-MsolUserLicense -UserPrincipalName belindan@litwareinc.com -RemoveLicenses "litwareinc:ENTERPRISEPACK"
