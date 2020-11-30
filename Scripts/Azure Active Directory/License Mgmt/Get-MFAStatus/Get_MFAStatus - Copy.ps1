<#
Title:Get MFA Status for users who got o365 license
Use this script to get the license information from o365 using stored credential .
Author:Eswar Koneti
Date:26-Feb-2018
#>

#Read-Host -Prompt "Enter your tenant password" -AsSecureString | ConvertFrom-SecureString | Out-File "C:\Temp\Scripts\Automation\o365.key"

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$date = (get-date -f dd-MM-yyyy-hhmmss)
$Outfile = "$dir\MFA Status-"+$date+".csv"
    Import-Module MSOnline
    $TenantUname = "eswar@eswar.com"
    $TenantPass = cat "C:\Temp\Scripts\Automation\o365.key" | ConvertTo-SecureString
    $TenantCredentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $TenantUname, $TenantPass
    Connect-MsolService -Credential $TenantCredentials

$MFAUsers=Get-MsolUser -all |Where {$_.IsLicensed -eq $true } #-and $_.UserPrincipalName -like 'prudential.co.id*'} 
if ($MFAUsers) { Write-Host "Found $($MFAUsers.Count) Users which are enabled with license" -ForegroundColor Green } else {Write-Host "No MFA Users were found, exiting." -ForegroundColor Red; exit}
 
# Setting Array to gather Users Information
$Results = @()
$UserCounter = 1

# Running on MFA Enabled All Users
Write-Host "Processing Invdividual Users, please wait" -ForegroundColor Green
foreach ($User in $MFAUsers)
{
    #Write-Host "Processing #$UserCounter Out Of #$($MFAUsers.Count): Working on User $($User.UserPrincipalName)" -ForegroundColor Cyan
    $UserCounter +=1
    
    $StrongAuthenticationRequirements = $User | Select-Object -ExpandProperty StrongAuthenticationRequirements
    $StrongAuthenticationUserDetails = $User | Select-Object -ExpandProperty StrongAuthenticationUserDetails
    $StrongAuthenticationMethods = $User | Select-Object -ExpandProperty StrongAuthenticationMethods
 
    $Results += New-Object PSObject -property @{ 
    DisplayName = $User.DisplayName -replace "#EXT#","" 
    UserPrincipalName = $user.UserPrincipalName -replace "#EXT#","" 
   # IsLicensed = $user.IsLicensed
    MFAState = $StrongAuthenticationRequirements.State
   # RememberDevicesNotIssuedBefore = $StrongAuthenticationRequirements.RememberDevicesNotIssuedBefore
    PhoneNumber = $StrongAuthenticationUserDetails.PhoneNumber
   # Email = $StrongAuthenticationUserDetails.Email
    MFAType = ($StrongAuthenticationMethods | Where {$_.IsDefault -eq $True}).MethodType
      }

}
 
# Select Users Details and export to CSV
#Write-Host "Exoprting Details to CSV..." -ForegroundColor Green
$Results | Select-Object `
            DisplayName, `
            UserPrincipalName, `
          #  IsLicensed, `
            MFAState, `
         #   RememberDevicesNotIssuedBefore, `
            PhoneNumber, `
          #  Email, `
            MFAType `
          | Export-Csv -NoTypeInformation $Outfile -Force