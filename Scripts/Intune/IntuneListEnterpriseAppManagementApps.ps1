
Connect-MgGraph -Scopes "DeviceManagementApps.Read.All"

# Start with a grouped view (unique apps). Adjust $top if you want, but paging still required.
$uri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileAppCatalogPackages?`$apply=groupby((productId,productDisplayName,publisherDisplayName))&`$top=999&`$orderBy=productDisplayName asc"

$all = @()

while ($uri) {
    $resp = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
    $all += $resp.value
    $uri = $resp.'@odata.nextLink'
}

$all | Select-Object productId, productDisplayName, publisherDisplayName |
    Export-Csv ".\EAM_EnterpriseAppCatalog_AllApps.csv" -NoTypeInformation -Encoding UTF8
``
