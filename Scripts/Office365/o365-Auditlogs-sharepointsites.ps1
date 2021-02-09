<#

Script:Audit logs for list of sharepoint sites.

Author: Eswar Koneti

Description: This script will read through the list of sharepoint sites, generate the output and send the report as an email to the recipients.

Twitter:@eskonr

Reference: https://docs.microsoft.com/en-us/microsoft-365/compliance/search-the-audit-log-in-security-and-compliance?view=o365-worldwide#step-1-run-an-audit-log-search

#>

#Get the script path

$dir = Split-Path $script:MyInvocation.MyCommand.Path

#Get the current date

$date = (Get-Date -f dd-MM-yyyy-hhmmss)

#Store the outputfile

$CSVFile = "$dir\Auditlogs_$date.csv"

#Details for sending email

$From = "o365@eskonr.com"

$To = "test1@eskonr.com","test2@eskonr.com","test3@eskonr.com"

$CC ="demo1@eskonr.com"

$smtp = "outlook.office365.com"

$Subject = "Sharepoint audit logs"

#Whom to notify incase of connection to exchange online module fails. This will be the task owner.

$notify="xxxxxxxx@eskonr.com"

$Body = "Hi Team,

Please find the audit logs for the following sharepoint sites for the last x days.

https://eswar.sharepoint.com/sites/Technology

https://eswar.sharepoint.com/sites/Marketting

https://eswar.sharepoint.com/sites/INIT

Thanks,

O365 Team

"

#Create a backup folder and move all the old files to it.

$destination = "$dir\Backup"

$Move = Get-ChildItem -Path "$dir\Auditlogs_*.csv" #| Sort-Object LastWriteTime -Descending | Select-Object -Skip 1

foreach ($file in $Move) {

  $parent = Split-Path $file.FullName -Parent

  Move-Item $file.FullName -Destination $destination -Force

}

#store the o365 credentials

$TenantUname = "xxxxx@eskonr.com"

#Run the following single line to store the password of account that will be used to connect to o365 exchange online

#Read-Host -Prompt "Enter your tenant password" -AsSecureString | ConvertFrom-SecureString | Out-File "foldername\O365.key"

#Replace the o365 key file that you stored the password.

$TenantPass = cat "foldername\O365.key" | ConvertTo-SecureString

$TenantCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $TenantUname,$TenantPass

#make sure the exchangeonline module is installed. The script will fail if module not installed.

Import-Module ExchangeOnlineManagement

try {

Connect-ExchangeOnline -Credential $TenantCredentials

}

catch [System.Exception]

{

$ErrorMessage = $_.Exception.Message

          $FailedItem = $_.Exception.ItemName

          $WebReqErr = $error[0] | Select-Object * | Format-List -Force

  Write-Error "An error occurred while attempting to connect to the requested service.  $ErrorMessage"

  Send-MailMessage -From $From -To  $notify -SmtpServer $smtp -Subject "Failed to connect to exchnage online" -Body "Please check ."

}

#list of sharepoint sites (* means all sub sites as well)

$SiteURLs = @("https://eswar.sharepoint.com/sites/Technology/*",

"https://eswar.sharepoint.com/sites/Marketting/*",

"https://eswar.sharepoint.com/sites/INIT/*")

#List of audit logs

#For a list of audit logs, refer https://docs.microsoft.com/en-us/microsoft-365/compliance/search-the-audit-log-in-security-and-compliance?view=o365-worldwide#file-and-page-activities

$Operations = @('PageViewed','FileAccessed','FileDownloaded','FileDeleted')

#audit logs for 15 days from today's date

$startDate=(Get-Date).AddDays(-15)

#Number of iterations (split them to 5 days because of the resultsize is 5K)

$daysToSkip=3

$endDate=Get-Date #today's date

#iteration start for 3 days

     while ($startDate -lt $endDate) {

        $startdate1=$startDate

        $startDate = $startDate.AddDays($daysToSkip)

        $enddate1=$startDate

$FileAccessLog = Search-UnifiedAuditLog -StartDate $startDate1 -EndDate $EndDate1 -Operations $Operations -ResultSize 5000 -ObjectIds $SiteURLs

$FileAccessLog.auditdata | ConvertFrom-Json | Select-Object CreationTime,UserId,Operation,ObjectID,SiteUrl,SourceFileName,ClientIP | `

   Export-Csv $CSVFile -NoTypeInformation -Force -Append

        }

   if ((import-csv $CSVFile).Length -gt 0)

   {

    Send-MailMessage -From $From -To $To -SmtpServer $smtp -Subject $Subject -Body $Body -Attachments $CSVFile

}
