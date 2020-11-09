<#
.SYNOPSIS
	This script perform the collection of Teams client logs from remote device.
.DESCRIPTION
	This script perform the collection of Teams client logs from remote device.
you can use this script to run it from Configuration Manager scripts feature to collect the teams client logs and store in shared drive.
Author: Eswar Koneti
Date:05-Oct-2020
#>
$computer = $env:COMPUTERNAME #Get Computer Name
$timestamp = $(Get-Date -f dd-MM-yyyy-HHmmss)
$logshare = "\\SG-CM01\TeamsLog"
Set-Variable -Name EventAgeDays -Value 7 #we will take events for the latest 7 days that should cover the teams crash issues.
Set-Variable -Name LogNames -Value @("Application") # Checking app and system logs
Set-Variable -Name EventTypes -Value @("Error","Warning") # Loading only Errors and Warnings
$TempPath = "C:\temp\TeamsLog" #Temp location to store the logs

if (-not (Test-Path $TempPath))
{
New-Item -ItemType directory -Path $TempPath -ErrorAction Stop | Out-Null
}
Set-Variable -Name ExportFolder -Value "C:\temp\TeamsLog"

$el_c = @() #consolidated error log
$now = Get-Date
$timestamp = $(Get-Date -f dd-MM-yyyy-HHmmss)
$startdate = $now.AddDays(- $EventAgeDays)
$ExportFile = "eventvwr" + "-" + $timestamp + ".csv"
foreach ($log in $LogNames)
{
Write-Host Processing $log
$el = Get-EventLog -ComputerName $env:Computername -log $log -After $startdate -EntryType $EventTypes
$el_c += $el #consolidating
}
$el_sorted = $el_c | Sort-Object TimeGenerated #sort by time
Write-Host Exporting to $ExportFile
$el_sorted | Select-Object EntryType,TimeGenerated,Source,EventID,MachineName,Message,description | Export-Csv $TempPath\$ExportFile -NoTypeInfo

#collect desktop, media logs

$username = Get-WmiObject -Class win32_process -Filter "name = 'Explorer.exe'" -ComputerName $computer -EA "Stop" | ForEach-Object { $_.GetOwner().User }
if ($username)
{
Copy-Item -Path "C:\Users\$username\AppData\Roaming\Microsoft\Teams\logs.txt" -Destination $TempPath -Force -ErrorAction SilentlyContinue #copy desktop logs
Copy-Item -Path "C:\Users\$username\AppData\Roaming\Microsoft\Teams\media-stack\*.blog" -Destination $TempPath -Force -ErrorAction SilentlyContinue #copy Media logs
Copy-Item -Path "C:\Users\$username\AppData\Roaming\Microsoft\Teams\skylib\*.blog" -Destination $TempPath -Force -ErrorAction SilentlyContinue #copy Media logs
Copy-Item -Path "C:\Users\$username\AppData\Roaming\Microsoft\Teams\media-stack\*.etl" -Destination $TempPath -Force -ErrorAction SilentlyContinue #copy Media logs
}

#collect debug logs:

if (Test-Path "C:\Users\$username\downloads\MSTeams Diagnostics Log*") 
{
Copy-Item -Path "C:\Users\$username\downloads\MSTeams Diagnostics Log*" -Destination $TempPath -Force -ErrorAction SilentlyContinue #copy debug logs
Remove-Item "C:\Users\$username\downloads\MSTeams Diagnostics Log*" -Recurse -Force -ErrorAction SilentlyContinue #remove the debug logs
}

#Collect crash dump logs , incase you have enabled the crashdump logs in the registry.

$folder = "C:\Users\$username\AppData\Local\CrashDumps"
if (!(Test-Path "$folder\teams.exe")) 
{# Write-Host "No crash dump exists"
}
 else { $file = (Get-Item "$folder\teams.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty name)
if ((Test-Path "$folder\$file" -OlderThan (Get-Date).AddDays(-0).AddHours(6).AddMinutes(-0)) -and (Get-Item "$folder\$file").Length -lt 200mb)
{
Copy-Item -Path "$folder\$file" -Destination $TempPath -Force -ErrorAction SilentlyContinue #copy desktop logs
}
else
{
#Write-Host "File size is more than 200mb hence exit copying"
}
}

#Compress the files and copy to share drive
$DestinationPath="$TempPath"+"\"+$username+"-"+$timestamp

Compress-Archive -Path $TempPath -CompressionLevel Optimal -DestinationPath "$TempPath\$username-$timestamp.zip"
#"$TempPath\$username-$timestamp"
Copy-Item "$DestinationPath.zip" -Destination $logshare -Force
write-host "Logs are copied to the share"

#Cleanup temporary files/folders

Remove-Item $TempPath -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$TempPath\$username-$timestamp.zip" -Force -ErrorAction SilentlyContinue
