<#
.SYNOPSIS
    Collect Asia Active Users data from Active Directory and send it to Log analytics for Mobile data comparision.

.DESCRIPTION
    This script will collect active users with employee type Y from Asia country and send it to log analytics (intune)
    This script requires to run from domain joined computer that is connected to Manulife network.
    this script requires Active directory module to be loaded.

.EXAMPLE
    Invoke-ActiveUsers.ps1

.NOTES
Created by Eswar Koneti
Dated: 03-May-2024
#>

#region initialize
# Enable TLS 1.2 support
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# Replace with your Log Analytics Workspace ID
$CustomerId = "dfgfdgfgg-09ed-4a4f-8e45-8b8ea6013232"

# Replace with your Primary Key
$SharedKey = "fgfgfgfgfgOjq2iPmUh8/rgxBUxlxZCOrfm4PT6BS0DleQP41eYULZpsTSm0p9RvnSVJHKFYMG8Wlr+ZzvFtQ=="

#Control if you want to collect App or Device Inventory or both (True = Collect)
$CollectAsiaUsers = $true
$AsiaUsersLogName = "AsiaUsers"
$Date = (Get-Date)
# You can use an optional field to specify the timestamp from the data. If the time field is not specified, Azure Monitor assumes the time is the message ingestion time
# DO NOT DELETE THIS VARIABLE. Recommened keep this blank.
$TimeStampField = ""

#endregion initialize

# Function to send data to log analytics
Function Send-LogAnalyticsData() {
	<#
   .SYNOPSIS
	   Send log data to Azure Monitor by using the HTTP Data Collector API

   .DESCRIPTION
	   Send log data to Azure Monitor by using the HTTP Data Collector API

   .NOTES

   #>
   param(
	   [string]$sharedKey,
	   [array]$body,
	   [string]$logType,
	   [string]$customerId
   )
   #Defining method and datatypes
   $method = "POST"
   $contentType = "application/json"
   $resource = "/api/logs"
   $date = [DateTime]::UtcNow.ToString("r")
   $contentLength = $body.Length
   #Construct authorization signature
   $xHeaders = "x-ms-date:" + $date
   $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource
   $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
   $keyBytes = [Convert]::FromBase64String($sharedKey)
   $sha256 = New-Object System.Security.Cryptography.HMACSHA256
   $sha256.Key = $keyBytes
   $calculatedHash = $sha256.ComputeHash($bytesToHash)
   $encodedHash = [Convert]::ToBase64String($calculatedHash)
   $signature = 'SharedKey {0}:{1}' -f $customerId, $encodedHash

   #Construct uri
   $uri = "https://" + $customerId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"

   #validate that payload data does not exceed limits
   if ($body.Length -gt (31.9 *1024*1024))
   {
	   throw("Upload payload is too big and exceed the 32Mb limit for a single upload. Please reduce the payload size. Current payload size is: " + ($body.Length/1024/1024).ToString("#.#") + "Mb")
   }
   $payloadsize = ("Upload payload size is " + ($body.Length/1024).ToString("#.#") + "Kb ")

   #Create authorization Header
   $headers = @{
	   "Authorization"        = $signature;
	   "Log-Type"             = $logType;
	   "x-ms-date"            = $date;
	   "time-generated-field" = $TimeStampField;
   }
   #Sending data to log analytics
   $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
   $statusmessage = "$($response.StatusCode) : $($payloadsize)"
   return $statusmessage
}#end function

# Define an array of the distinguished names for the OUs
$OUs = @(
    "OU=Users,OU=Cambodia,OU=Global,DC=eskonr,DC=com",
    "OU=Users,OU=China,OU=Global,DC=eskonr,DC=com",
    "OU=Users,OU=Hong Kong,OU=Global,DC=eskonr,DC=com",
    "OU=Users,OU=Indonesia,OU=Global,DC=eskonr,DC=com",
    "OU=Users,OU=Japan,OU=Global,DC=eskonr,DC=com",
    "OU=Users,OU=Malaysia,OU=Global,DC=eskonr,DC=com",
    "OU=Users,OU=Manila,OU=Global,DC=eskonr,DC=com",
    "OU=Users,OU=MITDC,OU=Global,DC=eskonr,DC=com",
    "OU=Users,OU=Myanmar,OU=Global,DC=eskonr,DC=com",
    "OU=Users,OU=Singapore,OU=Global,DC=eskonr,DC=com",
    "OU=Users,OU=Vietnam,OU=Global,DC=eskonr,DC=com"
)

# Initialize an array to hold all users' data
$AllUsersData = @()

# Loop through each OU and get the active users
foreach ($OU in $OUs) {
    $UsersData = Get-ADUser -Filter {(Enabled -eq $true)} -SearchBase $OU -Properties Name,UserPrincipalName,EmailAddress,whenCreated, Title, co, Department, Manager  -ErrorAction SilentlyContinue |
    Select-Object -Property Name,UserPrincipalName, @{Name="CreatedDate";Expression={$_.whenCreated.ToString("dd-M-yyyy")}}, Title, Co, EmailAddress, Department, @{Name="Manager";Expression={(Get-ADUser $_.Manager).Name}}

    # Add the users' data to the all users array
    $AllUsersData += $UsersData
}
#Convert the data to Json format
$AsiaUsersJson = $AllUsersData | ConvertTo-Json

# Sending the data to Log Analytics Workspace
# Submit the data to the API endpoint
#$ResponseAsiaUsers = Send-LogAnalyticsData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($AsiaUsersJson)) -logType $AsiaUsersLogName

#Report back status
$date = Get-Date -Format "dd-MM HH:mm"
$OutputMessage = "InventoryDate:$date "


if ($CollectAsiaUsers) {
    if ($ResponseAsiaUsers -match "200 :") {

        $OutputMessage = $OutPutMessage + "AsiaUsers:OK " + $ResponseAsiaUsers
    }
    else {
        $OutputMessage = $OutPutMessage + "AsiaUsers:Fail "
    }
}

Write-Output $OutputMessage
Exit 0
#endregion script