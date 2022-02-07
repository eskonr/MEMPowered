<#
Name:Audit Azure AD app registration credential expiry
Dated:Feb-07-2022
Original script: https://docs.microsoft.com/en-us/azure/active-directory/manage-apps/scripts/powershell-export-all-app-registrations-secrets-and-certs 
Author: Eswar Koneti @eskonr
#>
$scriptpath = $MyInvocation.MyCommand.Path
$directory = Split-Path $scriptpath
$date = (Get-Date -f dd-MM-yyyy-hhmmss)
$outfile="$directory\AADAppsnearexpiry_$date.csv"

#Email notification part at the end of the script.


#If you want to run the script in unattended , you will need to store the account credetials securely in key file and pass it while connecting to azure AD.
<#
#Store the account password in the key file, run line 22 only to store the password and change the dir location.
#Read-Host -Prompt "Enter your tenant password" -AsSecureString | ConvertFrom-SecureString | Out-File "Dir\o365.key"
$TenantUname = "username@domain.com"
$TenantPass = cat ""Dir\o365.key" | ConvertTo-SecureString
$TenantCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $TenantUname,$TenantPass
#>

if (!(Get-Module azureadpreview))
{
	Write-host "There are no Azure AD modules installed, Installing the Azure AD module" -ForegroundColor Red
	Install-module -Name azureadpreview -ErrorAction SilentlyContinue
	Import-module -Name azureadpreview -ErrorAction SilentlyContinue
	if (!(Get-Module azureadpreview))
	{
		Write-host "couldnt able to install Azure AD Module" -ForegroundColor Red
		break
	}
	else
	{
		Write-host "Azure AD module installed, Continue Script"
	}
}
if (Get-Module azureadpreview)
{
	try
	{
		Connect-AzureAD #-Credential $TenantCredentials
	}
	catch [System.Exception]
	{
		$WebReqErr = $error[0] | Select-Object * | Format-List -Force
		Write-Error "An error occurred while attempting to connect to the requested service. The error was $WebReqErr.Exception"
	}
}
$Applications = Get-AzureADApplication -all $true
$Logs = @()
$Days = "30"
$AlreadyExpired ="Yes"
$now = get-date
foreach ($app in $Applications) {
$AppName = $app.DisplayName
$AppID = $app.objectid
$ApplID = $app.AppId
$AppCreds = Get-AzureADApplication -ObjectId $AppID | select PasswordCredentials, KeyCredentials
$secret = $AppCreds.PasswordCredentials
$cert = $AppCreds.KeyCredentials
foreach ($s in $secret) {
    $StartDate = $s.StartDate
    $EndDate = $s.EndDate
    $operation = $EndDate - $now
    $ODays = $operation.Days

    if ($AlreadyExpired -eq "No") {
        if ($ODays -le $Days -and $ODays -ge 0) {

            $Owner = Get-AzureADApplicationOwner -ObjectId $app.ObjectId
            $Username = $Owner.UserPrincipalName -join ";"
            $OwnerID = $Owner.ObjectID -join ";"
            if ($owner.UserPrincipalName -eq $Null) {
                $Username = $Owner.DisplayName + " **<This is an Application>**"
            }
            if ($Owner.DisplayName -eq $null) {
                $Username = "<<No Owner>>"
            }

            $Log = New-Object System.Object

            $Log | Add-Member -MemberType NoteProperty -Name "ApplicationName" -Value $AppName
            $Log | Add-Member -MemberType NoteProperty -Name "ApplicationID" -Value $ApplID
            $Log | Add-Member -MemberType NoteProperty -Name "Secret Start Date" -Value $StartDate
            $Log | Add-Member -MemberType NoteProperty -Name "Secret End Date" -value $EndDate
            $Log | Add-Member -MemberType NoteProperty -Name "Certificate Start Date" -Value $Null
            $Log | Add-Member -MemberType NoteProperty -Name "Certificate End Date" -value $Null
            $Log | Add-Member -MemberType NoteProperty -Name "Owner" -Value $Username
            $Log | Add-Member -MemberType NoteProperty -Name "Owner_ObjectID" -value $OwnerID

            $Logs += $Log
        }
    }
    elseif ($AlreadyExpired -eq "Yes") {
        if ($ODays -le $Days) {
            $Owner = Get-AzureADApplicationOwner -ObjectId $app.ObjectId
            $Username = $Owner.UserPrincipalName -join ";"
            $OwnerID = $Owner.ObjectID -join ";"
            if ($owner.UserPrincipalName -eq $Null) {
                $Username = $Owner.DisplayName + " **<This is an Application>**"
            }
            if ($Owner.DisplayName -eq $null) {
                $Username = "<<No Owner>>"
            }

            $Log = New-Object System.Object

            $Log | Add-Member -MemberType NoteProperty -Name "ApplicationName" -Value $AppName
            $Log | Add-Member -MemberType NoteProperty -Name "ApplicationID" -Value $ApplID
            $Log | Add-Member -MemberType NoteProperty -Name "Secret Start Date" -Value $StartDate
            $Log | Add-Member -MemberType NoteProperty -Name "Secret End Date" -value $EndDate
            $Log | Add-Member -MemberType NoteProperty -Name "Certificate Start Date" -Value $Null
            $Log | Add-Member -MemberType NoteProperty -Name "Certificate End Date" -value $Null
            $Log | Add-Member -MemberType NoteProperty -Name "Owner" -Value $Username
            $Log | Add-Member -MemberType NoteProperty -Name "Owner_ObjectID" -value $OwnerID

            $Logs += $Log
        }
    }
}

foreach ($c in $cert) {
    $CStartDate = $c.StartDate
    $CEndDate = $c.EndDate
    $COperation = $CEndDate - $now
    $CODays = $COperation.Days

    if ($AlreadyExpired -eq "No") {
        if ($CODays -le $Days -and $CODays -ge 0) {

            $Owner = Get-AzureADApplicationOwner -ObjectId $app.ObjectId
            $Username = $Owner.UserPrincipalName -join ";"
            $OwnerID = $Owner.ObjectID -join ";"
            if ($owner.UserPrincipalName -eq $Null) {
                $Username = $Owner.DisplayName + " **<This is an Application>**"
            }
            if ($Owner.DisplayName -eq $null) {
                $Username = "<<No Owner>>"
            }

            $Log = New-Object System.Object

            $Log | Add-Member -MemberType NoteProperty -Name "ApplicationName" -Value $AppName
            $Log | Add-Member -MemberType NoteProperty -Name "ApplicationID" -Value $ApplID
            $Log | Add-Member -MemberType NoteProperty -Name "Certificate Start Date" -Value $CStartDate
            $Log | Add-Member -MemberType NoteProperty -Name "Certificate End Date" -value $CEndDate
            $Log | Add-Member -MemberType NoteProperty -Name "Owner" -Value $Username
            $Log | Add-Member -MemberType NoteProperty -Name "Owner_ObjectID" -value $OwnerID

            $Logs += $Log
        }
    }
    elseif ($AlreadyExpired -eq "Yes") {
        if ($CODays -le $Days) {

            $Owner = Get-AzureADApplicationOwner -ObjectId $app.ObjectId
            $Username = $Owner.UserPrincipalName -join ";"
            $OwnerID = $Owner.ObjectID -join ";"
            if ($owner.UserPrincipalName -eq $Null) {
                $Username = $Owner.DisplayName + " **<This is an Application>**"
            }
            if ($Owner.DisplayName -eq $null) {
                $Username = "<<No Owner>>"
            }

            $Log = New-Object System.Object

            $Log | Add-Member -MemberType NoteProperty -Name "ApplicationName" -Value $AppName
            $Log | Add-Member -MemberType NoteProperty -Name "ApplicationID" -Value $ApplID
            $Log | Add-Member -MemberType NoteProperty -Name "Certificate Start Date" -Value $CStartDate
            $Log | Add-Member -MemberType NoteProperty -Name "Certificate End Date" -value $CEndDate
            $Log | Add-Member -MemberType NoteProperty -Name "Owner" -Value $Username
            $Log | Add-Member -MemberType NoteProperty -Name "Owner_ObjectID" -value $OwnerID

            $Logs += $Log
        }
    }
}
}
$Logs | Export-CSV $outfile -NoTypeInformation -Encoding UTF8
$CutoffDate = (get-date).AddDays(30)
if ($Logs)
{
$Data=Import-Csv $outfile | Where-Object {($_.'Secret End Date' -as [datetime] -lt $CutoffDate -and $_.'Secret End Date' -ne '') -or ( $_.'Certificate End Date' -as [datetime] -lt $CutoffDate -and $_.'Certificate End Date' -ne '')}
foreach ($d in $data)
{
$appname1=$d.ApplicationName
$secretend1=$d.'Secret End Date'
$certend1=$d.'Certificate End Date'
<#
By default, if you use function or any other standard account to create the app registration, the account will be stamped as the the owner.
if your org allows user to create their own or follow the process to create the app onbehalf users, then this account will be common for all apps.
In Such cases, you may have to improve the process to update the app owner info with the Distribution list or user name so that when the app is near expiry, a notification will be sent.
#>

if($d.Owner -eq 'fid0365@eskonr.com' -or $d.Owner -eq $null ) {$Owner1="eswar.kon@eskonr.com"}
$From = "o365automation@eskonr.com"
$smtp="SMTP details"
$To = $Owner1
$Subject = "Your o365 app secret key or cert is expiring in the next 30 days"
$Body = "Hi,
we have identified that, you are the owner of the app:$appname1 created in Azure AD and its secret key or certificate expiring in the next 30 days.

Please review, renew the application. If the application is not used anymore, please raise a request to decom/remove the application from Azure AD portal.

The following are the details of Secret Key and Certificate
Secret Key Expiration Date=$secretend1
Certificate End Date=$certend1

Ignoring the messages may cause your application not function properly.

Thanks,
xxxxx Team
P.S: This is automated generated email. Please do not respond to this email.
"
Send-MailMessage -From $From -To $To -SmtpServer $smtp -Subject $Subject -Body $Body
}

}