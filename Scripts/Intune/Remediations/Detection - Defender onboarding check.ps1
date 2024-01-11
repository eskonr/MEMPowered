<#
Name: Check windows defender onboarding baseline
Dated:28-Sep-2023
Description: As part of Microsoft defender onboarding, it is required to check if the device is successfully migrated from the current security stack such as 3rd party AV to microsoft defender AV.
This script check for cylance and carbon service, if they exist, report as non-compliant else check defender service and report status if all good or not.
#>

# Define the log file path
$logFilePath = "C:\ProgramData\Corp\Logs\ComplianceCheckforDefender.log"

# Create the log folder if it doesn't exist
$logFolder = [System.IO.Path]::GetDirectoryName($logFilePath)
if (-not (Test-Path -Path $logFolder)) {
    New-Item -Path $logFolder -ItemType Directory -Force
}

# Function to log activity
function Log-Activity {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $message"
    $logMessage | Out-File -FilePath $logFilePath -Append
}

# Check for "Cylance" or "Carbon Black" service
if ((Get-Service -Name "CylanceSvc" -ErrorAction SilentlyContinue) -or (Get-Service -Name "CBDefense" -ErrorAction SilentlyContinue)) {
    Log-Activity "Non-compliant,Cylance or Carbon Black service found"
    Write-host "Non-compliant,Cylance or Carbon Black service found"
} else {
    # Check for "Sense" service
    $senseService = Get-Service -Name "Sense" -ErrorAction SilentlyContinue
    if ($senseService -and $senseService.Status -eq "Running") {
            Log-Activity "Compliant,Sense service found and running"
            write-host "Compliant,Sense service found and running"
        
        }
     else {
        Log-Activity "Non-compliant,Cylance and Carbon Black dont exist but Sense service not running"
        write-host "Non-compliant,Cylance and Carbon Black dont exist but Sense service not running"
        
            }
            }

