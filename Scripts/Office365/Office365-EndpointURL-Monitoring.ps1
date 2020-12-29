<# 
DESCRIPTION
This script calls the REST API of the Office 365 IP and URL Web Service (Worldwide instance)
and checks to see if there has been a new update since the version stored in an existing
$Env:TEMP\O365_endpoints_latestversion.txt file in your user directory's temp folder
(usually C:\Users\<username>\AppData\Local\Temp).
If the file doesn't exist, or the latest version is newer than the current version in the
file, the script returns IPs and/or URLs that have been changed, added or removed in the latest
update and writes the new version and data to the output file $Env:TEMP\O365_endpoints_data.txt.

Office 365 IP address and URL web service from https://aka.ms/ipurlws

USAGE
Run as a scheduled task once in month or once in 2 weeks.

PARAMETERS
n/a

PREREQUISITES
PS script execution policy: Bypass
PowerShell 3.0 or later
Does not require elevation
#>

#Requires -Version 3.0

$dir = Split-Path $script:MyInvocation.MyCommand.Path
#Get the current date
$date = (Get-Date -f dd-MM-yyyy-hhmmss)

#Email to be sent from
$From = "o365automation@eskonr.com"
#notify people in your org about the endpoint URL changes.
$To ="user1@eskonr.com","user2@eskonr.com"
$cc="user3@eskonr.com","user4@eskonr.com"
$smtp="smtp.intranet.asia"
$Subject = "O365 new endpoint URLs added"
$Body = "Hi Team,
Please find the list of newly added endpoints by Microsoft.Please review and work with Network team for better end-user Experience.

Thanks,
O365 Team
"

$destination = "$dir\Endpoint URL"
$Move = Get-ChildItem -path "$dir\EndpointURLs-*.csv" #| Sort-Object LastWriteTime -Descending | Select-Object -Skip 1
foreach ($file in $Move) {
  $parent = Split-Path $file.FullName -Parent
  Move-Item $file.FullName -Destination $destination -Force
}

# web service root URL
$ws = "https://endpoints.office.com"
# path where output files will be stored
$versionpath = "$dir\O365_endpoints_latestversion.txt"
$datapath ="$dir\O365_endpoints_data.txt"

# fetch client ID and version if version file exists; otherwise create new file and client ID
if (Test-Path $versionpath) {
    $content = Get-Content $versionpath
    $clientRequestId = $content[0]
    $lastVersion = $content[1]
    Write-Output ("Version file exists! Current version: " + $lastVersion)
}
else {
    Write-Output ("First run! Creating version file at " + $versionpath + ".")
    $clientRequestId = [GUID]::NewGuid().Guid
    $lastVersion = "0000000000"
    @($clientRequestId, $lastVersion) | Out-File $versionpath
    }
# call version method to check the latest version, and pull new data if version number is different
try 
{
$version = Invoke-RestMethod -Uri ($ws + "/version/Worldwide?clientRequestId=" + $clientRequestId)
}
Catch [System.Exception]
{
$WebReqErr = $error[0] | Select-Object * | Format-List -Force
Write-Error "An error occurred while attempting to connect to the requested site.  The error was $WebReqErr.Exception"
Send-MailMessage -From $From -To $To -SmtpServer $smtp -Subject "Failed to connect to IP URL endpoint URL" -Body "Please check the script"
}
#EndCatch
if ($version.latest -gt $lastVersion)
{
    Write-Host "New version of Office 365 worldwide commercial service instance endpoints detected"
    # write the new version number to the version file
    @($clientRequestId, $version.latest) | Out-File $versionpath
    # invoke endpoints method to get the new data
    $endpointSets = Invoke-RestMethod -Uri ($ws + "/endpoints/Worldwide?clientRequestId=" + $clientRequestId)
    # filter results for Allow and Optimize endpoints, and transform these into custom objects with port and category
    # URL results
    $flatUrls = $endpointSets | ForEach-Object {
        $endpointSet = $_
        $urls = $(if ($endpointSet.urls.Count -gt 0) { $endpointSet.urls } else { @() })
        $urlCustomObjects = @()
        if ($endpointSet.category -in ("Allow", "Optimize")) {
            $urlCustomObjects = $urls | ForEach-Object {
                [PSCustomObject]@{
                    category = $endpointSet.category;
                    url      = $_;
                    tcpPorts = $endpointSet.tcpPorts;
                    udpPorts = $endpointSet.udpPorts;
                }
            }
        }
        $urlCustomObjects
    }
    # IPv4 results
    $flatIp4s = $endpointSets | ForEach-Object {
        $endpointSet = $_
        $ips = $(if ($endpointSet.ips.Count -gt 0) { $endpointSet.ips } else { @() })
        # IPv4 strings contain dots
        $ip4s = $ips | Where-Object { $_ -like '*.*' }
        $ip4CustomObjects = @()
        if ($endpointSet.category -in ("Allow", "Optimize")) {
            $ip4CustomObjects = $ip4s | ForEach-Object {
                [PSCustomObject]@{
                    category = $endpointSet.category;
                    ip = $_;
                    tcpPorts = $endpointSet.tcpPorts;
                    udpPorts = $endpointSet.udpPorts;
                }
            }
        }
        $ip4CustomObjects
    }
    # IPv6 results
    $flatIp6s = $endpointSets | ForEach-Object {
        $endpointSet = $_
        $ips = $(if ($endpointSet.ips.Count -gt 0) { $endpointSet.ips } else { @() })
        # IPv6 strings contain colons
        $ip6s = $ips | Where-Object { $_ -like '*:*' }
        $ip6CustomObjects = @()
        if ($endpointSet.category -in ("Optimize")) {
            $ip6CustomObjects = $ip6s | ForEach-Object {
                [PSCustomObject]@{
                    category = $endpointSet.category;
                    ip = $_;
                    tcpPorts = $endpointSet.tcpPorts;
                    udpPorts = $endpointSet.udpPorts;
                }
            }
        }
        $ip6CustomObjects
    }

    # write output to screen
    Write-Output ("Client Request ID: " + $clientRequestId)
    Write-Output ("Last Version: " + $lastVersion)
    Write-Output ("New Version: " + $version.latest)
    Write-Output ""
    Write-Output "IPv4 Firewall IP Address Ranges"
    ($flatIp4s.ip | Sort-Object -Unique) -join "," | Out-String
    Write-Output "IPv6 Firewall IP Address Ranges"
    ($flatIp6s.ip | Sort-Object -Unique) -join "," | Out-String
    Write-Output "URLs for Proxy Server"
    ($flatUrls.url | Sort-Object -Unique) -join "," | Out-String
    Write-Output ("IP and URL data written to " + $datapath)

    # write output to data file
    Write-Output "Office 365 IP and UL Web Service data" | Out-File $datapath
    Write-Output "Worldwide instance" | Out-File $datapath -Append
    Write-Output "" | Out-File $datapath -Append
    Write-Output ("Version: " + $version.latest) | Out-File $datapath -Append
    Write-Output "" | Out-File $datapath -Append
    Write-Output "IPv4 Firewall IP Address Ranges" | Out-File $datapath -Append
    ($flatIp4s.ip | Sort-Object -Unique) -join "," | Out-File $datapath -Append
    Write-Output "" | Out-File $datapath -Append
    Write-Output "IPv6 Firewall IP Address Ranges" | Out-File $datapath -Append
    ($flatIp6s.ip | Sort-Object -Unique) -join "," | Out-File $datapath -Append
    Write-Output "" | Out-File $datapath -Append
    Write-Output "URLs for Proxy Server" | Out-File $datapath -Append
    ($flatUrls.url | Sort-Object -Unique) -join "," | Out-File $datapath -Append

#Get the URLs changed in the lastest version

 Try{
  Invoke-RestMethod -Uri 'https://endpoints.office.com/version/worldwide?allversions=true&format=rss&clientrequestid=b10c5ed1-bad1-445f-b386-b919946339a7' | Export-Csv "$dir\o365rss.csv" -NoTypeInformation -ErrorAction SilentlyContinue
  }
#EndTry
Catch [System.Exception]
{
$WebReqErr = $error[0] | Select-Object * | Format-List -Force
Write-Error "An error occurred while attempting to connect to the requested site.  The error was $WebReqErr.Exception"
Send-MailMessage -From $From -To $To -SmtpServer $smtp -Subject "Failed to connect to IP URL endpoint URL" -Body "Please check the script"
}
#EndCatch
$New = Import-Csv (Get-Item "$dir\o365rss.csv") | Sort-Object {[DateTime]$_.pubDate} | Select -Last 1
$lastdate=$new.pubdate
$LastURL=$new.link
$lastDescription=$new.description
#Write-host $LastURL

Try{
  Invoke-RestMethod -Uri $LastURL | Export-Csv "$dir\o365rss.csv" -NoTypeInformation -ErrorAction SilentlyContinue
  }
#EndTry
Catch [System.Exception]
{
$WebReqErr = $error[0] | Select-Object * | Format-List -Force
Write-Error "An error occurred while attempting to connect to the requested site.  The error was $WebReqErr.Exception"
Send-MailMessage -From $From -To $To -SmtpServer $smtp -Subject "Failed to connect to IP URL endpoints" -Body "Please check the script"
}

$endpointSets=Invoke-RestMethod -uri $LastURL
 $endpointSets | ForEach-Object {
$endpointSet = $_ | Select-Object * -ExpandProperty add -ErrorAction SilentlyContinue
$endpointSet | select id,endpointSetId,disposition,impact,version,@{ n = 'URL'; e = { ($endpointSet).URLs -join ','}} -Unique | Export-Csv "$dir\EndpointURLs-$($version.latest).csv" -NoTypeInformation  -append -Force -ErrorAction SilentlyContinue
$endpointSet1 = $_ | Select-Object * -ExpandProperty remove -ErrorAction SilentlyContinue
$endpointSet1 | select id,endpointSetId,disposition,impact,version,@{ n = 'URL'; e = { ($endpointSet1).URLs -join ','}} -Unique | Export-Csv "$dir\EndpointURLs-$($version.latest).csv" -NoTypeInformation  -append -Force -ErrorAction SilentlyContinue

}

Write-Host "Changes are found in the Microsoft Endpoint URL, sending email"
#if you dont want to send email with the URL changes, you can simply comment the below line.
Send-MailMessage -From $From -To $To -Cc $CC -SmtpServer $smtp -Subject $Subject -Body $Body -Attachments "$dir\O365_endpoints_data.txt","$dir\EndpointURLs-$($version.latest).csv"
}
else {
    Write-Host "Office 365 worldwide commercial service instance endpoints are up-to-date."
}

#script ends here
