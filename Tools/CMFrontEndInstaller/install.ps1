# ConfigMgr Frontend Installer

Write-Host "-----------------------------"
Write-Host "ConfigMgr Frontend Installer"
Write-Host "Scott Keiffer, 2013"
Write-Host "-----------------------------"

$scriptPath=Split-Path -parent $MyInvocation.MyCommand.Definition

# Helper functions
#region Helper Functions
function DownloadFile($url, $targetFile)
{
   $ErrorActionPreference= 'silentlycontinue'
   $uri = New-Object "System.Uri" "$url"
   $request = [System.Net.HttpWebRequest]::Create($uri)
   $request.set_Timeout(15000) #15 second timeout
   $response = $request.GetResponse()
   if (!$?) { throw }
   $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
   $responseStream = $response.GetResponseStream()
   $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
   $buffer = new-object byte[] 10KB
   $count = $responseStream.Read($buffer,0,$buffer.length)
   $downloadedBytes = $count
   while ($count -gt 0)
   {
       $targetStream.Write($buffer, 0, $count)
       $count = $responseStream.Read($buffer,0,$buffer.length)
       $downloadedBytes = $downloadedBytes + $count
       Write-Progress -activity "Downloading file '$($url.split('/') | Select -Last 1)'" -status "Downloaded ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): " -PercentComplete ((([System.Math]::Floor($downloadedBytes/1024)) / $totalLength)  * 100)
   }
   Write-Progress -activity "Finished downloading file '$($url.split('/') | Select -Last 1)'"
   $targetStream.Flush()
   $targetStream.Close()
   $targetStream.Dispose()
   $responseStream.Dispose()
}

Function Test-RegistryValue {
    param(
        [Alias("PSPath")]
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [String]$Path
        ,
        [Parameter(Position = 1, Mandatory = $true)]
        [String]$Name
        ,
        [Switch]$PassThru
    ) 

    process {
        if (Test-Path $Path) {
            $Key = Get-Item -LiteralPath $Path
            if ($Key.GetValue($Name, $null) -ne $null) {
                if ($PassThru) {
                    Get-ItemProperty $Path $Name
                } else {
                    $true
                }
            } else {
                $false
            }
        } else {
            $false
        }
    }
}

Function Invoke-SqlQuery
{
    param(
    [Parameter(Mandatory=$true)] [string]$ServerInstance,
    [string]$Database,
    [Parameter(Mandatory=$true)] [string]$Query,
    [Int32]$QueryTimeout=600,
    [Int32]$ConnectionTimeout=15
    )

    try {
        $ConnectionString = "Server=$ServerInstance;Database=$Database;Integrated Security=True;Connect Timeout=$ConnectionTimeout"
        $conn=new-object System.Data.SqlClient.SQLConnection
        $conn.ConnectionString=$ConnectionString
        $conn.Open()
        $cmd=new-object system.Data.SqlClient.SqlCommand($Query,$conn)
        $cmd.CommandTimeout=$QueryTimeout
        $ds=New-Object system.Data.DataSet
        $da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd)
        [void]$da.fill($ds)
        Write-Output ($ds.Tables[0])
    }
    catch {
        throw 
    }
    finally {
        $conn.Dispose()
    }
}
#endregion
#$ErrorActionPreference = "SilentlyContinue"

# Get user input
$ADConnectionUsername = Read-Host "Enter domain service account username (use domain\user format)"
$ADConnectionPassword = Read-Host "Enter domain service account password" -AsSecureString
$ADAdminGroup = Read-Host "Enter frontend domain admin group (do NOT include domain)"
$ConfigMgrSiteServer = Read-Host "Enter ConfigMgr site server FQDN"
$ConfigMgrSQLServer = Read-Host "Enter ConfigMgr SQL server FQDN"
$ConfigMgrSiteCode = Read-Host "Enter ConfigMgr site code"
$ConfigMgrUsername = Read-Host "Enter ConfigMgr service account usename (use domain\user format)"
$ConfigMgrPassword = Read-Host "Enter ConfigMgr service account password" -AsSecureString
$SourcesDir = Read-Host "Enter win2012 sources directory (ie D:\sources\sxs)"
Write-Host "---"
if ([String]::IsNullOrWhiteSpace($SourcesDir)) { $SourcesDir = "D:\sources\sxs" }

# Check user input for correct format.
if (!($ConfigMgrUsername.Split("\")[1]) -or !($ADConnectionUsername.Split("\")[1]) -or ($ADAdminGroup.Split("\")[1])) 
{
    Write-Host -ForegroundColor Red "Usernames and/or groups in wrong format. Exiting"
    Break
} 

# Get AD info
$domainName = $env:USERDNSDOMAIN
$domainDN = (New-Object -TypeName adsi).distinguishedName

# Install SQL Express
if (!(Test-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server" -Name "InstalledInstances")) 
{
    # Download SQL if not present.
    if (!(Test-Path $scriptPath\SQLEXPR_x64_ENU.exe)) 
    {
        Write-Host "Downloading SQL Server 2012 SP1 Express..."
        DownloadFile -url "http://download.microsoft.com/download/5/2/9/529FEF7B-2EFB-439E-A2D1-A1533227CD69/SQLEXPR_x64_ENU.exe" -targ "$scriptPath\SQLEXPR_x64_ENU.exe"
        if(!$?) { Write-Host -ForegroundColor Red "Error downloading SQL Express installer." }
        if (!(Test-Path $scriptPath\SQLEXPR_x64_ENU.exe))
        {
            Write-warning "Could not find SQL Express installer, exiting."
            break
        }
    }
    Write-Host "Installing SQL Express..."
    & "$scriptPath\SQLEXPR_x64_ENU.exe" /QS /ACTION=Install /FEATURES=SQL /INSTANCENAME=MSSQLSERVER /SQLSYSADMINACCOUNTS="$ConfigMgrUsername" "$env:COMPUTERNAME\Administrators" /UpdateEnabled=False /IACCEPTSQLSERVERLICENSETERMS | Out-Null
}
else 
{
    Write-warning "SQL already installed, Install will probably need to be manually configured."
}

# Install Windows Features
Write-Host "Installing Windows Features..."
$features = "IIS-WebServerRole", "IIS-WebServer", "IIS-CommonHttpFeatures", "IIS-StaticContent", "IIS-DefaultDocument", "IIS-DirectoryBrowsing", "IIS-HttpErrors", "IIS-HttpRedirect", "IIS-ApplicationDevelopment", "IIS-WebSockets", "IIS-ApplicationInit", "IIS-NetFxExtensibility", "IIS-NetFxExtensibility45", "IIS-ASPNET", "IIS-ASPNET45", "IIS-ASP", "IIS-CGI", "IIS-ISAPIExtensions", "IIS-ISAPIFilter", "IIS-ServerSideIncludes", "IIS-HealthAndDiagnostics", "IIS-HttpLogging", "IIS-CustomLogging", "IIS-Security", "IIS-CertProvider", "IIS-BasicAuthentication", "IIS-WindowsAuthentication", "IIS-RequestFiltering", "IIS-Performance", "IIS-HttpCompressionStatic", "IIS-HttpCompressionDynamic", "IIS-WebServerManagementTools", "IIS-ManagementConsole"
Enable-WindowsOptionalFeature -Online -FeatureName $features -All -Source "$SourcesDir" -LimitAccess -NoRestart | Out-Null
if (!$?) 
{
    Write-Host -ForegroundColor Red "Error installing windows features. Source directory is probably wrong. Exiting."
    break
}

# Copy application files
Write-Host "Installing CMFrontend files..."
New-Item -ItemType directory -Path "$env:SystemDrive\ProgramData\CMFrontEnd" -Force | Out-Null
New-Item -ItemType directory -Path "${env:ProgramFiles(x86)}\CMFrontEnd" -Force | Out-Null
Copy-Item -Path "$scriptPath\Service\*" -Destination "${env:ProgramFiles(x86)}\CMFrontEnd\" -Recurse -Force | Out-Null
Copy-Item -Path "$scriptPath\Settings\*" -Destination "$env:SystemDrive\ProgramData\CMFrontEnd\" -Recurse -Force | Out-Null
Remove-Item "$env:SystemDrive\inetpub\wwwroot\*" -Recurse -Force | Out-Null
Copy-Item -Path "$scriptPath\Web\*" -Destination "$env:SystemDrive\inetpub\wwwroot\" -Recurse -Force | Out-Null

Write-Host "Making file adjustments..."
$moo = (Get-Content "$env:SystemDrive\ProgramData\CMFrontEnd\appSettings.config") | % { $_ -replace '_adgroup_', "$ADAdminGroup" `
 -replace '_aduser_', "$ADConnectionUsername" `
 -replace '_adpass_', [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ADConnectionPassword)) `
 -replace '_cmuser_', "$ConfigMgrUsername" `
 -replace '_cmpass_', [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ConfigMgrPassword)) `
 -replace '_cmserver_', "$ConfigMgrSiteServer" `
 -replace '_sqlserver_', "$ConfigMgrSQLServer" `
 -replace '_sitecode_', "$ConfigMgrSiteCode" `
 } | Set-Content "$env:SystemDrive\ProgramData\CMFrontEnd\appSettings.config" -force
(Get-Content "$env:SystemDrive\inetpub\wwwroot\Web.config") | % { $_ -replace '_ADString_', "$domainName" `
 -replace '_ADRPString_', "$domainDN"
} | Set-Content "$env:SystemDrive\inetpub\wwwroot\Web.config" -force

# ConfigMgr SQL checks and setup
Write-Host "Running ConfigMgr SQL checks..."
$ComputerWarrantyDBExists = Invoke-SqlQuery -ServerInstance $ConfigMgrSQLServer -Database master -Query "if exists (select * from sys.databases where name = 'ComputerWarranty') select * from sys.databases where name = 'ComputerWarranty'"
$ConfigMgrDatabase = "CM_$ConfigMgrSiteCode"
# Check if service account is in ConfigMgr SQL
$userTestResult = Invoke-SqlQuery -ServerInstance $ConfigMgrSQLServer -Database master -Query "Select name from syslogins where name = '$ConfigMgrUsername'"
if (!$userTestResult)
{
    Write-Host "Service account not found in ConfigMgr SQL server, setting up logins.."
    
    Invoke-SqlQuery -ServerInstance $ConfigMgrSQLServer -Database master -Query "create login [$ConfigMgrUsername] from windows; use $ConfigMgrDatabase; create user [$ConfigMgrUsername] for login [$ConfigMgrUsername];"
    if ($ComputerWarrantyDBExists) {
        Invoke-SqlQuery -ServerInstance $ConfigMgrSQLServer -Database master -Query "use ComputerWarranty; create user [$ConfigMgrUsername] for login [$ConfigMgrUsername];"
    }
}

# Check if service account can already read database, if not add it to role.
$roleTestResult = Invoke-SqlQuery -ServerInstance $ConfigMgrSQLServer -Database $ConfigMgrDatabase -query "select pp.name as rolename from sys.database_role_members roles JOIN sys.database_principals p ON roles.member_principal_id = p.principal_id JOIN sys.database_principals pp ON roles.role_principal_id = pp.principal_id where p.name = '$ConfigMgrUsername'"
if (!$?) 
{
    Write-Host -ForegroundColor Red "Error executing sql query. Exiting"
    Break
}

Write-Host "Setting ConfigMgr SQL permissions..."
if (!$roleTestResult -or !$roleTestResult.rolename -or $roleTestResult.rolename -notcontains "db_datareader")
{
    # Service account is not assigned to the db_datareader role. We need to add it.
    Invoke-SqlQuery -ServerInstance $ConfigMgrSQLServer -Database $ConfigMgrDatabase -query "exec sp_addrolemember 'db_datareader', '$ConfigMgrUsername'"
    if (!$?) 
    {
        Write-Host -ForegroundColor Red "Error executing sql query. Exiting"
        Break
    }
}

# Add permission to Dell/Lenovo warranty database if it exists
if ($ComputerWarrantyDBExists) {
    Invoke-SqlQuery -ServerInstance $ConfigMgrSQLServer -Database master -Query "use ComputerWarranty; exec sp_addrolemember 'db_datareader', '$ConfigMgrUsername'"
}
# IIS Configuration
Write-Host "Creating a self signed certificate..."

#Create self signed cert
$FQDN = [System.Net.Dns]::GetHostByName(($env:computerName)).HostName

$AlternativeNameType = @{
XCN_CERT_ALT_NAME_UNKNOWN = 0
XCN_CERT_ALT_NAME_OTHER_NAME = 1
XCN_CERT_ALT_NAME_RFC822_NAME = 2
XCN_CERT_ALT_NAME_DNS_NAME = 3
XCN_CERT_ALT_NAME_DIRECTORY_NAME = 5
XCN_CERT_ALT_NAME_URL = 7
XCN_CERT_ALT_NAME_IP_ADDRESS = 8
XCN_CERT_ALT_NAME_REGISTERED_ID = 9
XCN_CERT_ALT_NAME_GUID = 10
XCN_CERT_ALT_NAME_USER_PRINCIPLE_NAME = 11
}

$ObjectIdGroupId = @{
XCN_CRYPT_ANY_GROUP_ID = 0
XCN_CRYPT_HASH_ALG_OID_GROUP_ID = 1
XCN_CRYPT_ENCRYPT_ALG_OID_GROUP_ID = 2
XCN_CRYPT_PUBKEY_ALG_OID_GROUP_ID = 3
XCN_CRYPT_SIGN_ALG_OID_GROUP_ID = 4
XCN_CRYPT_RDN_ATTR_OID_GROUP_ID = 5
XCN_CRYPT_EXT_OR_ATTR_OID_GROUP_ID = 6
XCN_CRYPT_ENHKEY_USAGE_OID_GROUP_ID = 7
XCN_CRYPT_POLICY_OID_GROUP_ID = 8
XCN_CRYPT_TEMPLATE_OID_GROUP_ID = 9
XCN_CRYPT_LAST_OID_GROUP_ID = 9
XCN_CRYPT_FIRST_ALG_OID_GROUP_ID = 1
XCN_CRYPT_LAST_ALG_OID_GROUP_ID = 4
XCN_CRYPT_OID_DISABLE_SEARCH_DS_FLAG = 0x80000000
XCN_CRYPT_KEY_LENGTH_MASK = 0xffff0000
}

$X509KeySpec = @{
XCN_AT_NONE = 0 # The intended use is not identified.
# This value should be used if the provider is a
# Cryptography API: Next Generation (CNG) key storage provider (KSP).
XCN_AT_KEYEXCHANGE = 1 # The key can be used for encryption or key exchange.
XCN_AT_SIGNATURE = 2 # The key can be used for signing.
}

$X509PrivateKeyExportFlags = @{
XCN_NCRYPT_ALLOW_EXPORT_NONE = 0
XCN_NCRYPT_ALLOW_EXPORT_FLAG = 0x1
XCN_NCRYPT_ALLOW_PLAINTEXT_EXPORT_FLAG = 0x2
XCN_NCRYPT_ALLOW_ARCHIVING_FLAG = 0x4
XCN_NCRYPT_ALLOW_PLAINTEXT_ARCHIVING_FLAG = 0x8
}

$X509PrivateKeyUsageFlags = @{
XCN_NCRYPT_ALLOW_USAGES_NONE = 0
XCN_NCRYPT_ALLOW_DECRYPT_FLAG = 0x1
XCN_NCRYPT_ALLOW_SIGNING_FLAG = 0x2
XCN_NCRYPT_ALLOW_KEY_AGREEMENT_FLAG = 0x4
XCN_NCRYPT_ALLOW_ALL_USAGES = 0xffffff
}

$X509CertificateEnrollmentContext = @{
ContextUser = 0x1
ContextMachine = 0x2
ContextAdministratorForceMachine = 0x3
}

$X509KeyUsageFlags = @{
DIGITAL_SIGNATURE = 0x80 # Used with a Digital Signature Algorithm (DSA)
# to support services other than nonrepudiation,
# certificate signing, or revocation list signing.
KEY_ENCIPHERMENT = 0x20 # Used for key transport.
DATA_ENCIPHERMENT = 0x10 # Used to encrypt user data other than cryptographic keys.
}

$EncodingType = @{
XCN_CRYPT_STRING_BASE64HEADER = 0
XCN_CRYPT_STRING_BASE64 = 0x1
XCN_CRYPT_STRING_BINARY = 0x2
XCN_CRYPT_STRING_BASE64REQUESTHEADER = 0x3
XCN_CRYPT_STRING_HEX = 0x4
XCN_CRYPT_STRING_HEXASCII = 0x5
XCN_CRYPT_STRING_BASE64_ANY = 0x6
XCN_CRYPT_STRING_ANY = 0x7
XCN_CRYPT_STRING_HEX_ANY = 0x8
XCN_CRYPT_STRING_BASE64X509CRLHEADER = 0x9
XCN_CRYPT_STRING_HEXADDR = 0xa
XCN_CRYPT_STRING_HEXASCIIADDR = 0xb
XCN_CRYPT_STRING_HEXRAW = 0xc
XCN_CRYPT_STRING_NOCRLF = 0x40000000
XCN_CRYPT_STRING_NOCR = 0x80000000
}

$InstallResponseRestrictionFlags = @{
AllowNone = 0x00000000
AllowNoOutstandingRequest = 0x00000001
AllowUntrustedCertificate = 0x00000002
AllowUntrustedRoot = 0x00000004
}

$X500NameFlags = @{
XCN_CERT_NAME_STR_NONE = 0
XCN_CERT_SIMPLE_NAME_STR = 1
XCN_CERT_OID_NAME_STR = 2
XCN_CERT_X500_NAME_STR = 3
XCN_CERT_XML_NAME_STR = 4
XCN_CERT_NAME_STR_SEMICOLON_FLAG = 0x40000000
XCN_CERT_NAME_STR_NO_PLUS_FLAG = 0x20000000
XCN_CERT_NAME_STR_NO_QUOTING_FLAG = 0x10000000
XCN_CERT_NAME_STR_CRLF_FLAG = 0x8000000
XCN_CERT_NAME_STR_COMMA_FLAG = 0x4000000
XCN_CERT_NAME_STR_REVERSE_FLAG = 0x2000000
XCN_CERT_NAME_STR_FORWARD_FLAG = 0x1000000
XCN_CERT_NAME_STR_DISABLE_IE4_UTF8_FLAG = 0x10000
XCN_CERT_NAME_STR_ENABLE_T61_UNICODE_FLAG = 0x20000
XCN_CERT_NAME_STR_ENABLE_UTF8_UNICODE_FLAG = 0x40000
XCN_CERT_NAME_STR_FORCE_UTF8_DIR_STR_FLAG = 0x80000
XCN_CERT_NAME_STR_DISABLE_UTF8_DIR_STR_FLAG = 0x100000
}

$ObjectIdPublicKeyFlags = @{
XCN_CRYPT_OID_INFO_PUBKEY_ANY = 0
XCN_CRYPT_OID_INFO_PUBKEY_SIGN_KEY_FLAG = 0x80000000
XCN_CRYPT_OID_INFO_PUBKEY_ENCRYPT_KEY_FLAG = 0x40000000
}

$AlgorithmFlags = @{
AlgorithmFlagsNone = 0
AlgorithmFlagsWrap = 0x1
}

# Only the following RDNs are supported in the subject name
# IX500DistinguishedName Interface
# http://msdn.microsoft.com/en-us/library/aa377051%28v=VS.85%29.aspx
# C, CN, E, EMAIL, DC, G, GivenName, I, L, O, OU, S, ST, STREET, SN, T, TITLE

# Note we build the subject as CN=subject
$subjectName = "CN=" + $FQDN.ToLower()
$objSubjectDN = New-Object -ComObject X509Enrollment.CX500DistinguishedName
$objSubjectDN.Encode($subjectName, $X500NameFlags.XCN_CERT_NAME_STR_NONE)

# Build a private key
$objKey = New-Object -ComObject X509Enrollment.CX509PrivateKey
$objKey.ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
$objKey.KeySpec = $X509KeySpec.XCN_AT_KEYEXCHANGE
$objKey.KeyUsage = $X509PrivateKeyUsageFlags.XCN_NCRYPT_ALLOW_ALL_USAGES
$objKey.Length = 2048
$objKey.MachineContext = $TRUE
$objKey.ExportPolicy = $X509PrivateKeyExportFlags.XCN_NCRYPT_ALLOW_PLAINTEXT_EXPORT_FLAG
$objKey.Create()

# Add the Server Authentication EKU OID
$objServerAuthenticationOid = New-Object -ComObject X509Enrollment.CObjectId
$strServerAuthenticationOid = "1.3.6.1.5.5.7.3.1"
$objServerAuthenticationOid.InitializeFromValue($strServerAuthenticationOid)

$objEkuoids = New-Object -ComObject X509Enrollment.CObjectIds
$objEkuoids.add($objServerAuthenticationOid)
$objEkuext = New-Object -ComObject X509Enrollment.CX509ExtensionEnhancedKeyUsage
$objEkuext.InitializeEncode($objEkuoids)

# Set the Key Usage to Key Encipherment and Digital Signature
$keyUsageExt = New-Object -ComObject X509Enrollment.CX509ExtensionKeyUsage
$keyUsageExt.InitializeEncode($X509KeyUsageFlags.KEY_ENCIPHERMENT -bor `
$X509KeyUsageFlags.DIGITAL_SIGNATURE )

$strTemplateName = "" # We don't use a certificate template
$cert = New-Object -ComObject X509Enrollment.CX509CertificateRequestCertificate
# Notice we use $X509CertificateEnrollmentContext.ContextMachine
$cert.InitializeFromPrivateKey($X509CertificateEnrollmentContext.ContextMachine, `
   $objKey, `
   $strTemplateName)
$cert.X509Extensions.Add($keyUsageExt)
$cert.Subject = $objSubjectDN
$cert.Issuer = $cert.Subject

# Set the hash algorithm to sha256 instead of the default sha1
$hashAlgorithmObject = New-Object -ComObject X509Enrollment.CObjectId
$hashAlgorithmObject.InitializeFromAlgorithmName( `
$ObjectIdGroupId.XCN_CRYPT_HASH_ALG_OID_GROUP_ID, `
$ObjectIdPublicKeyFlags.XCN_CRYPT_OID_INFO_PUBKEY_ANY, `
$AlgorithmFlags.AlgorithmFlagsNone, "SHA256")
$cert.HashAlgorithm = $hashAlgorithmObject

# We subtract one day from the start time to avoid timezone or other 
#   time issues where cert is not yet valid
$SubtractDays = New-Object System.TimeSpan 1, 0, 0, 0, 0
$curdate = get-date
$cert.NotBefore = $curdate.Subtract($SubtractDays)
$cert.NotAfter = $cert.NotBefore.AddDays(365*2)
$cert.X509Extensions.Add($objEkuext)
$cert.Encode()

# Now we create the cert from the request we have built up and 
#   install it into the certificate store
$enrollment = New-Object -ComObject X509Enrollment.CX509Enrollment
$enrollment.InitializeFromRequest($cert)
$enrollment.CertificateFriendlyName = 'CMFrontEndSelfSigned'
$certdata = $enrollment.CreateRequest($EncodingType.XCN_CRYPT_STRING_BASE64HEADER)
$strPassword = ""
$enrollment.InstallResponse($InstallResponseRestrictionFlags.AllowUntrustedCertificate, `
  $certdata, $EncodingType.XCN_CRYPT_STRING_BASE64HEADER, $strPassword)


#Find new enrolled cert
$installedCert = $Null
foreach ($curcert in Get-ChildItem cert:\LocalMachine\My) { 
	if ($curcert.Subject -eq ("CN=" + $FQDN)) {
		$installedCert = $curcert
	}
}

if (!$installedCert) 
{
    Write-Host -ForegroundColor Red "Unable to find self signed cert. Exiting"
    Break
}

Write-Host "Configuring IIS..."
Import-Module WebAdministration
if (!$?) 
{
    Write-Host -ForegroundColor Red "Unable to load IIS module. Exiting"
    Break
}

$existingBinding = Get-WebBinding -Protocol https
if (!$existingBinding)
{
    New-WebBinding -Name "Default Web Site" -IP "*" -Port 443 -Protocol https | Out-Null
    New-Item IIS:SslBindings\0.0.0.0!443 -Value $installedCert | Out-Null
}
Set-ItemProperty iis:\apppools\DefaultAppPool -name processModel -value @{userName="$ConfigMgrUsername";password="$([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ConfigMgrPassword)))";identitytype=3}

Write-Host "Adding service account to local admin group..."
$de = [ADSI]"WinNT://$env:ComputerName/Administrators,group"
$de.psbase.invoke("Add",([ADSI]"WinNT://$($ConfigMgrUsername.Split("\")[0])/$($ConfigMgrUsername.Split("\")[1])").path)

# Install service
Write-Host "Installing Service..."
#$flippedUsername = "$($ConfigMgrUsername.Split("\")[1])@$env:userdnsdomain"
#& "${env:ProgramFiles(x86)}\CMFrontEnd\FrontendBackgroundService.exe" install -username:$flippedUsername -password:"$([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ConfigMgrPassword)))" | Out-Null
$serviceCred = new-object -typename System.Management.Automation.PSCredential -argumentlist $ConfigMgrUsername, $ConfigMgrPassword
New-Service -Name "CMFrontEndBkg" -DisplayName "ConfigMgr FrontEnd Background Tasks" -Description "Configuration Manager Frontend background task runner" -StartupType Automatic -BinaryPathName "${env:ProgramFiles(x86)}\CMFrontEnd\FrontendBackgroundService.exe" -Credential $serviceCred | Out-Null
$installedService = Get-Service "cmfrontendbkg" -ErrorAction SilentlyContinue
if (!$installedService) 
{
    Write-Host -ForegroundColor Red "Service failed to install, Exiting"
    Break
}
Write-Host "Starting Service..."
Start-Service "CMFrontEndBkg" | Out-Null

Write-Host "Restarting IIS..."
& iisreset | Out-Null
Write-Host -ForegroundColor Green "Installation complete!"