<#
.SYNOPSIS
        Automates the monitoring and optimization of system memory to prevent low memory errors and ensure optimal performance. Continuously tracks physical memory usage and triggers the Memory Optimizer script when usage exceeds 90%.

.DESCRIPTION
        This script sets up a Task Scheduler task that continuously monitors the physical memory usage of the system. If memory usage exceeds 90%, it triggers an optimizer script to free up RAM, ensuring the system remains responsive   and efficient.

This script performs the following tasks:
    1. **Folder Creation**: Creates the following folders if they do not already exist:
        - Logs folder: `C:\logs`
        - Scripts folder: `C:\scripts`
    2. **Log File Setup**: Defines the path for log files, including a timestamp in the filename:
        - Log file path: `C:\logs\MemoryOptlogs_<timestamp>.txt`
    3. **Monitor Script Creation**: Generates a PowerShell script (`monitor_memory.ps1`) that:
        - Logs the start of the script.
        - Continuously monitors memory usage.
        - Logs memory usage at regular intervals.
        - Runs an optimizer script if memory usage exceeds 90%.
        - Sleeps for 60 seconds between checks.
        - Script location: `C:\scripts\monitor_memory.ps1`
    4. **Optimizer Script Creation**: Generates a PowerShell script (`optimizer.ps1`) that:
        - Trims the working set of all processes to free up RAM.
        - Empties the modified page list to free up additional memory.
        - Logs a message indicating successful RAM optimization.
        - Script location: `C:\scripts\optimizer.ps1`
    5. **Task Scheduler Setup**: Configures a Task Scheduler task (`MemoryMonitorTask`) that:
        - Runs the monitor script with elevated privileges.
        - Triggers at system startup.
        - Triggers daily at 11:00 AM.
        - Repeats every 15 minutes for almost 24 hours.
        - Starts immediately upon script registration.
    6. **Task Removal**: Removes any existing Task Scheduler task with the same name before creating a new one.

.VERSION
    1.0

.DATE
    2025-03-03

.USAGE
    Run this script to set up the Task Scheduler task for monitoring memory usage.

.PARAMETER logFolderPath
    The path to the folder where log files will be stored.

.PARAMETER scriptsFolderPath
    The path to the folder where the scripts will be stored.

.EXAMPLE
    .\Setup-MemoryMonitorTask.ps1

.NOTES
    Ensure you have the necessary permissions to create Task Scheduler tasks and write to the specified folders. Run this script as an Administrator.
#>

# Define paths
$logFolderPath = "C:\logs"
$scriptsFolderPath = "C:\scripts"

# Create folders if they don't exist
if (-Not (Test-Path -Path $logFolderPath)) {
    New-Item -Path $logFolderPath -ItemType Directory
}
if (-Not (Test-Path -Path $scriptsFolderPath)) {
    New-Item -Path $scriptsFolderPath -ItemType Directory
}

# Define log file path
$logFilePath = "$logFolderPath\MemoryOptlogs_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

# Create the monitor memory script content
$monitorScriptContent = @'
# Define log file path
$logFilePath = "C:\logs\MemoryOptlogs_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

# Write a simple message to the log file
Add-Content -Path $logFilePath -Value "$(Get-Date): Script started."

while ($true) {
    Add-Content -Path $logFilePath -Value "$(Get-Date): Checking memory usage."

    $totalMemory = (Get-WmiObject -Class Win32_OperatingSystem).TotalVisibleMemorySize
    $freeMemory = (Get-WmiObject -Class Win32_OperatingSystem).FreePhysicalMemory
    $usedMemory = $totalMemory - $freeMemory
    $memoryUsagePercent = ($usedMemory / $totalMemory) * 100

    Add-Content -Path $logFilePath -Value "$(Get-Date): Memory usage is $([math]::Round($memoryUsagePercent, 2))%."
    if ($memoryUsagePercent -gt 90) {
        Add-Content -Path $logFilePath -Value "$(Get-Date): Memory usage exceeded 90%. Running optimizer script."
        Start-Process -FilePath "powershell.exe" -ArgumentList "-File C:\scripts\optimizer.ps1" -WindowStyle Hidden
    }

    Add-Content -Path $logFilePath -Value "$(Get-Date): Sleeping for 60 seconds."
    Start-Sleep -Seconds 60
}
'@

# Write the monitor memory script to file
$monitorScriptPath = "$scriptsFolderPath\monitor_memory.ps1"
Set-Content -Path $monitorScriptPath -Value $monitorScriptContent

# Create the optimizer script content
$optimizerScriptContent = @'
# Trim the working set of all processes to free up RAM
Get-Process | ForEach-Object {
    Try {
        $null = $_.MinWorkingSet = 1
        $null = $_.MaxWorkingSet = 1
    } Catch {}
}

# Empty modified page list (similar to what Wise does)
$standbyList = "EmptyStandbyList.exe workingsets"
Start-Process -FilePath "cmd.exe" -ArgumentList "/c $standbyList" -WindowStyle Hidden

Write-Output "RAM Freed Successfully"
'@

# Write the optimizer script to file
$optimizerScriptPath = "$scriptsFolderPath\optimizer.ps1"
Set-Content -Path $optimizerScriptPath -Value $optimizerScriptContent

# Remove existing task if it exists
if (Get-ScheduledTask -TaskName "MemoryMonitorTask" -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName "MemoryMonitorTask" -Confirm:$false
}

# Create Task Scheduler task with elevated privileges and multiple triggers
$action = New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "-ExecutionPolicy Bypass -File $monitorScriptPath > C:\logs\task_output.log 2>&1"
$triggerAtStartup = New-ScheduledTaskTrigger -AtStartup
$triggerDaily = New-ScheduledTaskTrigger -Daily -At "11:00AM"
$triggerRepeat = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddHours(11) -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration ([TimeSpan]::FromHours(23.75))
$triggerImmediate = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -Action $action -Trigger $triggerAtStartup, $triggerDaily, $triggerRepeat, $triggerImmediate -Settings $settings -Principal $principal -TaskName "MemoryMonitorTask" -Description "Monitors physical memory and runs optimizer script if memory usage exceeds 90%"

Write-Output "Setup completed successfully. Task Scheduler task created with elevated privileges and multiple triggers, and scripts are in place."

