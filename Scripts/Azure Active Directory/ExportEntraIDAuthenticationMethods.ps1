<#
Script to export the user authentication methods using ClientID and Secret Key.
This scripts requries the ClientID to have audit log read permissions as per https://learn.microsoft.com/en-us/graph/api/authenticationmethodsroot-list-userregistrationdetails?view=graph-rest-1.0&tabs=http
I use beta graph in this because 'defaultMfaMethod' exist only in Beta at the time of script creation
Date:5-Aug-2025
Author:Eswar (@eskonr)
#>
# Variables
$tenantId = "3992590e-6f9b-4aa1-aa9f-d7717c111b07"
$clientId = "YourClientID"
$clientSecret = "SecretKEY"
$scope = "https://graph.microsoft.com/.default"
$tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
$csvPath = "C:\EntraID_UserAuthMethods.csv"

# Remove old CSV if it exists
if (Test-Path $csvPath) {
    Remove-Item $csvPath
}

# Get token
$body = @{
    client_id     = $clientId
    scope         = $scope
    client_secret = $clientSecret
    grant_type    = "client_credentials"
}
$response = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $body -ContentType "application/x-www-form-urlencoded"
$accessToken = $response.access_token

# Call Graph API
$graphUrl = "https://graph.microsoft.com/beta/reports/authenticationMethods/userRegistrationDetails"
$headers = @{ Authorization = "Bearer $accessToken" }
$data = Invoke-RestMethod -Uri $graphUrl -Headers $headers -Method Get

# Extract and format
$users = $data.value | Select-Object `
    id, userPrincipalName, userDisplayName, userType, isAdmin,
    isSsprRegistered, isSsprEnabled, isSsprCapable, isMfaRegistered,
    isMfaCapable, isPasswordlessCapable, methodsRegistered,
    isSystemPreferredAuthenticationMethodEnabled, systemPreferredAuthenticationMethods,
    userPreferredMethodForSecondaryAuthentication, lastUpdatedDateTime, defaultMfaMethod

# Convert array fields to strings
$users | ForEach-Object {
    $_.methodsRegistered = ($_.methodsRegistered -join ",")
}

# Export
$users | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Export completed: $csvPath"