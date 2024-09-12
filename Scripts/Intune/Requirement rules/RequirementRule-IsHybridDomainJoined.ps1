<#
.SYNOPSIS
This script checks if the computer is hybrid Azure AD joined before proceeding with application installation in Intune.

.DESCRIPTION
The script uses `dsregcmd /status` to determine if the device is both Azure AD joined and Domain joined. If both conditions are met, the script outputs `1` to indicate that the requirement is satisfied.

#>

# Ensure no PowerShell errors are captured in the error stream
$ErrorActionPreference = "SilentlyContinue"

# Initialize requirement flag
$b_Required = $False

function Get-DsRegStatus {
    $dsregcmd = dsregcmd /status
    $status = $dsregcmd | Select-String -Pattern " *[A-z]+ : .+ *"
    $result = @{}
    foreach ($line in $status) {
        $parts = ($line.ToString().Trim() -split " : ")
        $result[$parts[0]] = $parts[1]
    }
    return $result
}

# Check if device is Azure AD joined and Domain joined
$status = Get-DsRegStatus
if ($status["AzureADJoined"] -eq "YES" -and $status["DomainJoined"] -eq "YES") {
    $b_Required = $True
}

# Output the result
if ($b_Required) { Write-Output 1 }

# Clear errors and exit
$Error.Clear()
exit 0
