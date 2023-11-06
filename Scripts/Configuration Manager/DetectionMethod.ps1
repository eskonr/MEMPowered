<#
Name: DetectionLogic.ps1
Description: Detection logic for ODBC Driver 17 for SQL Server
Author: Eswar Koneti @eskonr
#>

# Define Application Name to check
$AppName = "Microsoft ODBC Driver 17 for SQL Server"
# Define the minimum required version
$MinimumVersion = [System.Version]::new("17.10.5.1")

# Assume app is not installed
$AppDetection = $false

# Search for the application in HKLM (64-bit registry)
$installedProducts64 = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Select-Object DisplayName, DisplayVersion
foreach ($product in $installedProducts64) {
    if ($product.DisplayName -like $AppName -and [System.Version]::new($product.DisplayVersion) -ge $MinimumVersion) {
        $AppDetection = $true
        break
    }
}

# If the app is not detected in the 64-bit registry, search in the 32-bit registry
if (-not $AppDetection) {
    $installedProducts32 = Get-ItemProperty -Path "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Select-Object DisplayName, DisplayVersion
    foreach ($product in $installedProducts32) {
        if ($product.DisplayName -like $AppName -and [System.Version]::new($product.DisplayVersion) -ge $MinimumVersion) {
            $AppDetection = $true
            break
        }
    }
}

# Return the detection status
if ($AppDetection)
{
Return $true
}
