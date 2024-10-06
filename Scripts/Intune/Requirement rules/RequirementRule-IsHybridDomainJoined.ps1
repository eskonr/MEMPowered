<#
.SYNOPSIS
This script checks if the computer is hybrid Azure AD joined before proceeding with application installation in Intune.

.DESCRIPTION
The script uses `dsregcmd /status` to determine if the device is both Azure AD joined and Domain joined. If both conditions are met, the script outputs `Yes` to indicate that the requirement is satisfied.
Author: Eswar Koneti (@eskonr)

#>

# Ensure no PowerShell errors are captured in the error stream
$ErrorActionPreference = "SilentlyContinue"

# Initialize requirement flag
$isHybrid= $False

# Execute dsregcmd and capture output
$dsregcmd = dsregcmd /status
$status = $dsregcmd | Select-String -Pattern " *[A-z]+ : .+ *"

# Parse the output into a hashtable
$result = @{}
foreach ($line in $status) {
    $parts = ($line.ToString().Trim() -split " : ")
    $result[$parts[0]] = $parts[1]
}

# Check if device is Azure AD joined and Domain joined
if ($result["AzureADJoined"] -eq "YES" -and $result["DomainJoined"] -eq "YES") {
    $isHybrid = $True
}

# Output the result
if ($isHybrid) { Write-Output "Yes" }

# Clear errors and exit
$Error.Clear()
exit 0
