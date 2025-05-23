<#
Name:GetKMSServer_Information.ps1
Description: Check if the Windows OS license is activated through KMS server or not.
Author: Eswar Koneti
Date:05-Sep-2024
#>

# Run the slmgr.vbs /dlv command using cscript and capture the output
$output = cscript //Nologo "$env:SystemRoot\System32\slmgr.vbs" /dlv

# Convert the output to an array of strings, each representing a line of the output
$outputLines = $output -split "`n"

# Initialize a variable to hold the KMS machine name
$kmsMachineName = $null

# Iterate through each line to find the "KMS machine name from DNS"
foreach ($line in $outputLines) {
    if ($line -match "KMS machine name from DNS") {
        # Extract the value after the colon
        $kmsMachineName = $line -replace ".*KMS machine name from DNS\s*:\s*", ""
        break
    }
}

# Output the KMS machine name
if ($kmsMachineName) {
    Write-Output "KMS machine name from DNS: $kmsMachineName"
} else {
    Write-Output "KMS machine name from DNS not found."
}