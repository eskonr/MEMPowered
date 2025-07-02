<#
.SYNOPSIS
    This scripts extract the hardware hashid of the device including serial number for Autopilot migration.
		This is useful if you have already provisioned the devices using traditional method and are managed by intune and you wanted to collect the hashid for all devices rather running the script manually on the devices.

.DESCRIPTION
    This scripts runs on local device using systema account or admin account.
    this script does NOT requires any modules.

.EXAMPLE
    SendAutopilotHashIDtoLogAnalytics.ps1

.NOTES
Created by Eswar Koneti
Dated: 02-Jul-2025
#>

#region initialize
# Enable TLS 1.2 support
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# Replace with your Log Analytics Workspace ID
$CustomerId = 'CustomerIDofLogAnalytics'  # Change the customerID of your log analytics workspace as per your tenant

# Replace with your Primary Key
$SharedKey = 'Primarykey/SharedKeyofYourLoganalyticsWorkspace' # Change the sharedKey/Primary key of your log analytics workspace.

#Control if you want to collect App or Device Inventory or both (True = Collect)
$CollectAutopilotHashInfo = $true
$AutopilotHashInfoLogName = 'AutopilotHashIDTable' #This will be the table that gets created in Log analytics specified above if not exist.
$Date = (Get-Date)
# You can use an optional field to specify the timestamp from the data. If the time field is not specified, Azure Monitor assumes the time is the message ingestion time
# DO NOT DELETE THIS VARIABLE. Recommened keep this blank.
$TimeStampField = ''

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
	$method = 'POST'
	$contentType = 'application/json'
	$resource = '/api/logs'
	$date = [DateTime]::UtcNow.ToString('r')
	$contentLength = $body.Length
	#Construct authorization signature
	$xHeaders = 'x-ms-date:' + $date
	$stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource
	$bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
	$keyBytes = [Convert]::FromBase64String($sharedKey)
	$sha256 = New-Object System.Security.Cryptography.HMACSHA256
	$sha256.Key = $keyBytes
	$calculatedHash = $sha256.ComputeHash($bytesToHash)
	$encodedHash = [Convert]::ToBase64String($calculatedHash)
	$signature = 'SharedKey {0}:{1}' -f $customerId, $encodedHash

	#Construct uri
	$uri = 'https://' + $customerId + '.ods.opinsights.azure.com' + $resource + '?api-version=2016-04-01'

	#validate that payload data does not exceed limits
	if ($body.Length -gt (31.9 * 1024 * 1024)) {
		throw('Upload payload is too big and exceed the 32Mb limit for a single upload. Please reduce the payload size. Current payload size is: ' + ($body.Length / 1024 / 1024).ToString('#.#') + 'Mb')
	}
	$payloadsize = ('Upload payload size is ' + ($body.Length / 1024).ToString('#.#') + 'Kb ')

	#Create authorization Header
	$headers = @{
		'Authorization'        = $signature;
		'Log-Type'             = $logType;
		'x-ms-date'            = $date;
		'time-generated-field' = $TimeStampField;
	}
	#Sending data to log analytics
	$response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
	$statusmessage = "$($response.StatusCode) : $($payloadsize)"
	return $statusmessage
}
#end function

# Start the main section ** You can make changes to the below if required ***

try {
	# Get the Device Serial Number
	$serial = (Get-CimInstance -Class Win32_BIOS).SerialNumber

	# Get the Hardware Hash
	$devDetail = Get-CimInstance -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'"
	$hash = $devDetail.DeviceHardwareData

	$cs = Get-CimInstance -Class Win32_ComputerSystem
	$make = $cs.Manufacturer.Trim()
	$model = $cs.Model.Trim()

	# Assuming the Windows Product ID is not available
	$product = ''

	# Create an object with the required properties
	$deviceInfo = [PSCustomObject]@{
		'Device Serial Number' = $serial
		'Windows Product ID'   = $product
		'Hardware Hash'        = $hash
		'Make'                 = $make
		'Model'                = $model
	}

} catch {
	Write-Error "Failed to retrieve information: $_"
}

# Convert to JSON and output
$AutopilotInfoJson = $deviceInfo | ConvertTo-Json

if ($CollectAutopilotHashInfo) {

	# Sending the data to Log Analytics Workspace
	# Submit the data to the API endpoint
	$ResponseOutput = Send-LogAnalyticsData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($AutopilotInfoJson)) -logType $AutopilotHashInfoLogName

	#Report back status
	$date = Get-Date -Format 'dd-MM HH:mm'
	$OutputMessage = "InventoryDate:$date "

	if ($ResponseOutput -match '200 :') {

		$OutputMessage = $OutPutMessage + 'AutopilotInfo:OK ' + $ResponseOutput
	} else {
		$OutputMessage = $OutPutMessage + 'AutopilotInfo:Fail '
	}
}

Write-Output $OutputMessage
Exit 0
#endregion script

