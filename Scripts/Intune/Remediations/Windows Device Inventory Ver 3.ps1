<#
.SYNOPSIS
    Collect custom device inventory and upload to Log Analytics for further processing. 

.DESCRIPTION
    This script will collect device hardware and / or app inventory and upload this to a Log Analytics Workspace. This allows you to easily search in device hardware and installed apps inventory. 
    The script is meant to be runned on a daily schedule either via Proactive Remediations (RECOMMENDED) in Intune or manually added as local schedule task on your Windows Computer. 

.EXAMPLE
    Invoke-CustomInventory.ps1 (Required to run as System or Administrator)      

.NOTES
    FileName:    Invoke-CustomInventory.ps1
    Based on script by Nickolaj Andersen
    Updated version with custom inventory: Eswar Koneti 07-Mar-2024
    
#>   

#region initialize
# Enable TLS 1.2 support 
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# Replace with your Log Analytics Workspace ID
$CustomerId = "123456-4545454545454545"  

# Replace with your Primary Key
$SharedKey = "eeerererererererererer"

#Control if you want to collect App or Device Inventory or both (True = Collect)
$CollectAppInventory = $true
$CollectDeviceInventory = $true
$CollectLAR = $true

$AppLogName = "AppInventory"
$DeviceLogName = "DeviceInventory"
$LARLogName = "LARInventory"
$Date = (Get-Date)

# You can use an optional field to specify the timestamp from the data. If the time field is not specified, Azure Monitor assumes the time is the message ingestion time
# DO NOT DELETE THIS VARIABLE. Recommened keep this blank. 
$TimeStampField = ""

#endregion initialize

#region functions
function Get-AzureADTenantID {
	# Cloud Join information registry path
	$AzureADTenantInfoRegistryKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\TenantInfo"
	# Retrieve the child key name that is the tenant id for AzureAD
	$AzureADTenantID = Get-ChildItem -Path $AzureADTenantInfoRegistryKeyPath | Select-Object -ExpandProperty "PSChildName"
	return $AzureADTenantID
}#end function
# Function to get Azure AD DeviceID
function Get-AzureADDeviceID {
    <#
    .SYNOPSIS
        Get the Azure AD device ID from the local device.
    
    .DESCRIPTION
        Get the Azure AD device ID from the local device.
    
   #>
	Process {
		# Define Cloud Domain Join information registry path
		$AzureADJoinInfoRegistryKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo"
		
		# Retrieve the child key name that is the thumbprint of the machine certificate containing the device identifier guid
		$AzureADJoinInfoThumbprint = Get-ChildItem -Path $AzureADJoinInfoRegistryKeyPath | Select-Object -ExpandProperty "PSChildName"
		if ($AzureADJoinInfoThumbprint -ne $null) {
			# Retrieve the machine certificate based on thumbprint from registry key
			$AzureADJoinCertificate = Get-ChildItem -Path "Cert:\LocalMachine\My" -Recurse | Where-Object { $PSItem.Thumbprint -eq $AzureADJoinInfoThumbprint }
			if ($AzureADJoinCertificate -ne $null) {
				# Determine the device identifier from the subject name
				$AzureADDeviceID = ($AzureADJoinCertificate | Select-Object -ExpandProperty "Subject") -replace "CN=", ""
				# Handle return value
				return $AzureADDeviceID
			}
		}
	}
} #endfunction 

# Function to get Azure AD Device Join Date
function Get-AzureADJoinDate {
    <#
    .SYNOPSIS
        Get the Azure AD device join date 
    
    .DESCRIPTION
        Get the Azure AD device join date 
    
    .NOTES
 
    #>
	Process {
		# Define Cloud Domain Join information registry path
		$AzureADJoinInfoRegistryKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo"
		
		# Retrieve the child key name that is the thumbprint of the machine certificate containing the device identifier guid
		$AzureADJoinInfoThumbprint = Get-ChildItem -Path $AzureADJoinInfoRegistryKeyPath | Select-Object -ExpandProperty "PSChildName"
		if ($AzureADJoinInfoThumbprint -ne $null) {
			# Retrieve the machine certificate based on thumbprint from registry key
			$AzureADJoinCertificate = Get-ChildItem -Path "Cert:\LocalMachine\My" -Recurse | Where-Object { $PSItem.Thumbprint -eq $AzureADJoinInfoThumbprint }
			if ($AzureADJoinCertificate -ne $null) {
				# Determine the device identifier from the subject name
				$AzureADJoinDate = ($AzureADJoinCertificate | Select-Object -ExpandProperty "NotBefore") 
				# Handle return value
				return $AzureADJoinDate
			}
		}
	}
} #endfunction 


# Function to get all Installed Application
function Get-InstalledApplications() {
    param(
        [string]$UserSid
    )
    
    New-PSDrive -PSProvider Registry -Name "HKU" -Root HKEY_USERS | Out-Null
    $regpath = @("HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*")
    $regpath += "HKU:\$UserSid\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    if (-not ([IntPtr]::Size -eq 4)) {
        $regpath += "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        $regpath += "HKU:\$UserSid\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    }
    $propertyNames = 'DisplayName', 'DisplayVersion', 'Publisher', 'UninstallString'
    $Apps = Get-ItemProperty $regpath -Name $propertyNames -ErrorAction SilentlyContinue | . { process { if ($_.DisplayName) { $_ } } } | Select-Object DisplayName, DisplayVersion, Publisher, UninstallString, PSPath | Sort-Object DisplayName   
    Remove-PSDrive -Name "HKU" | Out-Null
    Return $Apps
}#end function

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
#Function to get AzureAD TenantID


function Get-SecureBootStatus {
    $SecureBootEnabled = if (Confirm-SecureBootUEFI) { "Enabled" } else { "Disabled" }
    return $SecureBootEnabled
}

#Check Windows hello
function Get-WindowsHelloStatus {
    # Define machine-wide registry paths
    $PinKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\{D6886603-9D2F-4EB2-B667-1971041FA96B}"
    $BioKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WinBio\AccountInfo"

    # Initialize output
    $windowsHelloEnabled = $false

    # Check if the PIN key exists and whether it has relevant values
    if (Test-Path -Path $PinKeyPath) {
        # Check for all user SIDs under the PIN key
        $userSIDs = Get-ChildItem -Path $PinKeyPath
        foreach ($userSID in $userSIDs) {
            $pinValue = Get-ItemProperty -Path $userSID.PSPath -Name "LogonCredsAvailable" -ErrorAction SilentlyContinue
            if ($pinValue.LogonCredsAvailable -eq 1) {
                $windowsHelloEnabled = $true
                break
            }
        }
    }

    # Check if the biometric key exists
    if (Test-Path -Path $BioKeyPath) {
        # Check for all user SIDs under the biometric key
        $userSIDs = Get-ChildItem -Path $BioKeyPath
        foreach ($userSID in $userSIDs) {
            $bioValue = Get-ItemProperty -Path $userSID.PSPath -Name "EnrolledFactors" -ErrorAction SilentlyContinue
            if ($bioValue.EnrolledFactors -ne 0) {
                $windowsHelloEnabled = $true
                break
            }
        }
    }

    # Output result
    if ($windowsHelloEnabled) {
        return "Enable"
    } else {
        return "Disabled"
    }
}

#Check CredentialGuardStatus
function Get-CredentialGuardStatus {
    $keyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
    $guardEnabled = $false

    if (Test-Path -Path $keyPath) {
        $settings = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue
        if ($settings -and $settings.EnableVirtualizationBasedSecurity -eq 1) {
            $guardEnabled = $true
        }
    }

    if ($guardEnabled) {
        return "Enabled"
    } else {
        return "Disabled"
    }
}

#Check BIOS Mode

function Get-BiosMode {
    $firmwareType = (Get-WmiObject -Class Win32_ComputerSystem).BootupState

    if ($firmwareType -eq "Normal boot") {
        # Check if UEFI is supported
        $uefi = (Get-WmiObject -Class Win32_OperatingSystem).OSArchitecture
        if ($uefi -eq "64-bit") {
            return "UEFI"
        }
    } elseif ($firmwareType -eq "Safe boot") {
        return "Safe"
    }

    return "Legacy"
}

# Function to retrieve local administrators 
# On devices that are Entra joined only , the local admin user information is not available yet. The following only gets the data from mfcgd joined devices.
function Get-LocalAdminMembers {
    param ()

    # Get local members of the "Administrators" group
    $localAdminMembers = net localgroup Administrators | Where-Object {$_ -and $_ -notmatch '^Alias|^Comment|^---|^The command completed|^There are no entries|^The request will be processed|^successfully completed'} | ForEach-Object {
        [PSCustomObject]@{
            Account  = $_
            DeviceName   = $env:COMPUTERNAME
            Type     = 'Unknown'
            GroupName     = 'Administrators'
        }
    }

    # Determine if accounts are local or domain-based
    foreach ($admin in $localAdminMembers) {
        # Skip entries that represent the group itself
        if ($admin.Account -ne "Members") {
            $account = Get-LocalUser -Name $admin.Account -ErrorAction SilentlyContinue
            if ($account) {
                $admin.Type = 'Local'
            } else {
                $admin.Type = 'Domain'
            }

            $admin
        }
    }
}
#endregion functions

#region script
#Get Common data for App and Device Inventory: 
#Get Intune DeviceID and ManagedDeviceName
if (@(Get-ChildItem HKLM:SOFTWARE\Microsoft\Enrollments\ -Recurse | Where-Object { $_.PSChildName -eq 'MS DM Server' })) {
    $MSDMServerInfo = Get-ChildItem HKLM:SOFTWARE\Microsoft\Enrollments\ -Recurse | Where-Object { $_.PSChildName -eq 'MS DM Server' }
    $ManagedDeviceInfo = Get-ItemProperty -LiteralPath "Registry::$($MSDMServerInfo)"
}
$ManagedDeviceName = $ManagedDeviceInfo.EntDeviceName
$ManagedDeviceID = $ManagedDeviceInfo.EntDMID
$AzureADDeviceID = Get-AzureADDeviceID
$AzureADTenantID = Get-AzureADTenantID

#Get Computer Info
$ComputerInfo = Get-CimInstance -ClassName Win32_ComputerSystem
$ComputerName = $ComputerInfo.Name
$ComputerManufacturer = $ComputerInfo.Manufacturer
$ComputerOSInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$ComputerLastBoot = $ComputerOSInfo.LastBootUpTime
$ComputerUptime = [int](New-TimeSpan -Start $ComputerLastBoot -End $Date).Days
$Bios=get-ciminstance -ClassName win32_bios
$SerialNumber=$bios.serialnumber
$SMBIOSBIOSVersion=$Bios.SMBIOSBIOSVersion

#region DEVICEINVENTORY

if ($CollectDeviceInventory) {
# Get Computer Inventory Information 
	try {
		$TPMValues = Get-Tpm -ErrorAction SilentlyContinue | Select-Object -Property TPMReady, TPMPresent, TPMEnabled, TPMActivated, ManagedAuthLevel
	} catch {
		$TPMValues = $null
	}
	
	try {
		$ComputerTPMThumbprint = (Get-TpmEndorsementKeyInfo).AdditionalCertificates.Thumbprint
	} catch {
		$ComputerTPMThumbprint = $null
	}
	
	try {
		$TPMInfo = Get-WmiObject -Namespace 'root/cimv2/Security/MicrosoftTpm' -Class 'Win32_Tpm' | Select-Object -Property ManufacturerId, ManufacturerIdTxt, ManufacturerVersion, ManufacturerVersionFull20, ManufacturerVersionInfo, PhysicalPresenceVersionInfo, SpecVersion
	}
	catch {
		$TPMInfo = $null
	}
	try {
		$BitLockerInfo = Get-BitLockerVolume -MountPoint $env:SystemDrive | Select-Object -Property *
	} catch {
		$BitLockerInfo = $null
	}
# Get Computer Inventory Information

	$ComputerTPMReady = $TPMValues.TPMReady
	$ComputerTPMPresent = $TPMValues.TPMPresent
	$ComputerTPMEnabled = $TPMValues.TPMEnabled
	$ComputerTPMActivated = $TPMValues.TPMActivated
	$ComputerTPMInfoManufacturerId = $TPMInfo.ManufacturerId
	$ComputerTPMInfoManufacturerIdTxt = $TPMInfo.ManufacturerIdTxt
	$ComputerTPMInfoManufacturerVersion = $TPMInfo.ManufacturerVersion
	$ComputerTPMInfoManufacturerVersionFull20 = $TPMInfo.ManufacturerVersionFull20
	$ComputerTPMInfoManufacturerVersionInfo = $TPMInfo.ManufacturerVersionInfo
	$ComputerTPMInfoPhysicalPresenceVersionInfo = $TPMInfo.PhysicalPresenceVersionInfo
	$ComputerTPMInfoSpecVersion = $TPMInfo.SpecVersion
	$ComputerBitlockerCipher = $BitLockerInfo.EncryptionMethod
	$ComputerBitlockerStatus = $BitLockerInfo.VolumeStatus
	$ComputerBitlockerProtection = $BitLockerInfo.ProtectionStatus

	#Get network adapters
	$NetWorkArray = @()
	
	$CurrentNetAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
	
	foreach ($CurrentNetAdapter in $CurrentNetAdapters) {
		try{
			$IPConfiguration = Get-NetIPConfiguration -InterfaceIndex $CurrentNetAdapter[0].ifIndex -ErrorAction Stop
		}
		catch{
			$IPConfiguration = $null
		}
		$ComputerNetInterfaceDescription = $CurrentNetAdapter.InterfaceDescription
		#$ComputerNetProfileName = $IPConfiguration.NetProfile.Name
		$ComputerNetIPv4Adress = $IPConfiguration.IPv4Address.IPAddress
		$ComputerNetInterfaceAlias = $CurrentNetAdapter.InterfaceAlias
		$ComputerNetIPv4DefaultGateway = $IPConfiguration.IPv4DefaultGateway.NextHop
		$ComputerNetMacAddress = $CurrentNetAdapter.MacAddress
		
		$tempnetwork = New-Object -TypeName PSObject
		$tempnetwork | Add-Member -MemberType NoteProperty -Name "NetInterfaceDescription" -Value "$ComputerNetInterfaceDescription" -Force
		#$tempnetwork | Add-Member -MemberType NoteProperty -Name "NetProfileName" -Value "$ComputerNetProfileName" -Force
		$tempnetwork | Add-Member -MemberType NoteProperty -Name "NetIPv4Adress" -Value "$ComputerNetIPv4Adress" -Force
		$tempnetwork | Add-Member -MemberType NoteProperty -Name "NetInterfaceAlias" -Value "$ComputerNetInterfaceAlias" -Force
		$tempnetwork | Add-Member -MemberType NoteProperty -Name "NetIPv4DefaultGateway" -Value "$ComputerNetIPv4DefaultGateway" -Force
		$tempnetwork | Add-Member -MemberType NoteProperty -Name "MacAddress" -Value "$ComputerNetMacAddress" -Force
		$NetWorkArray += $tempnetwork
	}
	[System.Collections.ArrayList]$NetWorkArrayList = $NetWorkArray
        
    # Call function to get Secure Boot status
    $SecureBootStatus = Get-SecureBootStatus

    #call function to get windows hello
    $WindowsHello=Get-WindowsHelloStatus

    # Call the function and output the result
    $CredentialGuard=Get-CredentialGuardStatus

    #Call Bios function and output results
    $BiosMode=Get-BiosMode
           
 # Create JSON to Upload to Log Analytics
   # Create JSON to Upload to Log Analytics
	$Inventory = New-Object System.Object
	$Inventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceName" -Value "$ManagedDeviceName" -Force
    $Inventory | Add-Member -MemberType NoteProperty -Name "AzureADDeviceID" -Value "$AzureADDeviceID" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceID" -Value "$ManagedDeviceID" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value "$ComputerName" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "ComputerUpTime" -Value "$ComputerUptime" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "LastBoot" -Value "$ComputerLastBoot" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "TPMReady" -Value "$ComputerTPMReady" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "TPMPresent" -Value "$ComputerTPMPresent" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "TPMEnabled" -Value "$ComputerTPMEnabled" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "TPMActived" -Value "$ComputerTPMActivated" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "TPMThumbprint" -Value "$ComputerTPMThumbprint" -Force
    $Inventory | Add-Member -MemberType NoteProperty -Name "SecureBoot" -Value "$SecureBootStatus" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "TPMInfoManufacturerId" -Value "$ComputerTPMInfoManufacturerId" -Force
    $Inventory | Add-Member -MemberType NoteProperty -Name "TPMInfoManufacturerIdTxt" -Value "$ComputerTPMInfoManufacturerIdTxt" -Force
    $Inventory | Add-Member -MemberType NoteProperty -Name "TPMInfoManufacturerVersion" -Value "$ComputerTPMInfoManufacturerVersion" -Force
    $Inventory | Add-Member -MemberType NoteProperty -Name "TPMInfoManufacturerVersionFull20" -Value "$ComputerTPMInfoManufacturerVersionFull20" -Force
    $Inventory | Add-Member -MemberType NoteProperty -Name "TPMInfoManufacturerVersionInfo" -Value "$ComputerTPMInfoManufacturerVersionInfo " -Force
    $Inventory | Add-Member -MemberType NoteProperty -Name "TPMInfoPhysicalPresenceVersionInfo" -Value "$ComputerTPMInfoPhysicalPresenceVersionInfo" -Force
    $Inventory | Add-Member -MemberType NoteProperty -Name "TPMInfoSpecVersion" -Value "$ComputerTPMInfoSpecVersion" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "BitlockerCipher" -Value "$ComputerBitlockerCipher" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "BitlockerVolumeStatus" -Value "$ComputerBitlockerStatus" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "BitlockerProtectionStatus" -Value "$ComputerBitlockerProtection" -Force
	$Inventory | Add-Member -MemberType NoteProperty -Name "NetworkAdapters" -Value $NetWorkArrayList -Force
    $Inventory | Add-Member -MemberType NoteProperty -Name "SerialNumber" -Value $SerialNumber -Force
    $Inventory | Add-Member -MemberType NoteProperty -Name "SMBIOSBIOSVersion" -Value $SMBIOSBIOSVersion -Force
    $Inventory | Add-Member -MemberType NoteProperty -Name "WindowsHello" -Value $WindowsHello -Force
    $Inventory | Add-Member -MemberType NoteProperty -Name "CredentialGuard" -Value $CredentialGuard -Force
    $Inventory | Add-Member -MemberType NoteProperty -Name "BiosMode" -Value $BiosMode -Force

    $DevicePayLoad = $Inventory
	
}
#endregion DEVICEINVENTORY

#region APPINVENTORY
if ($CollectAppInventory) {
	#$AppLog = "AppInventory"
	
	#Get SID of current interactive users
	$CurrentLoggedOnUser = (Get-CimInstance win32_computersystem).UserName
	if (-not ([string]::IsNullOrEmpty($CurrentLoggedOnUser))) {
		$AdObj = New-Object System.Security.Principal.NTAccount($CurrentLoggedOnUser)
		$strSID = $AdObj.Translate([System.Security.Principal.SecurityIdentifier])
		$UserSid = $strSID.Value
	} else {
		$UserSid = $null
	}
	
	#Get Apps for system and current user
	$MyApps = Get-InstalledApplications -UserSid $UserSid
	$UniqueApps = ($MyApps | Group-Object Displayname | Where-Object { $_.Count -eq 1 }).Group
	$DuplicatedApps = ($MyApps | Group-Object Displayname | Where-Object { $_.Count -gt 1 }).Group
	$NewestDuplicateApp = ($DuplicatedApps | Group-Object DisplayName) | ForEach-Object { $_.Group | Sort-Object [version]DisplayVersion -Descending | Select-Object -First 1 }
	$CleanAppList = $UniqueApps + $NewestDuplicateApp | Sort-Object DisplayName
	
	$AppArray = @()
	foreach ($App in $CleanAppList) {
		$tempapp = New-Object -TypeName PSObject
		$tempapp | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value "$ComputerName" -Force
		$tempapp | Add-Member -MemberType NoteProperty -Name "ManagedDeviceName" -Value "$ManagedDeviceName" -Force
		$tempapp | Add-Member -MemberType NoteProperty -Name "ManagedDeviceID" -Value "$ManagedDeviceID" -Force
		$tempapp | Add-Member -MemberType NoteProperty -Name "AppName" -Value $App.DisplayName -Force
		$tempapp | Add-Member -MemberType NoteProperty -Name "AppVersion" -Value $App.DisplayVersion -Force
		$tempapp | Add-Member -MemberType NoteProperty -Name "AppInstallDate" -Value $App.InstallDate -Force -ErrorAction SilentlyContinue
		$tempapp | Add-Member -MemberType NoteProperty -Name "AppPublisher" -Value $App.Publisher -Force
		$tempapp | Add-Member -MemberType NoteProperty -Name "AppUninstallString" -Value $App.UninstallString -Force
		$tempapp | Add-Member -MemberType NoteProperty -Name "AppUninstallRegPath" -Value $app.PSPath.Split("::")[-1]
		$AppArray += $tempapp
	}
	
	$AppPayLoad = $AppArray
}
#endregion APPINVENTORY

if ($CollectLAR)
{
$localAdminMembers = Get-LocalAdminMembers
}

# Sending the data to Log Analytics Workspace
$Devicejson = $DevicePayLoad | ConvertTo-Json
$Appjson = $AppPayLoad | ConvertTo-Json
$localAdminJson = $localAdminMembers | ConvertTo-Json

# Submit the data to the API endpoint
#$ResponseDeviceInventory = Send-LogAnalyticsData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($Devicejson)) -logType $DeviceLogName
#$ResponseAppInventory = Send-LogAnalyticsData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($Appjson)) -logType $AppLogName
#$ResponseLARInventory = Send-LogAnalyticsData -customerId $customerId -sharedKey $sharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($localAdminJson)) -logType $LARLogName

#Report back status
$date = Get-Date -Format "dd-MM HH:mm"
$OutputMessage = "InventoryDate:$date "


if ($CollectDeviceInventory) {
    if ($ResponseDeviceInventory -match "200 :") {
        
        $OutputMessage = $OutPutMessage + "DeviceInventory:OK " + $ResponseDeviceInventory
    }
    else {
        $OutputMessage = $OutPutMessage + "DeviceInventory:Fail "
    }
}
if ($CollectAppInventory) {
    if ($ResponseAppInventory -match "200 :") {
        
        $OutputMessage = $OutPutMessage + " AppInventory:OK " + $ResponseAppInventory
    }
    else {
        $OutputMessage = $OutPutMessage + " AppInventory:Fail "
    }
}
if ($CollectLAR) {
    if ($ResponseLARInventory -match "200 :") {
        
        $OutputMessage = $OutPutMessage + "LARInventory:OK " + $ResponseLARInventory
    }
    else {
        $OutputMessage = $OutPutMessage + "LARInventory:Fail "
    }
}

Write-Output $OutputMessage
Exit 0
#endregion script