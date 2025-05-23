<#
.SYNOPSIS
    This scripts export the list of all Windows workstations active last 45 days and send it to Log analytics for data manipulation

.DESCRIPTION
    This script requires to run from domain joined computer that is connected to Manulife network.
    this script requires Active directory module to be loaded.

.NOTES
Created by Eswar Koneti
Dated: 16-Oct-2024
#>

#region initialize
# Enable TLS 1.2 support
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# Replace with your Log Analytics Workspace ID
$CustomerId = "fbc19b46-09ed-4a4f-5565656-8b8ea60565656565656"

# Replace with your Primary Key
$SharedKey = "dfdfdfdfdfjq2iPmUh8/rgxBUxlxZCOrfm4PT6BS0DleQPdfdgfggTSm0p9RfgfgfgfgHKFYMG8Wlr+ZzvFtQ=="

#Control if you want to collect App or Device Inventory or both (True = Collect)
$CollectADWindowsInfo = $true
$ADWindowsInfoLogName = "ADWindowsData"
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
}
#end function
$global:a_PSModules=@()
$a_PSModules += New-Object PSObject -Property @{Name = "ActiveDirectory"; MinVer = "1.0.1"; ModuleToUpdate=""}
#End of Module Load
$a_IgnoreTheseOUs=@()
<#
OUs that, if the object is currently there, means stale object, migration exempt, already begun or completed.
#>
$a_IgnoreTheseOUs += "OU=Disabled Computers,DC=eskonr,DC=com"
#Asia (Non-Japan)
$a_IgnoreTheseOUs += "OU=M2,OU=Win11,OU=Asia,OU=MDM Managed Computers,DC=eskonr,DC=com"
$a_IgnoreTheseOUs += "OU=Physical,OU=Windows,OU=Asia,OU=MDM Managed Computers,DC=eskonr,DC=com"
#Asia (Japan)
$a_IgnoreTheseOUs += "OU=M1,OU=Win11,OU=Asia,OU=MDM Managed Computers,DC=eskonr,DC=com"
$a_IgnoreTheseOUs += "OU=Physical Japan,OU=Windows,OU=Asia,OU=MDM Managed Computers,DC=eskonr,DC=com"
#North America
$a_IgnoreTheseOUs += "OU=M1,OU=Win11,OU=North America,OU=MDM Managed Computers,DC=eskonr,DC=com"
$a_IgnoreTheseOUs += "OU=M2,OU=Win11,OU=North America,OU=MDM Managed Computers,DC=eskonr,DC=com"
$a_IgnoreTheseOUs += "OU=Physical,OU=Windows,OU=North America,OU=MDM Managed Computers,DC=eskonr,DC=com"

$a_InScopeDeviceNamePrefixes=@()
<#
Prefixes of device names that are in scope for us to migrate
#>
# Canada, US and UK region
$a_InScopeDeviceNamePrefixes += "BE"
$a_InScopeDeviceNamePrefixes += "BM"
$a_InScopeDeviceNamePrefixes += "CA"
$a_InScopeDeviceNamePrefixes += "IE"
$a_InScopeDeviceNamePrefixes += "GB"
$a_InScopeDeviceNamePrefixes += "US"
#Asia region
$a_InScopeDeviceNamePrefixes += "CN"
$a_InScopeDeviceNamePrefixes += "HK"
$a_InScopeDeviceNamePrefixes += "ID"
$a_InScopeDeviceNamePrefixes += "JP"
$a_InScopeDeviceNamePrefixes += "MM"
$a_InScopeDeviceNamePrefixes += "MY"
$a_InScopeDeviceNamePrefixes += "PH"
$a_InScopeDeviceNamePrefixes += "VN"
$a_InScopeDeviceNamePrefixes += "KH"
$a_InScopeDeviceNamePrefixes += "SG"
$a_InScopeDeviceNamePrefixes += "TW"

$i_DaysDisabled=45
$o_StaleDate = (Get-Date).AddDays(-45)
$s_Domain="eskonr.com"
$s_DomainConnection=$s_Domain + ":389"
$s_ScriptVer="20.24.001"

#Function section ------------------------------------------------------------------
Clear-Host
$MyDir = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
Set-Location "$MyDir"

#Get the current time
$o_ScriptLaunchTime=Get-Date

#Get Date mask
$s_DateMask=$o_ScriptLaunchTime.ToString("yyyy_MM_dd")

#Ensure output folder is created
$s_Folder="$MyDir\" + "$s_DateMask"
If (!(Test-Path -path $s_Folder))
    {
    #Folder does not exist
    New-Item $s_Folder -type directory | Out-Null
    }
#Set outputfilename
$s_OutfileADInScope="$s_Folder\ADDevicesInScope" + "_$s_DateMask.csv"
Write-Host "** Connection to Manulife internal network is required or script will fail! **" -ForegroundColor Yellow
Write-Host ""
#### Config Don't change
$o_Start=Get-Date
Write-host "Reading all Windows-based device objects from AD domain `'$s_Domain`'..."
$o_Start=Get-Date
Write-Host "     Started: $o_Start"
#Get the info from AD, and save property 'Name' as "DeviceName" so we may use the Compare-object Cmdlet, below
$a_ComputerList = @(Get-ADComputer -Filter 'operatingSystem -notlike "*Server*"' -Properties Name, DistinguishedName, OperatingSystem, LastLogonDate, Enabled -ErrorAction SilentlyContinue |
Where-Object {
    ($null -ne $_.LastLogonDate) -and
    ($_.LastLogonDate -gt $o_StaleDate) -and
    ($_.Enabled -eq $True) -and
    $_.DistinguishedName -notlike "*server*" -and
    $_.DistinguishedName -notlike "*Disabled Computers*" -and
    $_.OperatingSystem -like "*Windows*" -and
    $_.Name.Substring(0,2) -in $a_InScopeDeviceNamePrefixes
} | Select-Object @{Name="DeviceName";Expression={$_.Name}},
                  @{Name="OU";Expression={$_.DistinguishedName -replace "^CN=$($_.Name),"}},
                  @{Name="OperatingSystem";Expression={$_.OperatingSystem}},
                  @{Name="LastLogonDate";Expression={$_.LastLogonDate.ToString("dd-M-yyyy")}}
                  )

$o_End=Get-Date
Write-Host "     Ended: $o_End"
#Sort
$a_ComputerList = $a_ComputerList | Sort-Object -Property DeviceName
#Keep only those objects not in the Ignored OUs
Write-host ""
Write-host "Exporting the list of all windows workstations from AD..."
#$a_ComputerListInScope=@($a_ComputerList | Where-Object {$PSItem.DeviceName.Substring(0,2) -in $a_InScopeDeviceNamePrefixes -and -not(($PSItem.DistinguishedName -replace 'CN=[^,]+,', '') -in $a_IgnoreTheseOUs)} #This helps to ignore the devices from specific OU listed above
$a_ComputerList | Sort-Object -Property DeviceName | Export-Csv -Path $s_OutfileADInScope -NoTypeInformation -Encoding UTF8
$o_Now=Get-Date
#$o_TotalElapsed=New-TimeSpan -Start $o_ScriptLaunchTime -End $o_Now
#Write-Host "Total script runtime: $($o_TotalElapsed.Days) DD, $($o_TotalElapsed.Hours) HH, $($o_TotalElapsed.Minutes) MM, $($o_TotalElapsed.Seconds) SS."

$ADWindowsInfoJson = $a_ComputerList | ConvertTo-Json

if ($CollectADWindowsInfo) {

# Sending the data to Log Analytics Workspace
# Submit the data to the API endpoint
#$ResponseADWindowsInfo = Send-LogAnalyticsData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($ADWindowsInfoJson)) -logType $ADWindowsInfoLogName

#Report back status
$date = Get-Date -Format "dd-MM HH:mm"
$OutputMessage = "InventoryDate:$date "

    if ($ResponseADWindowsInfo -match "200 :") {

        $OutputMessage = $OutPutMessage + "ADDeviceInfo:OK " + $ResponseADWindowsInfo
    }
    else {
        $OutputMessage = $OutPutMessage + "ADDeviceInfo:Fail "
    }
}

Write-Output $OutputMessage
Exit 0
#endregion script

