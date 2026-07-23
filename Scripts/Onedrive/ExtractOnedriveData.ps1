<#
.SYNOPSIS
    Exports OneDrive Sync App Health data (config.office.com) to CSV with
    portal-friendly formatting for Power BI / Known Folder Move reporting.

.DESCRIPTION
    TOKEN HANDLING (no more copy-paste from the browser):
      - Uses MSAL.PS against the M365 Apps admin center first-party client.
      - Interactive sign-in ONLY the first time; MSAL caches a refresh token.
      - Every subsequent run acquires the token SILENTLY (no prompt) until the
        refresh token expires (~90 days). Ideal for a daily scheduled task.
      - -DeviceCode switch: sign in via microsoft.com/devicelogin (headless).
      - -ManualToken "<token>": last-resort paste from F12.

.EXAMPLE
    .\Get-OneDriveSyncHealthReport.ps1
    First run prompts once; later runs are silent.

.EXAMPLE
    .\Get-OneDriveSyncHealthReport.ps1 -DeviceCode
    Use device-code sign-in on a headless server.

.NOTES
    Author : Eswar Koneti   |  Updated: 21-Jul-2026
#>

param(
    [switch]$DeviceCode,
    [string]$ManualToken
)

# ============================================================================
# 1. CONFIGURATION
# ============================================================================
$ClientId  = "3cf6df92-2745-4f6f-bbcf-19b59bcdb62a"
$TenantId  = "5d3e2773-e07f-4432-a630-1a0f68a28a05"    # MFCGD tenant
$Scope     = "https://config.office.net/user_impersonation"

$TokenCacheDir  = Join-Path $env:LOCALAPPDATA "ODSyncHealth"
$TokenCacheFile = Join-Path $TokenCacheDir "msal.cache"

# ============================================================================
# 2. TOKEN ACQUISITION
# ============================================================================
function Get-ConfigOfficeToken {

    if ($ManualToken) {
        Write-Host "Using manually supplied token." -ForegroundColor Yellow
        return $ManualToken
    }

    if (-not (Get-Module -ListAvailable -Name MSAL.PS)) {
        Write-Host "Installing MSAL.PS for current user..." -ForegroundColor Yellow
        Install-Module MSAL.PS -Scope CurrentUser -Force -ErrorAction Stop
    }
    Import-Module MSAL.PS -ErrorAction Stop

    if (-not (Test-Path $TokenCacheDir)) {
        New-Item -ItemType Directory -Path $TokenCacheDir -Force | Out-Null
    }

    $common = @{
        ClientId = $ClientId
        TenantId = $TenantId
        Scopes   = $Scope
    }

    # 1) Try SILENT first (uses cached refresh token)
    try {
        $t = Get-MsalToken @common -Silent -ErrorAction Stop
        Write-Host "Token acquired silently from cache." -ForegroundColor Green
        return $t.AccessToken
    }
    catch {
        Write-Host "No valid cached token - interactive sign-in required (one time)." -ForegroundColor Yellow
    }

    # 2) Device code (headless)
    if ($DeviceCode) {
        $t = Get-MsalToken @common -DeviceCode -ErrorAction Stop
        Write-Host "Token acquired via device code." -ForegroundColor Green
        return $t.AccessToken
    }

    # 3) Interactive (browser) - cached for next time
    $t = Get-MsalToken @common -Interactive -ErrorAction Stop
    Write-Host "Token acquired interactively (cached for silent reuse)." -ForegroundColor Green
    return $t.AccessToken
}

$bearertoken = Get-ConfigOfficeToken
if (-not $bearertoken) { throw "No valid bearer token available. Aborting." }

# ============================================================================
# 3. HELPERS  (folder logic + formatting)
# ============================================================================
function Convert-KnownFolders {
    param($KfmFolders)
    $names = @()
    foreach ($f in $KfmFolders) {
        switch ([int]$f) {
            1 { $names += "Desktop"   }
            2 { $names += "Documents" }
            3 { $names += "Pictures"  }
            default { $names += "$f"  }
        }
    }
    $display = switch ($names.Count) {
        0       { "None" }
        3       { "All"  }
        default { $names -join ", " }
    }
    [PSCustomObject]@{ Display = $display; Raw = ($names -join "; ") }
}

function Convert-LocalTime {
    param($TimeStamp)
    if (-not $TimeStamp) { return "" }
    try { return ([datetime]$TimeStamp).ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss") }
    catch { return $TimeStamp }
}

# ============================================================================
# 4. API CALL  (with paging)
# ============================================================================
$Headers = @{
    "authority"                 = "clients.config.office.net"
    "x-manageoffice-client-sid" = "b095b2a1-c688-471d-98cb-d05cab21131e"
    "x-correlationid"           = (New-Guid).ToString()
    "authorization"             = "Bearer $bearertoken"
    "accept"                    = "application/json"
    "x-requested-with"          = "XMLHttpRequest"
    "user-agent"                = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.77 Safari/537.36 Edg/91.0.864.41"
    "origin"                    = "https://config.office.com"
    "referer"                   = "https://config.office.com/"
    "accept-language"           = "en-US,en;q=0.9"
}

$BaseUri     = "https://clients.config.office.net/odbhealth/v1.0/synchealth/reports"
$reportarray = New-Object System.Collections.Generic.List[object]

function Add-Records {
    param($Reports)
    foreach ($user in $Reports) {
        $kf          = Convert-KnownFolders -KfmFolders $user.kfmFolders
        $errorStatus = if ($user.totalErrorCount -eq 0) { "0 errors" }
                       else { "$($user.totalErrorCount) errors" }

        $reportarray.Add(
            [PSCustomObject]@{
                User               = $user.userName
                UserEmail          = $user.userEmail
                DeviceName         = $user.deviceName
                Errors             = $errorStatus
                ErrorCount         = $user.totalErrorCount
                KnownFolders       = $kf.Display
                KnownFolderCount   = $user.kfmFolderCount
                KFMFoldersRaw      = $kf.Raw
                AppVersion         = $user.oneDriveVersion
                OperatingSystem    = $user.operatingSystem
                LastSynced         = Convert-LocalTime $user.lastUpToDateSyncTimestamp
                LastStatusReported = Convert-LocalTime $user.reportTimestamp
                KFMWizardEnabled   = $user.kfmOptInWithWizardGPOEnabled
                KFMSilentEnabled   = $user.kfmSilentOptInGPOEnabled
                UpdateRing         = $user.updateRing
                OneDriveDeviceId   = $user.oneDriveDeviceId
            }
        )
    }
}

Write-Host "Retrieving OneDrive sync health data..." -ForegroundColor Cyan

$report = Invoke-RestMethod -Method Get -Headers $Headers -Uri "$BaseUri?orderby=UserName%20asc"
Add-Records -Reports $report.reports

while ($report.skipToken) {
    $nextUri = "$BaseUri?skiptoken=$($report.skipToken)&collectionId=0&orderby=UserName%20asc"
    $report  = Invoke-RestMethod -Method Get -Headers $Headers -Uri $nextUri
    Add-Records -Reports $report.reports
    Write-Host "  ...retrieved $($reportarray.Count) devices so far" -ForegroundColor DarkGray
}

# ============================================================================
# 5. EXPORT + CONSOLE OUTPUT
# ============================================================================
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$CsvPath   = Join-Path $scriptDir "OneDriveSyncHealth_$(Get-Date -Format yyyyMMdd_HHmmss).csv"

$reportarray | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8

$reportarray |
    Select-Object User, UserEmail, DeviceName, Errors, KnownFolders,
                  AppVersion, OperatingSystem, LastSynced, LastStatusReported |
    Format-Table -AutoSize

Write-Host ""
Write-Host "Devices Found : $($reportarray.Count)" -ForegroundColor Green
Write-Host "CSV Saved     : $CsvPath"              -ForegroundColor Green