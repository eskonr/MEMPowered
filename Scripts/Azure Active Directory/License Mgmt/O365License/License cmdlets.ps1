

#get users count with usage location is NULL

(Get-MsolUser -All | where {$_.UsageLocation -eq $null}).count
#get users with users location is NULL
Get-MsolUser -All | where {$_.UsageLocation -eq $null}

#to set usage location
Set-MsolUser -UserPrincipalName "<Account>" -UsageLocation <CountryCode>

#remove o365 license for specific SKU ID:
Set-MsolUserLicense -UserPrincipalName belindan@litwareinc.com -RemoveLicenses "litwareinc:ENTERPRISEPACK"
#to remove o365 license for multiple users from notepad
Get-Content "C:\My Documents\Accounts.txt" | ForEach { Set-MsolUserLicense -UserPrincipalName $_ -RemoveLicenses "litwareinc:ENTERPRISEPACK" }
#removes the litwareinc:ENTERPRISEPACK (Office 365 Enterprise E3) license from all existing licensed user accounts.
    $x = Get-MsolUser -All  | Where {$_.isLicensed -eq $true}
$x | ForEach {Set-MsolUserLicense -UserPrincipalName $_.UserPrincipalName -RemoveLicenses "litwareinc:ENTERPRISEPACK"}