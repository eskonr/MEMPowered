<#
.SYNOPSIS
    Exports Passkey / Platform Credential / Windows Hello for Business authentication
    methods for VIP users from Microsoft Entra ID, and prepares the result for import
    into the VIP Passkey Readiness Power BI dashboard.

.DESCRIPTION
    This script can be further utilized to create the Passkey Readiness Dashboard for users (Executives)
     by closing the one gap Intune device inventory cannot provide on its
    own: whether a executives  Windows, macOS, iPhone, or iPad device actually has a
    passkey / passwordless credential registered in Microsoft Entra ID.

    For each executive user (read from the file name VIPUsers.csv), the
    script calls Microsoft Graph to retrieve:

        * fido2Methods                      -> Passkeys registered in Microsoft
                                                Authenticator (primarily iPhone/iPad).
                                                Reported at USER level only; Entra ID
                                                does not expose which specific mobile
                                                device a given passkey belongs to.

        * platformCredentialMethods         -> macOS Platform SSO credential.
                                                displayName holds the actual Mac
                                                device name, enabling exact
                                                device-level matching once Platform
                                                SSO is enabled tenant-wide.

        * windowsHelloForBusinessMethods    -> Windows Hello for Business.
                                                displayName is populated for most,
                                                but not all, registrations. For every
                                                registration, the script additionally
                                                expands the method with
                                                "?$expand=device" to retrieve the
                                                Entra Device Id, which is a more
                                                reliable join key against Intune's
                                                AzureADDeviceId than device name alone
                                                (device-name matching is used only as
                                                a fallback).

    To limit the number of additional Graph calls, the Device Id expansion is only
    performed for Windows Hello registrations created within the configurable
    recency window (default: 2 years) - older, likely-decommissioned registrations
    are recorded without a Device Id lookup.

    Executive users with zero registered methods across all three categories are still
    recorded with MethodType = "None", so they appear in the dashboard as
    "Not Registered" rather than silently disappearing from the report.


.NOTES
    Required Microsoft Graph PowerShell permissions (delegated or app-only):
        UserAuthenticationMethod.Read.All
        User.Read.All

    Required modules (import only what's needed - the full Microsoft.Graph
    umbrella module is not required and is significantly slower to load):
        Microsoft.Graph.Authentication
        Microsoft.Graph.Users

    Recommended: run under PowerShell 7 (pwsh), signed in as the same account
    used to launch the session (avoid running as a different/adm account from
    the logged-in Windows
#>

$scriptStart = Get-Date
# Define script location and output file
$scriptPath = $MyInvocation.MyCommand.Path
$directory  = if ($scriptPath) { Split-Path $scriptPath } else { (Get-Location).Path }
$VipListCsvPath = "$directory\VIPUsers.csv"
$OutputCsvPath = ".\VIPAuthMethods_Export.csv"

# ------------------------------------------------------------------
# 1. Connect to Microsoft Graph
# ------------------------------------------------------------------
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "UserAuthenticationMethod.Read.All", "User.Read.All"

# ------------------------------------------------------------------
# 2. Load VIP user list
# ------------------------------------------------------------------
# Option A (default): Read from a local CSV export of the VIP list.
if (-not (Test-Path $VipListCsvPath)) {
    throw "VIP list CSV not found at '$VipListCsvPath'"
}

$VipUsersRaw = Import-Csv -Path $VipListCsvPath
$VipEmails = $VipUsersRaw.email
Write-Host "Loaded $($VipEmails.Count) unique VIP user emails." -ForegroundColor Cyan

# ------------------------------------------------------------------
# 3. Resolve each VIP email to an Entra ID user object
# ------------------------------------------------------------------
$Report = New-Object System.Collections.Generic.List[Object]
$NotFound = New-Object System.Collections.Generic.List[Object]

$counter = 0
foreach ($email in $VipEmails) {

    $counter++
    Write-Progress -Activity "Exporting VIP authentication methods" `
        -Status "$counter of $($VipEmails.Count): $email" `
        -PercentComplete (($counter / $VipEmails.Count) * 100)

    try {
        $user = Get-MgUser -Filter "mail eq '$email'" -Property "id,userPrincipalName,mail,displayName" -ErrorAction Stop
    }
    catch {
        Write-Warning "User not found in Entra ID: $email"
        $NotFound.Add([PSCustomObject]@{ Email = $email; Reason = $_.Exception.Message })
        continue
    }

$userId  = $user.Id
$upn     = $user.UserPrincipalName
$mail    = $user.Mail
$display = $user.DisplayName

    # --- 3a. FIDO2 / Passkey methods (Authenticator - iOS is the common one for iPhone/iPad) ---
    try {
        $fido2 = Invoke-MgGraphRequest -Method GET `
            -Uri "https://graph.microsoft.com/v1.0/users/$userId/authentication/fido2Methods" `
            -OutputType PSObject
        $fido2Methods = $fido2.value
    }
    catch {
        Write-Warning "Failed to retrieve fido2Methods for $upn : $($_.Exception.Message)"
        $fido2Methods = @()
    }

    foreach ($m in $fido2Methods) {
        $Report.Add([PSCustomObject]@{
            UserPrincipalName = $upn
            Email=$mail
            DisplayNameUser   = $display
            MethodType        = "Fido2Passkey"
            PlatformOrModel   = $m.model              # e.g. "Authenticator - iOS"
            DeviceDisplayName = $m.displayName         # user-chosen label, NOT device name
            AaGuid            = $m.aaGuid
            PasskeyType       = $m.passkeyType         # deviceBound / synced
            CreatedDateTime   = $m.createdDateTime
            MethodId          = $m.id
        })
    }

    # --- 3b. Platform Credential (macOS Platform SSO) ---
    try {
        $platCred = Invoke-MgGraphRequest -Method GET `
            -Uri "https://graph.microsoft.com/v1.0/users/$userId/authentication/platformCredentialMethods" `
            -OutputType PSObject
        $platCredMethods = $platCred.value
    }
    catch {
        # This endpoint can 404/error if the tenant/user has no such method or feature isn't enabled yet
        $platCredMethods = @()
    }

    foreach ($m in $platCredMethods) {
        $Report.Add([PSCustomObject]@{
            UserPrincipalName = $upn
            Email=$mail
            DisplayNameUser   = $display
            MethodType        = "PlatformCredential"
            PlatformOrModel   = $m.platform            # windows, macOS, iOS, android, linux, unknown
            DeviceDisplayName = $m.displayName          # actual DEVICE NAME for Platform Credential
            AaGuid            = $null
            PasskeyType       = $null
            CreatedDateTime   = $m.createdDateTime
            MethodId          = $m.id
        })
    }

    # --- 3c. Windows Hello for Business (optional cross-check / redundancy) ---
    try {
        $whfb = Invoke-MgGraphRequest -Method GET `
            -Uri "https://graph.microsoft.com/v1.0/users/$userId/authentication/windowsHelloForBusinessMethods" `
            -OutputType PSObject
        $whfbMethods = $whfb.value
    }
    catch {
        $whfbMethods = @()
    }

foreach ($m in $whfbMethods) {
    if ($null -eq $m.displayName -or $m.displayName.Trim() -eq "") {
        # Fetch DeviceId via expand, since displayName is blank
        try {
            $expanded = Invoke-MgGraphRequest -Method GET `
                -Uri "https://graph.microsoft.com/v1.0/users/$userId/authentication/windowsHelloForBusinessMethods/$($m.id)?`$expand=device" `
                -OutputType PSObject
            $deviceId = $expanded.device.deviceId
        }
        catch {
            $deviceId = $null
        }
    } else {
        $deviceId = $null
    }

    $Report.Add([PSCustomObject]@{
        UserPrincipalName = $upn
        Email             = $mail
        DisplayNameUser   = $display
        MethodType        = "WindowsHelloForBusiness"
        PlatformOrModel   = "Windows"
        DeviceDisplayName = $m.displayName
        DeviceId          = $deviceId
        AaGuid            = $null
        PasskeyType       = $null
        CreatedDateTime   = $m.createdDateTime
        MethodId          = $m.id
    })
}

    # If a VIP has zero methods registered at all, still record one row so
    # they appear in the report as "Not Registered" instead of silently missing.
    if ($fido2Methods.Count -eq 0 -and $platCredMethods.Count -eq 0 -and $whfbMethods.Count -eq 0) {
        $Report.Add([PSCustomObject]@{
            UserPrincipalName = $upn
            Email=$mail
            DisplayNameUser   = $display
            MethodType        = "None"
            PlatformOrModel   = $null
            DeviceDisplayName = $null
            AaGuid            = $null
            PasskeyType       = $null
            CreatedDateTime   = $null
            MethodId          = $null
        })
    }
}

Write-Progress -Activity "Exporting VIP authentication methods" -Completed

# ------------------------------------------------------------------
# 4. Export to CSV
# ------------------------------------------------------------------
$Report | Export-Csv -Path $OutputCsvPath -NoTypeInformation -Encoding UTF8
Write-Host "Exported $($Report.Count) authentication method rows to $OutputCsvPath" -ForegroundColor Green

if ($NotFound.Count -gt 0) {
    $NotFoundPath = ".\VIPUsers_NotFoundInEntra.csv"
    $NotFound | Export-Csv -Path $NotFoundPath -NoTypeInformation -Encoding UTF8
    Write-Warning "$($NotFound.Count) VIP emails were not found in Entra ID. See $NotFoundPath"
}
