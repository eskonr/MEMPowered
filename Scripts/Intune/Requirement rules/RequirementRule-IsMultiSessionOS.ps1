<#
.SYNOPSIS
This script checks if the operating system is a multi-session OS before proceeding with application installation using Intune.
.DESCRIPTION
The script queries the Win32_OperatingSystem class to determine if the OS is a multi-session version. If the OS caption includes the term "Multi-Session",
 it indicates that the OS supports multiple user sessions, and the script exits with code 1. If the OS is not a multi-session version, the script exits with code 0.
File Name: RequirementRule-IsMultiSessionOS.ps1
Author:Eswar Koneti
#>

# Query the Win32_OperatingSystem class
$os = Get-WmiObject -Class Win32_OperatingSystem

# Check for multi-session OS
if ($os.Caption -match "Multi-Session") {
    Write-Host "Multi-session OS"
    exit 1
} else {
    Write-Host "Not a multi-session OS"
    exit 0
}
