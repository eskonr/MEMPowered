
<#PSScriptInfo
 
.VERSION 1.0.0
 
.GUID 163529f1-bbbd-4228-8e59-445c2be3d870
 
.AUTHOR carmenf
 
.COMPANYNAME Microsoft
 
.COPYRIGHT
 
.TAGS
 
.LICENSEURI
 
.PROJECTURI
 
.ICONURI
 
.EXTERNALMODULEDEPENDENCIES
 
.REQUIREDSCRIPTS
 
.EXTERNALSCRIPTDEPENDENCIES
 
.RELEASENOTES The Delivery Optimization Troubleshooter Tool can be used to verify device settings are properly
configured to use Delivery Optimization.
#>

<#
 
.DESCRIPTION
 Delivery Optimization Troubleshooter Tool
 
#> 
[CmdLetBinding()]

Param()

#----------------------------------------------------------------------------------#
# Print Functions

Add-Type -TypeDefinition @"
    public enum TestResult
    {
        Unset,
        Fail,
        Pass,
        Disabled,
        Warn,
    }
"@

function Print-Result([string] $outputName, [string] $outputMsg, [TestResult] $result)
{
    $outputName = AddSpace($outputName)
    Write-Host $outputName -NoNewline

    switch ($result)
    {
        "Fail" { Write-Host -ForegroundColor Red    "FAIL " -NoNewline }
        "Pass" { Write-Host -ForegroundColor Green  "PASS " -NoNewline }
        "Warn" { Write-Host -ForegroundColor Yellow "WARN " -NoNewline }
        "Disabled" { Write-Host -ForegroundColor Yellow "DISABLED " -NoNewline }
        default { Write-Host -ForegroundColor Red   "ERROR " -NoNewline }
    }

    Write-Host $outputMsg
}

function Print-Header()
{
    $outputName = AddSpace("Test")
    Write-Host ""
    Write-Host $outputName -NoNewline
    Write-Host "Result " -NoNewline
    Write-Host "Details"
    $outputName = AddSpace("----")
    Write-Host $outputName -NoNewline
    Write-Host "------ " -NoNewline
    Write-Host "-------"
}

function AddSpace([string] $text)
{
    return $text + ' ' * (30 - $text.Length)
}

#----------------------------------------------------------------------------------#
# Device Check

function Check-AdminPrivileges([string] $invocationLine)
{
    if (IsElevated)
    {
        return $true;
    }
    
    $ScriptPath = $MyInvocation.PSCommandPath

    # The new process can't resolve working dir when script is launched like .\dolog.ps1, so we have to parse
    # and rebuild the full script path and param list.
    $scriptParams = ""
    $firstParam = $invocationLine.IndexOf('-')

    if($firstParam -gt 0)
    {
        $scriptParams = $invocationLine.Substring($firstParam-1)
    }

    $scriptCmd = "$ScriptPath $scriptParams"

    $arg = "-NoExit -Command `"$scriptCmd`""

    #Check Powershell version to use the right path
    if ($PSVersionTable.PSVersion.Major -lt 7)
    {
        $PSPath = "powershell.exe" 
    }
    else
    {
        $PSPath = "pwsh.exe"
    }
    
    $proc = Start-Process $PSPath -ArgumentList $arg -Verb Runas -ErrorAction Stop

    return $false
}

function IsElevated
{
    $wid = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $prp = new-object System.Security.Principal.WindowsPrincipal($wid)
    $adm = [System.Security.Principal.WindowsBuiltInRole]::Administrator
    $isElevated = $prp.IsInRole($adm)
    return $isElevated
}

function Check-NetInterface()
{
    $outputName = "Network Interface"
    $result = [TestResult]::Unset
    $msg = " "

    try
    {
        $query = "SELECT * FROM Win32_NetworkAdapter WHERE NOT PNPDeviceID LIKE 'ROOT\\%'"
        $interfaces = Get-WmiObject -Query $query | Sort index
        $networkInterface = @()
        
        #Save in a string all the interfaces found
        foreach ($interface in $interfaces)
        {
            $name = $interface.NetConnectionID
            $description = $interface.Name

            if ($name)
            {
               $networkInterface += "($name) $description "
            }
        }

        if ($networkInterface)
        {
            $msg = $networkInterface -join " - "
            $result = [TestResult]::Pass
        }
        else
        {
            $msg = "No network"
            $result = [TestResult]::Fail
        }

        Print-Result -outputMsg $msg -outputName $outputName -result $result
    }
    catch
    {
        Write-Error $_.Exception
    }
}

function Check-CacheFolder()
{
    $outputName = "Cache Folder Access"
    $result = [TestResult]::Unset
    $msg = ""

    try
    {
        $dosvcWorkingDir = $doConfig.WorkingDirectory
        if (!(Test-Path $dosvcWorkingDir)) { throw "Cache folder not found: $dosvcWorkingDir" }

        $acl = Get-Acl $dosvcWorkingDir

        $IdentityReferenceDO = "NT SERVICE\DoSvc"
        $IdentityReferenceNS = "NT AUTHORITY\NETWORK SERVICE"
        $inheritanceFlags = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor ([System.Security.AccessControl.InheritanceFlags]::ObjectInherit)

        # Filter to DO/NS permissions
        $permissionEntries = $acl.Access | where { @($IdentityReferenceDO, $IdentityReferenceNS) -contains $_.IdentityReference.Value }
        # This might be interesting here: Write-Verbose $permissionEntries

        # Look for Allow/FullControl/Full inheritance
        $permissionEntries = $permissionEntries | where { ($_.AccessControlType -eq "Allow") -and ($_.FileSystemRights -eq "FullControl") -and ($_.InheritanceFlags -eq $inheritanceFlags) }

        if ($permissionEntries)
        {
            $result = [TestResult]::Pass
        }
        else
        {
            $msg = "Required permissions missing"
            $result = [TestResult]::Fail
        }

        Print-Result -outputMsg $msg -outputName $outputName -result $result
    }
    catch
    {
        Write-Error "Cache folder permission check failed:" $_.Exception
    }
}

function Check-Service([string] $serviceName)
{
    $outputName = "Service Status"
    $result = [TestResult]::Unset
    $msg = ""

    try
    {
        $service = Get-Service -Name $serviceName
        if ($service -and ($service.StartType -ne "Disabled"))
        {
            if ($service.Status -eq "Running")
            {
                $msg = "$serviceName running"
                $result = [TestResult]::Pass
            }
            else
            {
                $msg = "$serviceName stopped"
                $result = [TestResult]::Warn
            }
        }
        else
        {
            $msg = "$serviceName disabled"
            $result = [TestResult]::Fail
        }

        Print-Result -outputMsg $msg -outputName $outputName -result $result
    }
    catch
    {
        Write-Error $_.Exception
    }
}

function Check-KeyAccess()
{
    $outputName = "Registry Key Access"
    $result = [TestResult]::Unset
    $msg = ""

    try
    {
        Remove-PSDrive HKU -ErrorAction SilentlyContinue

        $drive = New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS
        $testPath = Test-Path -Path HKU:\S-1-5-20\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization
        if (!$testPath) { throw "Registry Key not found" }
        # TODO: Check permissions on key

        # $doConfig.WorkingDirectory is the cache path, which may be redirected elsewhere. The state directory doesn't follow that redirection.
        $path = "$env:windir\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\State\dosvcState.dat"

        $testPath = Test-Path -Path $path -PathType Leaf
        if (!$testPath)
        {
            $msg = "Registry file not found"
            $result = [TestResult]::Fail
        }
        else
        {
            # TODO: Check permissions on file
            $result = [TestResult]::Pass
        }

        Print-Result -outputMsg $msg -outputName $outputName -result $result
    }
    catch
    {
        Write-Error $_.Exception
    }
    finally
    {
        Remove-PSDrive HKU -ErrorAction SilentlyContinue
    }
}

function Check-RAMRequired()
{
    $outputName = "RAM"
    $result = [TestResult]::Unset
    $msg = ""

    try
    {
        $totalRAM = (Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum | Select-Object -ExpandProperty Sum)/1GB

        if ($totalRAM -ge $doConfig.MinTotalRAM)
        {
            $msg = "$totalRAM GB"
            $result = [TestResult]::Pass
        }
        else
        {
            $msg = "Local RAM: $ramTotal GB | RAM Requirements: $minTotalRAM GB."
            $result = [TestResult]::Fail
        }

        Print-Result -outputMsg $msg -outputName $outputName -result $result
    }
    catch
    {
        Write-Error $_.Exception
    }
}

function Check-DiskRequired()
{
    $outputName = "Disk"
    $result = [TestResult]::Unset
    $msg = ""

    try
    {
        $diskSize = Get-WmiObject -Class win32_logicaldisk | Where-Object DeviceId -eq $env:SystemDrive | Select-Object @{N='Disk'; E={$_.DeviceId}}, @{N='Size'; E={[math]::Round($_.Size/1GB,2)}}, @{N='FreeSpace'; E={[math]::Round($_.FreeSpace/1GB,2)}}

        if ($diskSize.FreeSpace -ge $doConfig.MinTotalDiskSize)
        {
            $msg = $diskSize.Disk + " | Total Size: " + $diskSize.Size + "GB | Free Space: " + $diskSize.FreeSpace + "GB"
            $result = [TestResult]::Pass
        }
        else
        {
            $msg = "Free Space Requirements: $minDiskSize GB. | Local Free Space: $diskSize.FreeSpace GB"
            $result = [TestResult]::Fail
        }

        Print-Result -outputMsg $msg -outputName $outputName -result $result
    }
    catch
    {
        Write-Error $_.Exception
    }
}

function Check-Vpn()
{
    $outputName = "VPN"
    $result = [TestResult]::Unset
    $msg = ""

    try
    {
        $vpn = Get-VpnConnection
        if (!$vpn)
        {
            $result = [TestResult]::Pass
        }
        else
        {
            $activeVPN = $vpn | Where-Object ConnectionStatus -eq "Connected"  | Select-Object -ExpandProperty Name
            if ($activeVPN)
            {
                $msg = "Connected: $activeVPN"
                $result = [TestResult]::Warn
            }
            else
            {
                $AllVPN = (($vpn | Select-Object -ExpandProperty Name) -join " - ")
                $msg = "Not connected: $AllVPN"
                $result = [TestResult]::Pass
            }
        }

        Print-Result -outputMsg $msg -outputName $outputName -result $result
    }
    catch
    {
        Write-Error $_.Exception
    }
}

function Check-PowerBattery()
{
    $outputName = "Power"
    $result = [TestResult]::Unset
    $msg = ""

    try
    {
        $battery = Get-WmiObject -Class win32_battery

        #PC:
        if (!$battery)
        {
            $plan = Get-WmiObject -Class win32_powerplan -Namespace "root\cimv2\power" | Where-Object IsActive -eq true | Select-Object -ExpandProperty ElementName
            $msg = "A/C: $plan"
            $result = [TestResult]::Pass
        }
        #Notebook:
        else
        {
            $batteryPercentage = $battery.EstimatedChargeRemaining
            $batteryStatus = Get-WmiObject -Class BatteryStatus -Namespace root\wmi -ComputerName "localhost" -ErrorAction SilentlyContinue -ErrorVariable ProcessError
            
            if ($ProcessError)
            {
                $result = [TestResult]::Fail
                $msg = "WMI Error ( Check https://learn.microsoft.com/en-us/previous-versions/tn-archive/ff406382(v=msdn.10) ) | Error: " + $ProcessError.Exception
            }
            elseif ($batteryStatus.PowerOnline)
            {
                $result = [TestResult]::Pass
                $msg = "A/C: $batteryPercentage% (charging)"
            }
            else
            {
                $batteryLevelForSeeding = $doConfig.BatteryPctToSeed
                if ($batteryPercentage -ge $batteryLevelForSeeding)
                {
                    $result = [TestResult]::Pass
                }
                else
                {
                    $result = [TestResult]::Fail
                }
                $msg = "Battery: $batteryPercentage% ($batteryLevelForSeeding% required to upload)"
            }
        }

        Print-Result -outputMsg $msg -outputName $outputName -result $result
    }
    catch
    {
        Write-Error $_.Exception
    }
}

function Print-OSInfo()
{
    # Check OS Version
    $os = Get-WmiObject -Class Win32_OperatingSystem

    Write-Host "Windows" $os.Version -NoNewline

    switch ($os.BuildNumber)
    {
        "10240" { Write-Host " - TH1" }
        "10586" { Write-Host " - TH2" }
        "14393" { Write-Host " - RS1" }
        "15063" { Write-Host " - RS2" }
        "16299" { Write-Host " - RS3" }
        "17134" { Write-Host " - RS4" }
        "17763" { Write-Host " - RS5" }
        "18362" { Write-Host " - Titanium 19H1" }
        "18363" { Write-Host " - Vanadium 19H2" }
        "19041" { Write-Host " - Vibranium 20H1" }
        "19042" { Write-Host " - Vibranium (v2) 20H2" }
        "19645" { Write-Host " - Manganese" }
        "19043" { Write-Host " - Vibranium (v3) 21H1" }
        "19044" { Write-Host " - Vibranium (v4) 21H2" }
        "20348" { Write-Host " - Iron" }
        "22000" { Write-Host " - Cobalt" }
        "22621" { Write-Host " - Nickel" }
        default { Write-Host "" }
    }

    # Check UUS Version
    $uusVerPath = "$env:ProgramData\Microsoft\Windows\UUS\State\_active.uusver"
    if (Test-Path $uusVerPath)
    {
        $uusVersion = Get-Content $uusVerPath
        Write-Host "UUS" $uusVersion
    }
    
    $PSVersion = "PS Version " + $PSVersionTable.PSVersion
    Write-Verbose $PSVersion
}

#----------------------------------------------------------------------------------#
# Connection Check

function Test-Port([int] $port, [switch] $optional)
{
    $outputName = "Check Port"
    $oldPreference = $Global:ProgressPreference
    $result = [TestResult]::Unset
    $msg = "$port"

    try
    {
        $Global:ProgressPreference = 'SilentlyContinue'
        $resultTest = Test-NetConnection -Computer localhost -Port $port -WarningAction SilentlyContinue -InformationLevel 'Quiet'

        if ($resultTest)
        {
            $result = [TestResult]::Pass
        }
        else
        {
            $downloadMode = Check-DownloadMode -noOutput
            if (!$downloadMode -or $optional)
            {
                $result = [TestResult]::Warn
            }
            else
            {
                $result = [TestResult]::Fail
            }
        }

        Print-Result -outputMsg $msg -outputName $outputName -result $result
    }
    catch
    {
        Write-Error $_.Exception
    }
    finally
    {
        $Global:ProgressPreference = $oldPreference
    }
}

function Check-DownloadMode([switch] $noOutput)
{
    $outputName = "Download Mode"
    $msg = $doConfig.DownloadMode
    $result = [TestResult]::Fail

    $peerModes = @("Lan", "Group", "Internet")
    $downloadMode = $doConfig.DownloadMode
    if ($peerModes -contains $downloadMode)
    {
        $result = [TestResult]::Pass
    }

    if ($noOutput)
    {
        return ($result -eq "Pass")
    }

    Print-Result -outputMsg $msg -outputName $outputName -result $result
}

function Test-Hostname([string] $urlHostName, [switch] $noOutput)
{
    $outputName = "Host Connection"
    $msg = $urlHostName
    $result = [TestResult]::Unset

    try
    {
        $dnsHostnames = Resolve-DnsName $urlHostName | Select-Object -Unique -Property NameHost | % {[string]$_.NameHost}
        $dnsHostnames = $dnsHostnames | Where {!$_.Equals("")}

        $result = [TestResult]::Fail

        # Check if the list of hostnames is empty
        if ($dnsHostnames -eq $null)
        {
            $msg = "DNS resolution failed"
        }
        else
        {
            foreach($dnsHostname in $dnsHostnames)
            {
                $test = Test-Connection $dnsHostname -Quiet
                if ($test)
                {
                    $result = [TestResult]::Pass
                    break
                }
            }
        }

        if ($noOutput)
        {
            return ($result -eq "Pass")
        }

        Print-Result -outputMsg $msg -outputName $outputName -result $result
    }
    catch
    {
        Write-Error $_.Exception
    }
}

function Test-InternetInfo()
{
    # Check Request Timeout
    # Check if the Request comes back with a StatusCode error
    # Check if the Request comes back with a StatusCode 200 (success)
    # Check if the WebRequest comes back with Content-Type "text/json" (DO services all return json). Captive portal falls under here.
    # Check if the Json misses some information.

    $resultInt = [TestResult]::Unset
    $outputNameInt = "Internet Access"
    $msgInt = ""

    $resultIp = [TestResult]::Unset
    $outputNameIp = "External IP"
    $msgIp = "Not found"

    $url = "https://geo.prod.do.dsp.mp.microsoft.com/geo/"

    try
    {
        $httpResponse = Invoke-WebRequest -Uri $url
        if ($httpResponse.StatusCode -eq 200)
        {
            Write-Verbose $httpResponse.RawContent
            if ($httpResponse.Headers["Content-Type"] -eq "text/json")
            {
                $contentJson = ConvertFrom-Json $httpResponse.Content

                if (($contentJson.KeyValue_EndpointFullUri.Length -gt 0) -and ($contentJson.ExternalIpAddress.Length -gt 4))
                {
                    $resultInt = [TestResult]::Pass
                    $resultIp = [TestResult]::Pass
                    $msgIp = $contentJson.ExternalIpAddress
                }
                else
                {
                    $resultInt = [TestResult]::Fail
                    $resultIp = [TestResult]::Fail
                    $msgInt = "GEO response incomplete!"
                }
            }
            elseif ($httpResponse.Headers["Content-Type"] -eq "text/html")
            {
                $resultInt = [TestResult]::Warn
                $resultIp = [TestResult]::Fail
                $msgInt = "Possible captive portal detected!"
            }
            else
            {
                $resultInt = [TestResult]::Fail
                $resultIp = [TestResult]::Fail
                $msgInt = "Invalid GEO response!"
            }
        }
        else
        {
            $testHostname = Test-Hostname -urlHostName "https://www.microsoft.com/" -noOutput
            if ($testHostname)
            {
                $msgInt = "Internet access but unable to reach DO's GEO service. Status Code: $httpResponse.StatusCode - $httpResponse.StatusDescription"
                $resultInt = [TestResult]::Disabled
                $publicIp = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content
                if ($publicIp)
                {
                    $msgIp = "$publicIp"
                    $resultIp = [TestResult]::Pass
                }
                else
                {
                    $resultIp = [TestResult]::Fail
                }
            }
            else
            {
                $resultInt = [TestResult]::Fail
                $resultIp = [TestResult]::Fail
                $msgInt = "No internet access!"
            }
        }

        Print-Result -outputMsg $msgInt -outputName $outputNameInt -result $resultInt
        Print-Result -outputMsg $msgIp  -outputName $outputNameIp  -result $resultIp
    }
    catch
    {
        Write-Error $_.Exception
    }
}

function Check-ByteRange()
{
    $outputName = "HTTP Byte-Range Support"
    $result = [TestResult]::Unset
    $msg = ""

    try
    {
        $uri = "http://dl.delivery.mp.microsoft.com/filestreamingservice/files/52fa8751-747d-479d-8f22-e32730cc0eb1"
        $request = [System.Net.WebRequest]::Create($uri)
        
        # Set request
        $request.Method = "GET"
        $request.AddRange("bytes", 0, 9)
        
        $return = $request.GetResponse()
        $statusCode = [int]$return.StatusCode
        $contentRange = $return.GetResponseHeader("Content-Range")
        $msg = "$statusCode - " + $return.StatusCode + ", Content-Range: $contentRange"
        
        if(($statusCode -eq 206) -and ($contentRange -eq "bytes 0-9/25006511"))
        {
            $result = [TestResult]::Pass
        }
        else
        {
            $result = [TestResult]::Fail
        }
        Print-Result -outputMsg $msg -outputName $outputName -result $result
        Write-Verbose $return.Headers.ToString()
    }
    catch
    {
        Write-Error $_.Exception
    }
}

#----------------------------------------------------------------------------------#
# Main script

$admin = Check-AdminPrivileges($MyInvocation.Line)

if (!$admin)
{
    return
}

$doConfig = Get-DOConfig -Verbose

Write-Host ""

Print-OSInfo

Print-Header

Check-DownloadMode

Check-NetInterface

Test-InternetInfo

Check-Service -serviceName "dosvc"

# 7680 - DO port
Test-Port -port 7680

# 3544 - Teredo port
Test-Port -port 3544 -optional

Check-ByteRange

Check-CacheFolder

Check-KeyAccess

Check-RAMRequired

Check-DiskRequired

Check-Vpn

Check-PowerBattery

$hostNames = @("dl.delivery.mp.microsoft.com", "emdl.ws.microsoft.com", "download.windowsupdate.com")
foreach($hostName in $hostNames)
{
    Test-Hostname -urlHostName $hostName
}

Write-Host ""