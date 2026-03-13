<#
.SYNOPSIS
Exports the list of applications available in the Enterprise App Catalog (EAM) from Microsoft Graph.

.DESCRIPTION
This script retrieves all applications available in the Enterprise App Catalog using Microsoft Graph.
The results are exported to a CSV file.

The script checks whether the Microsoft Graph PowerShell module is installed. 
If the module is missing, it attempts to install it for the current user.

IMPORTANT:
The tenant must have the Enterprise App Management capability enabled 
(Intune Suite license or equivalent). Without this license, the Graph API 
endpoint will not return data.

.REQUIREMENTS
- Microsoft Graph PowerShell SDK
- Permission: DeviceManagementApps.Read.All
- Intune tenant with Enterprise App Management (Intune Suite or equivalent)

.OUTPUT
CSV file containing:
- Product ID
- Product Display Name
- Publisher

.NOTES
Author: Example
Graph API: /beta/deviceAppManagement/mobileAppCatalogPackages
#>

#---------------------------------------------------------
# Ensure Microsoft Graph module is installed
#---------------------------------------------------------

$ModuleName = "Microsoft.Graph"

if (-not (Get-Module -ListAvailable -Name $ModuleName)) {

    Write-Host "Microsoft Graph PowerShell module not found. Attempting installation for current user..." -ForegroundColor Yellow

    try {
        Install-Module Microsoft.Graph -Scope CurrentUser -Repository PSGallery -Force -ErrorAction Stop
        Write-Host "Microsoft Graph module installed successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to install Microsoft Graph module. Install manually using: Install-Module Microsoft.Graph"
        return
    }
}

Import-Module Microsoft.Graph

#---------------------------------------------------------
# Connect to Microsoft Graph
#---------------------------------------------------------

try {
    Connect-MgGraph -Scopes "DeviceManagementApps.Read.All" -ErrorAction Stop
}
catch {
    Write-Error "Failed to authenticate to Microsoft Graph."
    return
}


$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$date=Get-date -Format ddMMyyyy
$output ="$dir\ListofEnterpriseAppManagenentApps_$date.csv"

#---------------------------------------------------------
# Graph API Query
#---------------------------------------------------------

$uri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileAppCatalogPackages?`$apply=groupby((productId,productDisplayName,publisherDisplayName))&`$top=999&`$orderBy=productDisplayName asc"

$all = @()

Write-Host "Retrieving Enterprise App Catalog applications..." -ForegroundColor Cyan

while ($uri) {
    try {
        $resp = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
        $all += $resp.value
        $uri = $resp.'@odata.nextLink'
    }
    catch {
        Write-Error "Failed to retrieve data from Microsoft Graph. Ensure the tenant has Enterprise App Management enabled."
        return
    }
}

#---------------------------------------------------------
# Export results
#---------------------------------------------------------

$all |
Select-Object productId, productDisplayName, publisherDisplayName |
Export-Csv $output -NoTypeInformation -Encoding UTF8

Write-Host "Export completed successfully with count of apps:$($All.count)." -ForegroundColor Green
Write-Host "File saved to: $output"