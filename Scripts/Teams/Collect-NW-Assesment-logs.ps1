<#
Title:This script help to collect the network assesment logs
Description:The Skype for Business Network Assessment Tool provides the ability to perform a simple test of network performance
and network connectivity to determine how well the network would perform for a Microsoft Teams and Skype for Business Online calls.
Author:Eswar Koneti
Twitter:@eskonr
Date:18-Nov-2020
#>

$dir = Split-Path $script:MyInvocation.MyCommand.Path
$computer = $env:COMPUTERNAME #Get Computer Name
$timestamp = $(Get-Date -f dd-MM-yyyy-HHmmss)
$logshare = "\\servername\sharefoldername"
$TempPath="C:\Temp\TeamsLog"
$systeminfo="$TempPath\systeminfo.txt"
$From = "o365automation@eskonr.com"
$To = "xxxxxx@eskonr.com","yyyyyyy@eskonr.com"
$Body = "Hi,
Please find the network assesment logs for the user as attached.

Thanks,
xxxxxx Team
"
#Collect system information
$computerSystem = Get-CimInstance CIM_ComputerSystem
$computerBIOS = Get-CimInstance CIM_BIOSElement
$computerOS = Get-CimInstance CIM_OperatingSystem
$computerCPU = Get-CimInstance CIM_Processor
$computerHDD = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID = 'C:'"
Clear-Host
Write-Host "System Information for: " $computerSystem.Name -BackgroundColor DarkCyan 
"System Information for: "+ $computerSystem.Name | Out-File $systeminfo -Append
"Manufacturer: " + $computerSystem.Manufacturer | Out-File $systeminfo -Append
"Model: " + $computerSystem.Model | Out-File $systeminfo -Append
"Serial Number: " + $computerBIOS.SerialNumber | Out-File $systeminfo -Append
"CPU: " + $computerCPU.Name | Out-File $systeminfo -Append
"HDD Capacity: "  + "{0:N2}" -f ($computerHDD.Size/1GB) + "GB" | Out-File $systeminfo -Append
"HDD Space: " + "{0:P2}" -f ($computerHDD.FreeSpace/$computerHDD.Size) + " Free (" + "{0:N2}" -f ($computerHDD.FreeSpace/1GB) + "GB)" | Out-File $systeminfo -Append
"RAM: " + "{0:N2}" -f ($computerSystem.TotalPhysicalMemory/1GB) + "GB" | Out-File $systeminfo -Append
"Operating System: " + $computerOS.caption + ", Service Pack: " + $computerOS.ServicePackMajorVersion | Out-File $systeminfo -Append
"User logged In: " + $computerSystem.UserName | Out-File $systeminfo -Append
"Last Reboot: " + $computerOS.LastBootUpTime | Out-File $systeminfo -Append

#start network assesment tool
#network assesment tool Installation location. Change it if needed.
$skypelocation= "C:\Program Files (x86)\Microsoft Skype for Business Network Assessment Tool"
#Get user login information. User must logged in to get the assesment results.
$username = Get-WmiObject -Class win32_process -Filter "name = 'Explorer.exe'" -ComputerName $computer -EA "Stop" | ForEach-Object { $_.GetOwner().User }
if ($username)
{
if (Test-Path $skypelocation)
{
$command="$skypelocation\NetworkAssessmentTool.exe"
push-location "C:\Program Files (x86)\Microsoft Skype for Business Network Assessment Tool";
$exe = "NetworkAssessmentTool" 
$proc = (Start-Process $exe -PassThru -WindowStyle Hidden)
$proc | Wait-Process
$proc1= (Start-Process $exe -ArgumentList "/connectivitycheck /verbose" -PassThru -WindowStyle Hidden)
$proc1 | Wait-Process
Copy-Item -Path "C:\Users\$username\AppData\Local\Microsoft Skype for Business Network Assessment Tool\connectivity_results.txt" -Destination $TempPath -Force -ErrorAction SilentlyContinue
Copy-Item -Path "C:\Users\$username\AppData\Local\Microsoft Skype for Business Network Assessment Tool\\performance_results.tsv" -Destination $TempPath -Force -ErrorAction SilentlyContinue
#compress the files and copy to share drive
Compress-Archive -Path $TempPath\* -CompressionLevel Optimal -DestinationPath "$TempPath\$username-$timestamp.zip"
#Copy the network assesement logs to network share
Copy-Item "$TempPath\$username-$timestamp.zip" -Destination $logshare -Force
$Subject = "Network assesment results for $username"
send-MailMessage -From $From -To $To -SmtpServer "yoursmtpserverName" -Subject $Subject -Body $Body -Attachments "$TempPath\$username-$timestamp.zip"
#Cleanup temporary files/folders
Remove-Item -Path "C:\Users\$username\AppData\Local\Microsoft Skype for Business Network Assessment Tool\connectivity_results.txt" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Users\$username\AppData\Local\Microsoft Skype for Business Network Assessment Tool\\performance_results.tsv" -Force -ErrorAction SilentlyContinue
Remove-Item $TempPath\* -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$TempPath\$username-$timestamp.zip" -Force -ErrorAction SilentlyContinue
}
}
#script ends
