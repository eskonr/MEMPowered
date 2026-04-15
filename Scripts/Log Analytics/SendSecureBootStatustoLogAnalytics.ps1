<#
.SYNOPSIS
  Outputs device Secure Boot servicing status, certificate presence, BIOS readiness, and a recommended action, aligned with
  Microsoft guidance for the Windows Secure Boot certificate expiration and CA updates.

  Reference: Windows Secure Boot certificate expiration and CA updates
  https://support.microsoft.com/en-us/topic/windows-secure-boot-certificate-expiration-and-ca-updates-7ff40d33-95dc-4c3c-8725-a9b95457578e

.DESCRIPTION
  This script collects:
  - Device and OS details (version, build, uptime)
  - BIOS version/date and OEM readiness for 2023 Secure Boot certificates
  - Secure Boot state (ON/OFF)
  - Presence of 2023 certs in Active (KEK/DB) and Default (KEK/DB) stores
  - Servicing status from HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing (UEFICA2023Status, Error/Event)
  - Secure Version Number compliance status (if Get-SecureBootSVN is available)

  It derives a simple State and Action for operational decision-making. The script prints a single compressed JSON to stdout and exits with:
  - 0 when Action == 'None' (PASS)
  - 1 otherwise (FAIL)

.NOTES
  - BIOSShippedWith2023Certs is determined using OEM rules:
    * Dell: BIOS release date after 2026-01-01 or minimum version per model list
    * Microsoft Surface: minimum version per model list
    * VMs are treated as compliant for BIOS cert readiness
  - No registry writes or event logging are performed; this is output-only.

  This script is based on Steven H remediation script
#>

#region initialize
# Enable TLS 1.2 support
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# Replace with your Log Analytics Workspace ID
$CustomerId = "fbc19b46-09ed-4a4f-8e45-8b8ea6013232"
# Replace with your Primary Key
$SharedKey = "yUlop+kVDL2Ojq2iPmUh8/rgxBUxlxZCOrfm4PT6BS0DleQP41eYULZpsTSm0p9RvnSVJHKFYMG8Wlr+ZzvFtQ=="

#Control if you want to collect App or Device Inventory or both (True = Collect)
$CollectSecureBootInventory = $true

$AppLogName = "SecureBootCertStatus"
$Date = (Get-Date)

# You can use an optional field to specify the timestamp from the data. If the time field is not specified, Azure Monitor assumes the time is the message ingestion time
# DO NOT DELETE THIS VARIABLE. Recommened keep this blank.
$TimeStampField = ""

#endregion initialize

$startTime = Get-Date

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

#region APPINVENTORY
if ($CollectSecureBootInventory)
{

#Region Variables
# Define Variables
#Uncomment one of the $s_ModeForced values below during debugging.  Values are ignored in production
$s_ModeForced="detect"
#$s_ModeForced="remediate"
#Determine the script mode (detect or remediate) and then name us
$s_Mode = $MyInvocation.MyCommand.Name.Split(".")[0]  #gets the name of the script.  when deployed in Production by Intune Proactive remediation the result is either 'detect' or 'remediate'
#Were we run by Intune, or manually?  If manual, force a mode
if (($s_Mode -ine "detect") -and ($s_Mode -ine "remediate")) {$s_Mode = $s_ModeForced.ToLower()}
$s_MyName="Detection"
$s_MyFunction="SecureBootRenewal"    #e.g. 'EnvironmentVariables'
$s_RegKeyInstallTattoo="HKLM:\Software\Manulife\IntuneManaged" + $s_MyFunction + "History\ProactiveRemediation_$s_MyName"
$s_ScriptVer="20.26.009"

#For dates
$o_AReallyOldDate=([datetime]0).ToUniversalTime()
$o_DellBIOSIsGoodDate=([datetime]::new(2026, 1, 1)).ToUniversalTime()

#Define Dell hardware models and their minimum firmware version to support the 2023 initiative
#Date from https://www.dell.com/support/kbdoc/en-ca/000347876/microsoft-2011-secure-boot-certificate-expiration#:~:text=starting%20June%202026.-,Resolution,new%202023%20Secure%20Boot%20Certificates
$a_DellBios=@()
#Dell and Dell Plus
$a_DellBios += New-Object PSObject -Property @{Model = "Dell 14 DC14250"; Minver = "1.1.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell 14 DC14255"; Minver = "1.4.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell 14 Plus 2-in-1 DB04250"; Minver = "1.6.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell 14 Plus 2-in-1 DB04255"; Minver = "1.4.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell 14 Plus DB14250"; Minver = "1.6.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell 14 Plus DB14255"; Minver = "1.4.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell 14 Premium DA14250"; Minver = "1.3.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell 14 DC14250"; Minver = "1.1.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell 15 DC15250"; Minver = "1.2.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell 15 DC15255"; Minver = "1.3.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell 16 DC16250"; Minver = "1.3.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell 16 DC16251"; Minver = "1.3.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell 16 DC16255"; Minver = "1.0.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell 16 DC16256"; Minver = "1.0.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell 16 Plus 2-in-1 DB06250"; Minver = "1.6.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell 16 Plus DB16250"; Minver = "1.6.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell 16 Plus DB16255"; Minver = "1.4.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell 16 Premium DA16250"; Minver = "1.5.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell 24 All-in-One EC24250"; Minver = "1.7.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "DELL 27 All-in-One EC27250"; Minver = "1.7.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Laptop DC14255"; Minver = "1.4.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Slim ECS1250"; Minver = "1.6.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Tower ECT1250"; Minver = "1.6.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Tower Plus EBT2250"; Minver = "1.8.1"}
#Dell Pro
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro 13 Plus PB13250"; Minver = "2.6.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro 13 Plus PB13255"; Minver = "1.7.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro 13 Premium PA13250"; Minver = "2.6.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro 14 Essential PV14250"; Minver = "1.1.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro 14 Essential PV14255"; Minver = "1.5.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro 14 PC14250"; Minver = "1.7.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro 14 PC14255"; Minver = "1.7.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro 14 Plus PB14250"; Minver = "2.6.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro 14 Plus PB14255"; Minver = "1.7.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro 14 Premium PA14250"; Minver = "2.6.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro 15 Essential PV15250"; Minver = "1.0.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro 15 Essential PV15255"; Minver = "1.2.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro 16 PC16250"; Minver = "1.7.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro 16 PC16255"; Minver = "1.7.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro 16 Plus PB16250"; Minver = "2.6.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro 16 Plus PB16255"; Minver = "1.7.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro 24 All-in-One Plus QB24250"; Minver = "1.8.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro 24 All-in-One QC24250"; Minver = "1.8.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro 24 All-in-One QC24251"; Minver = "1.8.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Laptop PC14250"; Minver = "1.7.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Laptop PC16250"; Minver = "1.7.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Max 14 MC14250"; Minver = "1.7.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Max 14 MC14255"; Minver = "1.2.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Max 14 Premium MA14250"; Minver = "1.4.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Max 16 MC16250"; Minver = "1.7.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Max 16 MC16255"; Minver = "1.2.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Max 16 Plus MB16250"; Minver = "1.3.3"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Max 16 Premium MA16250"; Minver = "1.4.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Max 18 Plus MB18250"; Minver = "1.3.3"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Max Micro FCM2250"; Minver = "1.7.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Max Slim FCS1250"; Minver = "1.7.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Max Tower T2 FCT2250"; Minver = "1.7.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Max with GB10 FCM1253"; Minver = "1.1.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Micro QCM1255"; Minver = "1.4.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Micro QCM1250"; Minver = "1.7.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Micro QCT1255"; Minver = "1.4.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Micro Plus QBM1250"; Minver = "1.7.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Rugged 10 Tablet"; Minver = "1.1.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Rugged 12 Tablet"; Minver = "1.1.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Rugged 13 RA13250"; Minver = "1.9.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Rugged 14 RB14250"; Minver = "1.9.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Slim QCS1255"; Minver = "1.4.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Slim Essential QVS1260"; Minver = "1.8.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Slim Plus QBS1250"; Minver = "1.7.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Slim QCS1250"; Minver = "1.7.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Tower Essential QVT1260"; Minver = "1.8.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Tower QCT1255"; Minver = "1.4.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Tower Plus QBT1250"; Minver = "1.7.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Dell Pro Tower QCT1250"; Minver = "1.7.0"}
#Latitude
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 12 Rugged Extreme 7214"; Minver = "1.52.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3120"; Minver = "1.37.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3140"; Minver = "1.25.5"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3140 2-in-1"; Minver = "1.25.5"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3190"; Minver = "1.42.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3190 2-in-1"; Minver = "1.42.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3301"; Minver = "1.37.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3310"; Minver = "1.31.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3310 2-In-1"; Minver = "1.30.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3320"; Minver = "1.40.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3330"; Minver = "1.32.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3340"; Minver = "1.25.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3400"; Minver = "1.39.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3410"; Minver = "1.36.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3420"; Minver = "1.44.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3430"; Minver = "1.30.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3440"; Minver = "1.25.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3450"; Minver = "1.16.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3500"; Minver = "1.39.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3510"; Minver = "1.36.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3520"; Minver = "1.44.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3530"; Minver = "1.30.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3540"; Minver = "1.25.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 3550"; Minver = "1.16.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5300"; Minver = "1.37.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5300 2-in-1"; Minver = "1.37.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5310"; Minver = "1.30.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5310 2-in-1"; Minver = "1.30.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5320"; Minver = "1.46.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5330"; Minver = "1.32.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5340"; Minver = "1.24.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5350"; Minver = "1.16.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5400"; Minver = "1.41.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5401"; Minver = "1.42.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5410"; Minver = "1.38.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5411"; Minver = "1.39.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5420"; Minver = "1.49.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5420 Rugged"; Minver = "1.40.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5421"; Minver = "1.41.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5424 Rugged"; Minver = "1.40.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5430"; Minver = "1.32.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5430 Rugged Laptop"; Minver = "1.39.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5431"; Minver = "1.33.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5440"; Minver = "1.25.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5450"; Minver = "1.16.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5455"; Minver = "2.11.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5500"; Minver = "1.41.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5501"; Minver = "1.42.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5510"; Minver = "1.38.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5511"; Minver = "1.39.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5520"; Minver = "1.46.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5521"; Minver = "1.39.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5530"; Minver = "1.32.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5531"; Minver = "1.32.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5540"; Minver = "1.24.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 5550"; Minver = "1.16.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7030 Rugged Extreme"; Minver = "1.17.3"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7200 2-In-1"; Minver = "1.38.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7210 2-in-1"; Minver = "1.40.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7212 Rugged Extreme Tablet"; Minver = "1.58.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7220 Rugged Extreme"; Minver = "1.48.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7230 Rugged Extreme"; Minver = "1.26.4"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7300"; Minver = "1.42.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7310"; Minver = "1.41.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7320"; Minver = "1.46.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7320 Detachable"; Minver = "1.43.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7330"; Minver = "1.34.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7330 Rugged Laptop"; Minver = "1.39.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7340"; Minver = "1.25.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7350"; Minver = "1.16.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7350 Detachable"; Minver = "1.14.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7400"; Minver = "1.42.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7400 2-In-1"; Minver = "1.37.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7410"; Minver = "1.41.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7420"; Minver = "1.46.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7424 Rugged Extreme"; Minver = "1.40.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7430"; Minver = "1.34.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7440"; Minver = "1.25.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7450"; Minver = "1.16.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7455"; Minver = "2.11.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7520"; Minver = "1.46.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7530"; Minver = "1.34.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7640"; Minver = "1.25.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 7650"; Minver = "1.16.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 9330"; Minver = "1.31.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 9410"; Minver = "1.39.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 9420"; Minver = "1.42.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 9430"; Minver = "1.34.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 9440 2-in-1"; Minver = "1.23.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 9450"; Minver = "1.15.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 9510 2-in-1"; Minver = "1.38.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude 9520"; Minver = "1.43.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Latitude Rugged 7220EX"; Minver = "1.48.0"}
#Optiplex
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 3000 Micro"; Minver = "1.34.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 3000 Small Form Factor"; Minver = "1.34.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 3000 Tower"; Minver = "1.34.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 3000 Thin Client"; Minver = "1.29.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 3070"; Minver = "1.35.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 3080"; Minver = "2.33.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 3090"; Minver = "2.27.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 3090 Ultra"; Minver = "1.38.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 3280 All-in-One"; Minver = "1.41.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 5000 Micro"; Minver = "1.33.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 5000 Small Form Factor"; Minver = "1.33.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 5000 Tower"; Minver = "1.33.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 5070"; Minver = "1.35.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 5080"; Minver = "1.33.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 5090 Micro"; Minver = "1.37.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 5090 Small Form Factor"; Minver = "1.37.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 5090 Tower"; Minver = "1.37.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 5270 All-in-One"; Minver = "1.40.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 5400 All-In-One"; Minver = "1.1.53"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 5480 All-in-One"; Minver = "1.42.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 5490 All-In-One"; Minver = "1.43.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 7000 Micro"; Minver = "1.33.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 7000 Small Form Factor"; Minver = "1.33.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 7000 Tower"; Minver = "1.33.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 7000 XE Micro"; Minver = "1.33.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 7070"; Minver = "1.35.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 7070 Ultra"; Minver = "1.33.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 7071"; Minver = "1.35.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 7080"; Minver = "1.36.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 7090 Tower"; Minver = "1.37.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 7090 Ultra"; Minver = "1.38.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 7400 All-In-One"; Minver = "1.1.53"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 7470 All-in-One"; Minver = "1.40.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 7480 All-in-One"; Minver = "1.42.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 7490 All-In-One"; Minver = "1.43.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 7770 All-in-One"; Minver = "1.40.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex 7780 All-in-One"; Minver = "1.42.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex AIO 7420"; Minver = "1.20.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex All-in-One 7410"; Minver = "1.30.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex Micro 7010"; Minver = "1.30.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex Micro Plus 7010"; Minver = "1.30.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex Micro 7020"; Minver = "1.20.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex SFF 7020"; Minver = "1.20.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex Small Form Factor 7010"; Minver = "1.30.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex Small Form Factor Plus 7010"; Minver = "1.30.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex Tower 7010"; Minver = "1.30.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex Tower Plus 7010"; Minver = "1.30.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex Tower 7020"; Minver = "1.20.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex XE3"; Minver = "1.38.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex XE4 SFF"; Minver = "1.33.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "OptiPlex XE4 Tower"; Minver = "1.33.2"}
#Precision
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3240 Compact"; Minver = "1.38.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3260 XE Compact"; Minver = "3.18.3"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3260 Compact"; Minver = "3.18.3"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3280 CFF"; Minver = "1.16.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3430 Tower"; Minver = "1.37.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3431 Tower"; Minver = "1.36.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3440"; Minver = "1.36.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3450"; Minver = "1.37.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3460 XE Small Form Factor"; Minver = "3.18.3"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3460 Small Form Factor"; Minver = "3.18.3"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3470"; Minver = "1.33.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3480"; Minver = "1.25.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3490"; Minver = "1.16.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3540"; Minver = "1.41.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3541"; Minver = "1.42.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3550"; Minver = "1.38.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3551"; Minver = "1.39.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3560"; Minver = "1.46.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3561"; Minver = "1.39.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3570"; Minver = "1.32.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3571"; Minver = "1.32.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3580"; Minver = "1.24.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3581"; Minver = "1.24.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3590"; Minver = "1.16.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3591"; Minver = "1.16.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3630 Tower"; Minver = "2.37.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3640"; Minver = "1.41.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3650 Tower"; Minver = "1.44.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3660"; Minver = "2.30.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3680 Tower"; Minver = "1.18.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 3930 Rack"; Minver = "2.40.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 5470"; Minver = "1.34.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 5480"; Minver = "1.22.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 5490"; Minver = "1.14.2"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 5540"; Minver = "1.39.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 5550"; Minver = "1.39.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 5560"; Minver = "1.41.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 5570"; Minver = "1.35.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 5680"; Minver = "1.23.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 5690"; Minver = "1.15.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 5750"; Minver = "1.37.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 5760"; Minver = "1.37.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 5770"; Minver = "1.35.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 5820 Tower"; Minver = "2.46.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 5860 Tower"; Minver = "3.1.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 7540"; Minver = "1.43.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 7550"; Minver = "1.41.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 7560"; Minver = "1.42.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 7670"; Minver = "1.32.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 7680"; Minver = "1.23.6"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 7740"; Minver = "1.43.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 7750"; Minver = "1.41.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 7760"; Minver = "1.42.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 7770"; Minver = "1.32.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 7780"; Minver = "1.23.6"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 7820 Tower"; Minver = "2.50.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 7865 Tower"; Minver = "1.21.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 7875 Tower"; Minver = "2.2.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 7920 Tower"; Minver = "2.50.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 7920 Rack"; Minver = "2.25.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 7920 XL Rack"; Minver = "2.25.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 7960 Tower"; Minver = "2.13.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 7960 Rack"; Minver = "2.8.3"}
$a_DellBios += New-Object PSObject -Property @{Model = "Precision 7960 XL Rack"; Minver = "2.8.3"}
#XPS
$a_DellBios += New-Object PSObject -Property @{Model = "XPS 13 9305"; Minver = "1.33.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "XPS 13 9310"; Minver = "3.34.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "XPS 13 9315"; Minver = "1.32.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "XPS 13 9340"; Minver = "1.19.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "XPS 13 9345"; Minver = "2.0.9"}
$a_DellBios += New-Object PSObject -Property @{Model = "XPS 13 9350"; Minver = "1.14.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "XPS 13 Plus 9320"; Minver = "2.24.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "XPS 14 9440"; Minver = "1.17.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "XPS 15 9500"; Minver = "1.39.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "XPS 15 9510"; Minver = "1.41.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "XPS 15 9520"; Minver = "1.35.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "XPS 15 9530"; Minver = "1.25.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "XPS 16 9640"; Minver = "1.17.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "XPS 17 9710"; Minver = "1.37.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "XPS 17 9720"; Minver = "1.35.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "XPS 17 9730"; Minver = "1.22.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "XPS 8950"; Minver = "1.29.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "XPS 8960"; Minver = "2.20.1"}
$a_DellBios += New-Object PSObject -Property @{Model = "XPS 9315 2-in-1"; Minver = "1.25.0"}
$a_DellBios += New-Object PSObject -Property @{Model = "XPS 9320"; Minver = "2.24.1"}

#Define Microsoft hardware models and their minimum firmware version to support the 2023 initiative
#Data from https://support.microsoft.com/en-US/surface/drivers-firmware/surface-secure-boot-certificates
$a_MSBios=@()
#$a_MSBios += New-Object PSObject -Property @{Model = "Surface Laptop 3"; Minver = ""}
$a_MSBios += New-Object PSObject -Property @{Model = "Surface Laptop 5"; Minver = "9.200.143.0"}
$a_MSBios += New-Object PSObject -Property @{Model = "Surface Laptop 5G for Business 7th Edition with Intel"; Minver = "1.0.0.0"}
$a_MSBios += New-Object PSObject -Property @{Model = "Surface Laptop 6 for Business"; Minver = "1.0.0.0"}
$a_MSBios += New-Object PSObject -Property @{Model = "Surface Laptop for Business 7th Edition with Intel"; Minver = "1.0.0.0"}
$a_MSBios += New-Object PSObject -Property @{Model = "Surface Pro 7+"; Minver = "23.200.143.0"}
$a_MSBios += New-Object PSObject -Property @{Model = "Surface Pro 8"; Minver = "23.200.143.0"}
$a_MSBios += New-Object PSObject -Property @{Model = "Surface Pro 9"; Minver = "12.200.143.0"}
$a_MSBios += New-Object PSObject -Property @{Model = "Surface Pro 10 for Business"; Minver = "1.0.0.0"}
$a_MSBios += New-Object PSObject -Property @{Model = "Surface Pro for Business 11th Edition with Intel"; Minver = "1.0.0.0"}
$a_MSBios += New-Object PSObject -Property @{Model = "Microsoft Surface Pro, 11th Edition"; Minver = "1.0.0.0"}



#region Functions
#Functions here

Function Convert-VersionTo4Octets
    {
    <#
    .Synopsis
       Convert-VersionTo4Octets
    .DESCRIPTION
       Pads the version number of a provided version to 4 octets.  Makes no changes it > 4 octets already

       Returns - the updated version eg:
        w                   is returned as w.0.0.0
        w.x                 is returned as w.x.0.0
        w.x.y               is returned as w.x.y.0
        w.x.y.z             is returned unchanged
        w.x.y.z.anything    is returned unchanged

    .PARAMETER Version
        The version number to convert
    .EXAMPLE
       Convert-VersionTo4Octets -Version w.x
    #>
        [CmdletBinding()]
        Param
        (
            # Param1 help description
            [Parameter(Mandatory=$true)][string]$Version
        )

    #Define local variables

    #Get ocd count
    $i_Count=$Version.Split(".").Count
    if ($i_Count -ge 4)
        {
        #Passed version is already 4 or more octets
        #Do nothing
        }
    else
        {
        #Let's pad 4-$i_Count times
        for ($i = 1; $i -le ([int](4-[int]$i_Count)); $i++)
            {
            $Version=$Version + ".0"
            }
        }

    Return $Version

    }

function Get-SecureBootCertNames
    {
    <#
    .Synopsis
       Get-SecureBootCertNames
    .DESCRIPTION
       Uses cmdlet Get-SecureBootUEFI (without the requirement of the March 2026+ '-decode' parameter) to retrieve various Secure Boot certificates

       Returns an array of the cert subject names like this:
        CN=Microsoft Corporation KEK CA 2011, O=Microsoft Corporation, L=Redmond, S=Washington, C=US
        CN=Microsoft Corporation KEK 2K CA 2023, O=Microsoft Corporation, C=US

        If no certs found, returns an empty array
    
    .PARAMETER Name
        Specifies the name of the UEFI environment variable

        As per https://learn.microsoft.com/en-us/powershell/module/secureboot/get-securebootuefi?view=windowsserver2025-ps, one of:
        PK, KEK, db, PKDefault, KEKDefault, dbDefault
            Some systems don't offer PKDfault, KEKDefault, dbDefault if:
                KEKDefault is the OEM‑provided “factory default” Key Exchange Key database, stored in UEFI firmware. Whether it exists depends entirely on how the OEM implemented Secure Boot.
                Many modern systems — including fully compliant Windows 11 devices — do not expose KEKDefault at all, even though:

                KEK is present
                Secure Boot is enabled
                The system boots and updates normally

                This is normal and expected behavior, especially on:

                Devices that have never had Secure Boot keys reset
                Systems where the OEM does not maintain a separate “default” KEK variable
                Devices relying on Windows‑managed Secure Boot updates rather than firmware resets

                Microsoft documents KEKDefault as an optional variable, not a guaranteed one

    .EXAMPLE
       Convert-VersionTo4Octets -Version w.x
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
        )

    #Set initial values
    $a_Certs=@()

    #Get the certificates
    $ErrorActionPreference="SilentlyContinue"
    $a_Results=@(Get-SecureBootUEFI -Name $Name -ErrorAction SilentlyContinue)
    $ErrorActionPreference="Continue"
    if ($a_Results.Count -eq 0)
        {
        #No data was returned
        }
    else
        {
        #Some data on one or more certs was returned
        foreach ($Result in $a_Results)
            {
            $data = $Result.Bytes
            $stream = New-Object System.IO.MemoryStream(,$data)
            $reader = New-Object System.IO.BinaryReader($stream)

            while ($stream.Position -lt $stream.Length)
                {
                # Read EFI_SIGNATURE_LIST header
                $sigType = $reader.ReadBytes(16)
                $sigListSize = $reader.ReadUInt32()
                $sigHeaderSize = $reader.ReadUInt32()
                $sigSize = $reader.ReadUInt32()

                # Skip SignatureHeader
                $reader.ReadBytes($sigHeaderSize) | Out-Null

                # Read all signatures in this list
                $numSigs = [math]::Floor(($sigListSize - 28 - $sigHeaderSize) / $sigSize)

                for ($i = 0; $i -lt $numSigs; $i++)
                    {
                    # Skip SignatureOwner GUID
                    $reader.ReadBytes(16) | Out-Null

                    # Remaining bytes are the certificate or hash
                    $certBytes = $reader.ReadBytes($sigSize - 16)

                    try
                        {
                        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @(,$certBytes)
                        if ($cert.Subject)
                            {
                            $a_Certs += $cert.Subject
                            }
                        else
                            {
                            #No subject, not a cert
                            $a_Certs += "Hi there"
                            }
                        }
                    catch
                        {
                        # Ignore non‑cert entries like hashes
                        $a_Certs += "Hi there2"
                        }
                    }
                }
            }
        }

    return $a_Certs
    }

Function Write-CustomEventLog($Message)
    {
    #Based on Write-CustomEventLog by Jos Lieben
    $EventSource="Manulife-Remediation_" + $s_MyFunction + "_$s_MyName"
    if ([System.Diagnostics.EventLog]::Exists('Application') -eq $False -or [System.Diagnostics.EventLog]::SourceExists($EventSource) -eq $False)
        {
      #  $res = New-EventLog -LogName Application -Source $EventSource  | Out-Null
        }
  #  $res = Write-EventLog -LogName Application -Source $EventSource -EntryType Information -EventId 1985 -Message $Message
    }

function Write-History
    {
     <#
    .Synopsis
       Write-History
    .DESCRIPTION
        - Writes a registry key as a history of other registry keys applied vi Intune to match GPO
    .PARAMETER
        Path (mandatory)            The key path
        Name (mandatory)            The Valuename within the key
        PropertyType (mandatory)    The type of key written
        Value (mandatory)           The data written
        Remove (optional)           Deletes the registry key history instead of creating it
    .EXAMPLE
       Write-History -Path "$s_DesiredRegKey" -Name "$s_DesiredRegValueName"  -PropertyType $s_DesiredRegValueType -Value $s_DesiredRegValue
    #>
        [CmdletBinding()]
        Param
        (
            # Param1 help description
            [Parameter(Mandatory=$true)][string]$Path,
            [Parameter(Mandatory=$true)][string]$Name,
            [Parameter(Mandatory=$true)][string]$PropertyType,
            [Parameter(Mandatory=$true)][string]$Value,
            [Parameter(Mandatory=$false)][switch]$Remove
        )

    #Define local variables
    [string]$s_HistoryKey

    $s_HistoryKey=$s_RegKeyInstallTattoo + "\" + $Path.Replace(":","")

    if ($Remove -eq $false)
        {
        #Create the history
        #Verify that the history key exists
        Try
            {
            Get-Item -path "$s_HistoryKey" -ErrorAction Stop
            #The key exists, good, we'll keep going
            }
        Catch
            {
            #The key does not exist.  Create it!
            New-Item -Path "$s_HistoryKey" -Force -ErrorAction SilentlyContinue
            }
        #Write the value.  We can force the value write
        New-ItemProperty -Path "$s_HistoryKey" -Name "$Name" -PropertyType $PropertyType -Value $Value -Force -ErrorAction SilentlyContinue
        }
    else
        {
        #Remove the history
        Remove-Item -Path "$s_HistoryKey" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

function Write-RegistryValue
    {
    <#
    .Synopsis
       Write-RegistryValue
    .DESCRIPTION
        - Writes a registry key value as the requested value type.  Creates the provided registry key if it does not already exist
        v1 - Initial save of most-used iteration
        
        v2 - May 28, 2020 - Steven Heimbecker
            - Changed:
                - No reliance on preexisting registry key and value, these are now explicitly passed as parameters
        
        v3 - Mar 24, 2022 - Steven Heimbecker
            - Changed:
                - Added $PropertyType optional parameter
                - Set-ItemProperty replaced with New-ItemProperty
        
        - 20.23.001 June 8, 2023
            Fixed:
                - Nothing
            Added:
                - Comments about the use of Out-Null
            Changed:
                - New version format
                - blank is now acceptable for $Value
            Removed:
                - Nothing
            Known issues:
                - None

        - 20.25.001 Mar 2, 2025
            Fixed:
                - Write of multistring $Value
            Added:
                - Nothing
            Changed:
                - If $Value is an array, surrounding "" are not used on pass of $Value to cmdlet New-ItemProperty
                - Renamed function to 'Write-RegistryValue'
                - Removed type [string] from [Parameter(Mandatory=$false)]$Value
                - New-Item and New-ItemProperty piped to Out-Null
            Removed:
                - Nothing
            Known issues:
                - None

    .NOTE
        To suppress action output to the output stream, invoke this function and pipe to Out-Null, i.e.:
            Write-RegistryValue -Path "HKCU:\Software\Manulife" -Name "SomeValueS"  -Value "1"  | Out-Null
        
    .PARAMETER
        Path (mandatory).  The registry key to write to
    .PARAMETER
        Name (mandatory).  The registry value name to be created under key Path
    .PARAMETER
        PropertyType (optional).  The type of value name to be created.  Options are:
            String:         Specifies a null-terminated string. Equivalent to REG_SZ.  (Default if not provided)
            ExpandString:   Specifies a null-terminated string that contains unexpanded references to environment variables that are expanded when the value is retrieved. Equivalent to REG_EXPAND_SZ.
            Binary:         Specifies binary data in any form. Equivalent to REG_BINARY.
            DWord:          Specifies a 32-bit binary number. Equivalent to REG_DWORD.
            MultiString:    Specifies an array of null-terminated strings terminated by two null characters. Equivalent to REG_MULTI_SZ.
            Qword:          Specifies a 64-bit binary number. Equivalent to REG_QWORD.
            Unknown:        Indicates an unsupported registry data type, such as REG_RESOURCE_LIST.
    .PARAMETER
        Value (mandatory).  The data to be written to Name in key Path
    .EXAMPLE
       Write-RegistryValue -Path "HKCU:\Software\Manulife" -Name "SomeValueD" -PropertyType "Dword" -Value 1
       Write-RegistryValue -Path "HKCU:\Software\Manulife" -Name "SomeValueS"  -Value $s_AVariableofText  | Out-Null  #string in a variable (no quotes)
       Write-RegistryValue -Path "HKCU:\Software\Manulife" -Name "SomeValueS"  -Value $a_AnArrayofWhatever  | Out-Null  #array in a variable (no quotes)
       Write-RegistryValue -Path "HKCU:\Software\Manulife" -Name "SomeValueS"  -Value "1"  | Out-Null   #enclose value in quotes for adhoc text only
    #>
        [CmdletBinding()]
        Param
        (
            # Param1 help description
            [Parameter(Mandatory=$true)][string]$Path,
            [Parameter(Mandatory=$true)][string]$Name,
            [Parameter(Mandatory=$false)][string]$PropertyType,
            [Parameter(Mandatory=$false)]$Value    #We may be passing a blank value so can't be mandatory, handled below
        )

    #Define local variables

    #Begin

    #Ensure default property type is set if not provided
    if (($null -eq $PropertyType) -or ($PropertyType -eq "")) {$PropertyType = "String"}

    #Ensure $Value is set to blank if not provided
    if ($null -eq $Value) {$Value=""}

    #Ensure the desired registry key exists
    Try
        {
        Get-Item -path "$Path" -ErrorAction Stop
        #The key exists, good, we'll keep going
        }
    Catch
        {
        #The key does not exist.  Create it!
        New-Item -Path "$Path" -Force | Out-Null
        }
    
    #Write the desired value.  We can force the value write
    #Ensure that if $Value is an array then "" are not used as this affects the result
    if ($Value -is [array])
        {
        #No quotes on $Value
        New-ItemProperty -Path "$Path" -Name "$Name" -PropertyType "$PropertyType" -Value $Value -Force -ErrorAction SilentlyContinue | Out-Null
        }
    else
        {
        #Quotes on $Value, as it is a string
        New-ItemProperty -Path "$Path" -Name "$Name" -PropertyType "$PropertyType" -Value "$Value" -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }

#Region Main
#Begin Main section

#Get script startdate
$o_ScriptLaunchTime=Get-Date

#Start the text for the consolidated log.  We only want to write one entry to the eventlog
$s_LogTextConsolidated=""
$s_LogTextConsolidated="v$s_ScriptVer starting, `'$s_Mode`' mode."

#Write the script version and when it last ran (if remediating)
if ($s_Mode -ieq "remediate")
    {
    Write-RegistryValue -Path "$s_RegKeyInstallTattoo" -Name "ScriptVer" -PropertyType "String" -Value "$s_ScriptVer" | Out-Null
    Write-RegistryValue -Path "$s_RegKeyInstallTattoo" -Name "Lastrun" -PropertyType "String" -Value "$o_ScriptLaunchTime" | Out-Null
    }

#Get the hardware Manufacturer, model
$o_DeviceInfo=Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model
$s_Manufacturer=$($o_DeviceInfo.Manufacturer).Trim()
$s_Model=$($o_DeviceInfo.Model).Trim()

#Get and format the bios version and release date
$o_BIOS=$null
$o_BIOS = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
if ($null -eq $o_BIOS)
    {
    #Don't know the BIOS version.  Assume very old
    $s_BIOSVer="0.0.0.0"
    $o_BIOSReleaseDate=$o_AReallyOldDate
    }
else
    {
    $s_BIOSVer=$null
    #Try to get it
    $s_BIOSVer=$o_bios.SMBIOSBIOSVersion
    if ($null -eq $s_BIOSVer)
        {
        #Don't know the BIOS version.  Assume very old
        $s_BIOSVer="0.0.0.0"
        $o_BIOSReleaseDate=$o_AReallyOldDate
        }
    else
        {
        #We have a version.  Try to get its release date
        $o_BIOSReleaseDate=$null
        $o_BIOSReleaseDate=$o_bios.ReleaseDate
        if ($null -eq $o_BIOSReleaseDate)
            {
            #We don't know what it is.  Assume very old
            $o_BIOSReleaseDate=$o_AReallyOldDate
            }
        else
            {
            #We have a value, it may or may not be in datetime format.  Convert to UTC
            if ($o_BIOSReleaseDate -is [datetime])
                {
                #Already a date object.  Convert to UTC
                $o_BIOSReleaseDate=$o_BIOSReleaseDate.ToUniversalTime()
                }
            else
                {
                #Try to make a date object as per Copilot suggestion
                $ErrorActionPreference="SilentlyContinue"
                $o_BIOSReleaseDateConverted=$null
                $o_BIOSReleaseDateConverted=[Management.ManagementDateTimeConverter]::ToDateTime($o_BIOSReleaseDate)
                $ErrorActionPreference="Continue"
                if ($null -eq $o_BIOSReleaseDateConverted)
                    {
                    #We can't calculate the date, assume very old
                    $o_BIOSReleaseDate=$o_AReallyOldDate
                    }
                else
                    {
                    #Not an error.  Is the result a date?
                    if ($o_BIOSReleaseDateConverted -is [datetime])
                        {
                        #Now a date object.  Convert to UTC
                        $o_BIOSReleaseDate=$o_BIOSReleaseDateConverted.ToUniversalTime()
                        }
                    else
                        {
                        #Still not a date object, we can't figure it out, assume very old
                        $o_BIOSReleaseDate=$o_AReallyOldDate
                        }
                    }
                }
            }
        }
    }
#Make sure the bios version is padded to 4 Octets
$s_BIOSVer=Convert-VersionTo4Octets -Version $s_BIOSVer

#Get the OS version
$s_OSVersion=(Get-CimInstance Win32_OperatingSystem).Version

$s_UBR=$(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' | Select-Object UBR).UBR
#Update version
$s_OSVersion=$s_OSVersion + "." + $s_UBR

#Check for virtuals (simple approach)
if (($s_Model -like "*virtual*") -or ($s_Model -like "*Cloud PC*"))
    {
    $b_IsVirtual=$True
    }
else
    {
    $b_IsVirtual=$False
    }

#Calculate if we are at or beyond BIOS version minimum
#Dell devices are automatically if BIOS release date is later than Jan 1 2026
$b_BIOSIsGood=$False
if ($b_IsVirtual -eq $True)
    {
    #A VM, skip the BIOS versioning
    $b_BIOSIsGood=$True
    }
elseif ($s_Manufacturer -like "*Dell*")
    {
    #Dell indicates any firmware released in 2026+ is compliant.
    if ($o_BIOSReleaseDate -gt $o_DellBIOSIsGoodDate)
        {
        #consider it good!
        $b_BIOSIsGood=$true
        }
    else
        {
        #Need to figure it out
        $s_MinGoodBIOSVer=$null
        $s_MinGoodBIOSVer=($a_DellBios | Where-Object {$PSItem.Model -ieq $s_Model} | Select-Object -Property Minver).Minver
        #if $s_MinGoodBIOSVer is still $null, then we don't know the minimum so assume good is false
        if ($null -ne $s_MinGoodBIOSVer)
            {
            #We found a minimum version.  Pad!
            $s_MinGoodBIOSVer=Convert-VersionTo4Octets -Version $s_MinGoodBIOSVer
            #compare!
            if ([version]$s_BIOSVer -ge [version]$s_MinGoodBIOSVer)
                {
                #We are good!
                $b_BIOSIsGood=$true
                }
            }
        }
    }
elseIf ($s_Manufacturer -like "*Microsoft*")
    {
    $s_MinGoodBIOSVer=$null
    $s_MinGoodBIOSVer=($a_MSBios | Where-Object {$PSItem.Model -ieq $s_Model} | Select-Object -Property Minver).Minver
    #if $s_MinGoodBIOSVer is still $null, then we don't know the minimum so assume good is false
    if ($null -ne $s_MinGoodBIOSVer)
        {
        #We found a minimum version.  Pad!
        $s_MinGoodBIOSVer=Convert-VersionTo4Octets -Version $s_MinGoodBIOSVer
        #compare!
        if ([version]$s_BIOSVer -ge [version]$s_MinGoodBIOSVer)
            {
            #We are good!
            $b_BIOSIsGood=$true
            }
        }   
    }
else
    {
    #Unknown Manufacturer, can't do compare
    }

#Build hardware string + OS Version + BIOS Version + BIOS Min Good
$s_Hardware=$s_OSVersion + "|" + $s_Manufacturer + "|" + $s_Model + "|" + $s_BIOSVer + "|" + $b_BIOSIsGood



#Get Secure boot status which determines how much more work we do
$b_SecureBootOK=Confirm-SecureBootUEFI -ErrorAction SilentlyContinue    #Returns True or False
if ($b_SecureBootOK -eq $false)
    {
    #secure boot is off
    $s_SecureBoot="OFF"
    #We don't care about further analysis
    $s_CertFoundKEK="Unknown"
    $s_CertFoundDB="Unknown"
    $s_CertFoundKEKDefault="Unknown"
    $s_CertFoundDBDefault="Unknown"
    $s_SVN="Unknown"
    $s_Bucket="Not applicable"
    $s_Action="Enable Secure boot"
    }
else
    {
    #secure boot is on
    $s_SecureBoot="ON"
    #We care
    
    #Get UEFI2023 status as suggested by Microsoft / Copilot
    $s_UEFIStatus=$null
    $KeyPath="HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing"
    $KeyName="UEFICA2023Status"
    $s_UEFIStatus=Get-ItemProperty -Path $KeyPath -ErrorAction SilentlyContinue | Select-Object $KeyName -ExpandProperty $KeyName -ErrorAction SilentlyContinue

    #Look for any error events
    $s_UEFICA2023Error=$null
    $KeyName="UEFICA2023Error"
    $s_UEFICA2023Error=Get-ItemProperty -Path $KeyPath -ErrorAction SilentlyContinue | Select-Object $KeyName -ExpandProperty $KeyName -ErrorAction SilentlyContinue
    if ($null -eq $s_UEFICA2023Error) {$s_UEFICA2023Error="0"}
    $s_UEFICA2023ErrorEvent=$null
    $KeyName="UEFICA2023ErrorEvent"
    $s_UEFICA2023ErrorEvent=Get-ItemProperty -Path $KeyPath -ErrorAction SilentlyContinue | Select-Object $KeyName -ExpandProperty $KeyName -ErrorAction SilentlyContinue
    if ($null -eq $s_UEFICA2023ErrorEvent) {$s_UEFICA2023ErrorEvent=""}

    #Let's look for the active secure boot certs.  We are looking for 2023 certs
    $i_ActiveCertsInstalled=0   #initially no certs flagged as installed
    #We want KEK, db
    #Get the KEK cert data. See: https://support.microsoft.com/en-us/topic/secure-boot-certificate-updates-guidance-for-it-professionals-and-organizations-e2b43f9f-b424-42df-bc6a-8476db65ab2f
    #We are NOT using Get-SecureBootUEFI -Decoded -Name xxx so we aren't dependent on March 2026 updates to this cmdlet which added this parameter
    $a_SecureBootUEFIKEK=@(Get-SecureBootCertNames -Name KEK)
    if ($a_SecureBootUEFIKEK.Count -eq 0)
        {
        #No certificates present
        $s_CertFoundKEK="None"
        }
    else
        {
        #There are some.  Are any the ones we want?
        $a_CertFoundKEK=@($a_SecureBootUEFIKEK | Where-Object {$PSItem -like "*2023*"})
        If ($a_CertFoundKEK.Count -eq 0)
            {
            #No 2023 Cert
            $s_CertFoundKEK="None"
            }
        elseif ($a_CertFoundKEK.Count -eq 1)
            {
            #A 2023 cert.  Increment we have an ActiveCert installed.
            $s_CertFoundKEK=$a_CertFoundKEK[0]
            $i_ActiveCertsInstalled += 1
            }
        else
            {
            #More than one found.  Sort for uniqueness and then join with a "|"  Increment we have an ActiveCert installed.  Doesn't matter if there are more than one
            $a_CertFoundKEK=$a_CertFoundKEK | Sort-Object -Unique
            $s_CertFoundKEK=$a_CertFoundKEK -join "|"
            $i_ActiveCertsInstalled += 1
            }
        }

    #Get the db cert data.
    $a_SecureBootUEFIDB=@(Get-SecureBootCertNames -Name DB)
    if ($a_SecureBootUEFIDB.Count -eq 0)
        {
        #No certificates present
        $s_CertFoundDB="None"
        }
    else
        {
        #There are some.  Is it the one we want?
        $a_CertFoundDB=@($a_SecureBootUEFIDB | Where-Object {$PSItem -like "*2023*"})
        If ($a_CertFoundDB.Count -eq 0)
            {
            #No 2023 Cert
            $s_CertFoundDB="None"
            }
        elseif ($a_CertFoundDB.Count -eq 1)
            {
            #A 2023 cert.  Increment we have one ActiveCert installed
            $s_CertFoundDB=$a_CertFoundDB[0]
            $i_ActiveCertsInstalled += 1
            }
        else
            {
            #More than one found.  Sort for uniqueness and then join with a "|"  Increment we have an ActiveCert installed.  Doesn't matter if there are more than one
            $a_CertFoundDB=$a_CertFoundDB | Sort-Object -Unique
            $s_CertFoundDB=$a_CertFoundDB -join "|"
            $i_ActiveCertsInstalled += 1
            }
        }

    #Let's look for the default secure boot certs (in firmware).  These might be available depending on hardware.  We are looking for 2023 certs
    #We want KEKDefault (if exists) and dbDefault (if exists)
    $a_SecureBootUEFIKEKDefault=@(Get-SecureBootCertNames -Name KEKDefault)
    if ($a_SecureBootUEFIKEKDefault.Count -eq 0)
        {
        #No certificates present
        $s_CertFoundKEKDefault="None"
        }
    else
        {
        #There are some.  Is it the one we want?
        $a_CertFoundKEKDefault=@($a_SecureBootUEFIKEKDefault | Where-Object {$PSItem -like "*2023*"})
        if ($a_CertFoundKEKDefault.Count -eq 0)
            {
            #No 2023 Cert
            $s_CertFoundKEKDefault="None"
            }
        elseif ($a_CertFoundKEKDefault.Count -eq 1)
            {
            #A 2023 cert.
            $s_CertFoundKEKDefault=$a_CertFoundKEKDefault[0]
            }
        else
            {
            #More than one found.  Sort for uniqueness and then join with a "|" 
            $a_CertFoundKEKDefault=$a_CertFoundKEKDefault | Sort-Object -Unique
            $s_CertFoundKEKDefault=$a_CertFoundKEKDefault -join "|"
            }
        }

    #Get the db cert data.
    $a_SecureBootUEFIDBDefault=@(Get-SecureBootCertNames -Name DBDefault)
    if ($a_SecureBootUEFIDBDefault.Count -eq 0)
        {
        #No certificates present
        $s_CertFoundDBDefault="None"
        }
    else
        {
        #There are some.  Is it the one we want?
        $a_CertFoundDBDefault=@($a_SecureBootUEFIDBDefault | Where-Object {$PSItem -like "*2023*"})
        If ($a_CertFoundDBDefault.Count -eq 0)
            {
            #No 2023 Cert
            $s_CertFoundDBDefault="None"
            }
        elseif ($a_CertFoundDBDefault.Count -eq 1)
            {
            #A 2023 cert.
            $s_CertFoundDBDefault=$a_CertFoundDBDefault[0]
            }
        else
            {
            #More than one found.  Sort for uniqueness and then join with a "|" 
            $a_CertFoundDBDefault=$a_CertFoundDBDefault | Sort-Object -Unique
            $s_CertFoundDBDefault=$a_CertFoundDBDefault -join "|"
            }
        }

    #Confirm the cmdlets are installed (requires March 2026 Windows cumulative update for Get-SecureBootSVM)
    #SVN is the 'Secure Version Number', used in future when the new boot manager will be enforced.
    if (Get-Command -Name Get-SecureBootSVN -ErrorAction SilentlyContinue)
        {
        #cmdlet exists
        #Get the compliance status of the Secure Boot updates
        $s_SVN=$(Get-SecureBootSVN | Select-Object -Property ComplianceStatus).ComplianceStatus
        }
    else
        {
        $s_SVN="Data not available - no Get-SecureBootSVN cmdlet"
        }

    #We now need to determine what 'bucket' / state we are in 
    if (($s_UEFICA2023Error -ne 0) -and ($b_IsVirtual -eq $False))
        {
        #Errors are only analyzed on physical devices
        $b_RebootLogEntryFound=$False   #Assume initially no 1800 reboot event id
        #Is this event 1800?
        if ($s_UEFICA2023ErrorEvent -eq "1800")
            {
            #We need to check event log to see if this is or is not related to a reboot pending.  Thanks for the assist, copilot!
            # Look back far enough to catch pre-reboot events
            $o_EventStartTime = $o_ScriptLaunchTime.AddDays(-7)
            $o_Event=$null
            $o_Event = Get-WinEvent -FilterHashtable @{
                LogName      = 'System'
                ProviderName = 'Microsoft-Windows-TPM-WMI'
                Id           = 1800
                StartTime    = $o_EventStartTime
                } -MaxEvents 1 -ErrorAction SilentlyContinue

            if (-not $o_Event)
                {
                #No 1800 present
                #Must be a real error
                }
            else
                {
                #There is an 1800 event ID within to time period indicated.  We need to read the event to s if it's what we are looking for
                $s_message = $o_Event.Message
                #We are looking for "A reboot is required before installing the Secure Boot update.  Reason: Boot Manager (2023)"
                if (($s_message -match 'reboot is required') -and ($s_message -match 'Boot Manager\s*\(2023\)'))
                    {
                    #A reboot required message!
                    $b_RebootLogEntryFound=$True
                    }
                else
                    {
                    #No, not a reboot required message.  Act as a real error
                    }
                }
            }
        else
            {
            #Not 1800.  Act as a real error
            }
        
        #Apply bucket and actions based on reboot event detection
        if ($b_RebootLogEntryFound -eq $False)
            {
            #Apply a real error
            $s_Bucket="Blocked - error $s_UEFICA2023Error ($s_UEFICA2023ErrorEvent)"
            $s_Action="Investigate"
            }
        else
            {
            #An 1800 reboot state
            $s_Bucket="InProgress"
            $s_Action="Reboot Required"
            }
        }
    elseif ($s_UEFIStatus -ieq "InProgress")
        {
        #Conversion is in progress
        if ($b_IsVirtual)
            {
            #Not managed by Manulife
            $s_Bucket="InProgress - Microsoft Managed"
            $s_Action="None"
            }
        else
            {
            #Managed by Manulife
            $s_Bucket="InProgress"
            $s_Action="Apply Intune profile"
            }
        }
    elseif ($s_UEFIStatus -ieq "NotStarted")
        {
        #Conversion hasn't started yet
        if ($b_IsVirtual)
            {
            #Not managed by Manulife
            $s_Bucket="NotStarted - Microsoft Managed"
            $s_Action="None"
            }
        else
            {
            #Managed by Manulife
            #Do we have the data to attempt?  Depends on scenario
            if ($i_ActiveCertsInstalled -eq 2)
                {
                ##2023 certificates are present in Active db, regardless of BIOS at min version and should have the keys.  In this case should be able to proceed
                $s_Bucket="NotStarted"
                $s_Action="Apply Intune profile"
                }
            elseif (($i_ActiveCertsInstalled -lt 2) -and ($b_BIOSIsGood -eq $True))
                {
                ##2023 certificates are not all present in Active db and BIOS is at min version and should have the keys.  In this case try to proceed
                $s_Bucket="NotStarted"
                $s_Action="Apply Intune profile"
                }
            else
                {
                ##2023 certificates are not all present in Active db and BIOS is NOT at min version and may not have the keys.  In this case do not try, require BIOS update
                $s_Bucket="NotStarted"
                $s_Action="BIOS update required"
                }
            }
        }
    elseif ($s_UEFIStatus -ieq "Updated")
        {
        #Conversion appears to be complete
        #Is this complete or not?  Copilot says Microsoft devices don't have default db, so this is complete
        #Dells might have default, so check for those, as this may update what investigation is required
        If ($s_Manufacturer -like "*Microsoft*")
            {
            #Update the bucket
            $s_Bucket="Updated - Complete"
            $s_Action="None"
            }
        elseif ($s_Manufacturer -like "*Dell*")
            {
            #Look at the values of the default keys we may have found
            if (($s_CertFoundKEKDefault -ne "None") -and ($s_CertFoundDBDefault -ne "None"))
                {
                #There are default updated default keys
                $s_Bucket="Updated - Complete"
                $s_Action="None"
                }
            else
                {
                #Default keys aren't updated.  Might cause issues on this device if keys are ever reset in the bios, might need to re-remediate
                #Is a BIOS update recommended?
                if ($b_BIOSIsGood -eq $False)
                    {
                    #Yes it is.  BIOS may be lower than the minimum indicated by the vendor
                    $s_Bucket="Updated - Fragile"
                    $s_Action="BIOS update recommended"
                    }
                else
                    {
                    #No, BIOS should not be a concern even if default keys aren't detectable because BIOS version is above minimums where new keys are included
                    $s_Bucket="Updated - Complete"
                    $s_Action="None"
                    }
                }
            }
        else
            {
            #totally don't know
            $s_Bucket="Updated - Unknown"
            $s_Action="None"
            }
        }
    else
        {
        #Unknown status
        $s_Bucket="Unknown"
        $s_Action="Investigate"
        }
    }

    # Uptime (days)
$BootDays = $null
if($os.LastBootUpTime){ try { $BootDays = ((Get-Date) - $os.LastBootUpTime).Days } catch { $BootDays = $null } }

#Formulate output
$s_Output=$s_Hardware + "|" + $s_SecureBoot + "|" + $s_CertFoundKEK + "|" + $s_CertFoundDB + "|" + $s_CertFoundKEKDefault + "|" + $s_CertFoundDBDefault + "|" + $s_SVN + "|" + $s_Bucket + "|" + $s_Action

#Build an object with all of this data!
$o_Output = New-Object PSObject -Property ([ordered]@{
    DetectResults = "";
    DeviceName          = $env:COMPUTERNAME
    OSVersion = $s_OSVersion;
    OSBuild             = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).DisplayVersion;
    BootuptimeDays      = $BootDays;
    Manufacturer = $s_Manufacturer;
    Model = $s_Model;
    BIOSVer = $s_BIOSVer;
    BIOSReleaseDate=$o_BIOSReleaseDate;
    BIOSShippedWith2023Certs = $b_BIOSIsGood;
    SecureBoot = $s_SecureBoot;
    ActiveDBKEKCert = $s_CertFoundKEK;
    ActiveDBDBCert = $s_CertFoundDB;
    DefaultDBKEKCert = $s_CertFoundKEKDefault;
    DefaultDBDBCert = $s_CertFoundDBDefault;
    SecureVersionNumber = $s_SVN;
    State = $s_Bucket;
    Action = $s_Action
    })

#What is a detect fail?  When action not 'None'
if ($s_Action -ine "None")
    {
    #This is a fail
    #Detection mode
    $s_LogText="Detection FAIL" + "|" + $s_Output
    $s_LogTextConsolidated=$s_LogTextConsolidated + "`n`n" + $s_LogText
    $o_Output.DetectResults="FAIL"
    $s_Output=$o_Output | ConvertTo-Json -Compress
  #  Write-Host $s_Output
    $i_ExitCode=1
    }
else
    {
    #This is a pass
    #Detection mode
    #All OK
    $s_LogText="Detection PASS" + "|" + $s_Output
    $s_LogTextConsolidated=$s_LogTextConsolidated + "`n`n" + $s_LogText
    $o_Output.DetectResults="PASS"
    $s_Output=$o_Output | ConvertTo-Json -Compress
   # Write-Host $s_Output
    $i_ExitCode=0 #OK
    }
}

# Sending the data to Log Analytics Workspace
# Submit the data to the API endpoint
$ResponseAppInventory = Send-LogAnalyticsData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($s_Output)) -logType $AppLogName

$date = Get-Date -Format "dd-MM HH:mm"
$OutputMessage = "InventoryDate:$date "

if ($CollectSecureBootInventory) {
	if ($ResponseAppInventory -match '200 :') {

		$OutputMessage = $OutPutMessage + ' AppInventory:OK ' + $ResponseAppInventory
	} else {
		$OutputMessage = $OutPutMessage + ' AppInventory:Fail '
	}
}
Write-Output $OutputMessage
Exit 0
#endregion script

#End as Appropriate
$o_Now=Get-Date
$o_TotalElapsed=New-TimeSpan -Start $o_ScriptLaunchTime -End $o_Now
$s_LogText="Ending, return code: $i_ExitCode.`nTotal script runtime: " + ($o_TotalElapsed).Days + " day(s), " + ($o_TotalElapsed).Hours + " hour(s), " + ($o_TotalElapsed).Minutes + " minute(s), " + ($o_TotalElapsed).Seconds + " second(s), " + ($o_TotalElapsed).Milliseconds + " millisecond(s)."
$s_LogTextConsolidated=$s_LogTextConsolidated + "`n`n" + $s_LogText
#Write-CustomEventLog "$s_LogTextConsolidated"
Exit $i_ExitCode
