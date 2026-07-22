<#
.SYNOPSIS
    Exports Entra ID (Azure AD) user authentication method registration details to CSV
    

.DESCRIPTION
    - No App Registration / ClientId / ClientSecret required.
    - Uses Connect-MgGraph (from the lightweight Microsoft.Graph.Authentication module)
      - Calls the beta reports endpoint DIRECTLY via Invoke-MgGraphRequest (no Reports SDK):
        GET /beta/reports/authenticationMethods/userRegistrationDetails
    - Handles server-side paging automatically via @odata.nextLink.
    - Filters out external/guest accounts (*#EXT#@*).
    - Deduplicates by UPN, keeping the most recent record (lastUpdatedDateTime).
    - Flattens key properties and arrays into CSV-friendly columns.
    - Measures and prints total execution time.

.REQUIREMENTS
    - PowerShell 5.1 or 7+ (7+ recommended for performance).
    - Module: Microsoft.Graph.Authentication  (small — just the auth layer, NOT the full SDK).
    - Your signed-in account needs the delegated permission
        AuthenticationMethod.Read.All  (or UserAuthenticationMethod.Read.All)
      and an appropriate directory role (e.g., Global Reader / Reports Reader /
      Authentication Policy Administrator) to read tenant-wide reports.

.OUTPUTS
    - CSV file: exportUserRegistrationDetails.csv written to the script directory.

.NOTES
    - The FIRST time you run this, you may be asked to consent to the requested scope.
    - This uses Invoke-MgGraphRequest so the actual data call is a raw REST call — you are
      NOT dependent on Get-MgBetaReport... cmdlets.

.EXAMPLE
    .\Export-UserRegistrationDetails-GraphAPI-UserAuth.ps1
#>

# ============================================================================
# START TIME TRACKING
# ============================================================================
$scriptStart = Get-Date

# Define script location and output file
$scriptPath = $MyInvocation.MyCommand.Path
$directory  = if ($scriptPath) { Split-Path $scriptPath } else { (Get-Location).Path }
$outputCsv  = Join-Path $directory "ExportUserRegistrationDetails.csv"

# Graph endpoint (beta is required for userRegistrationDetails)
$ReportUri  = "https://graph.microsoft.com/beta/reports/authenticationMethods/userRegistrationDetails"

# ============================================================================
# FUNCTION: Ensure only the lightweight auth module is present
# ============================================================================
function Ensure-GraphAuthModule {
    $moduleName = "Microsoft.Graph.Authentication"
    if (-not (Get-Module -ListAvailable -Name $moduleName)) {
        Write-Host "$moduleName not found. Installing..." -ForegroundColor Yellow
        try {
            Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber
            Import-Module $moduleName
        } catch {
            Write-Host "Failed to install '$moduleName'. Please install it manually." -ForegroundColor Red
            exit 1
        }
    } else {
        Import-Module $moduleName -ErrorAction SilentlyContinue
        Write-Host "$moduleName is available." -ForegroundColor Green
    }
}

# ============================================================================
# FUNCTION: Interactive user sign-in (delegated) — pop-up window
# ============================================================================
function Authenticate-Graph {
    try {
        Write-Host "Authenticating with Microsoft Graph, please look out for a pop-up window" -ForegroundColor Yellow
        Connect-MgGraph -NoWelcome
        Write-Host "Authentication successful." -ForegroundColor Green
    } catch {
        Write-Host "Failed to authenticate with Microsoft Graph: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# ============================================================================
# FUNCTION: GET all pages from a Graph collection endpoint (raw REST)
# ============================================================================
function Get-GraphAllPages {
    param(
        [Parameter(Mandatory)] [string]$Uri
    )

    $all  = New-Object System.Collections.Generic.List[object]
    $next = $Uri
    $page = 0

    do {
        try {
            # Invoke-MgGraphRequest reuses the Connect-MgGraph token automatically.
            # -OutputType PSObject returns a normal object (with @odata.nextLink accessible).
            $response = Invoke-MgGraphRequest -Method GET -Uri $next -OutputType PSObject -ErrorAction Stop
        }
        catch {
            Write-Host "Graph request failed: $($_.Exception.Message)" -ForegroundColor Red
            if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message -ForegroundColor DarkYellow }
            exit 1
        }

        if ($response.value) { $all.AddRange($response.value) }
        $page++
        Write-Host ("  Retrieved page {0} - running total: {1}" -f $page, $all.Count) -ForegroundColor DarkGray

        # Follow paging link (property name is '@odata.nextLink')
        $next = $response.'@odata.nextLink'
    } while ($next)

    return $all
}

# ============================================================================
# MAIN
# ============================================================================
Ensure-GraphAuthModule
Authenticate-Graph

Write-Host "Gathering the Entra ID User Authentication methods.. please wait" -ForegroundColor Green
$raw = Get-GraphAllPages -Uri $ReportUri

# Filter out guest/external UPNs (client-side)
$raw = $raw | Where-Object { $_.userPrincipalName -notlike '*#EXT#@*' }
Write-Host "Records after excluding guest/#EXT# accounts: $($raw.Count)" -ForegroundColor Green

# Deduplicate: group by UPN, keep most recent by LastUpdatedDateTime

$latestByUpn = @{}

foreach ($r in $raw) {
    $upn = $r.userPrincipalName
    if (-not $latestByUpn.ContainsKey($upn)) {
        $latestByUpn[$upn] = $r
    } else {
        if ($r.lastUpdatedDateTime -gt $latestByUpn[$upn].lastUpdatedDateTime) {
            $latestByUpn[$upn] = $r
        }
    }
}

$deduped = $latestByUpn.Values
Write-Host "Records after de-duplication: $($deduped.Count)" -ForegroundColor Green

# Flatten key fields + arrays into CSV-friendly columns
$results = $deduped | ForEach-Object {
    [PSCustomObject]@{
        userPrincipalName                             = $_.userPrincipalName
        userDisplayName                               = $_.userDisplayName
        isAdmin                                       = $_.isAdmin
        isSsprRegistered                              = $_.isSsprRegistered
        isSsprEnabled                                 = $_.isSsprEnabled
        isSsprCapable                                 = $_.isSsprCapable
        isMfaRegistered                               = $_.isMfaRegistered
        isMfaCapable                                  = $_.isMfaCapable
        isPasswordlessCapable                         = $_.isPasswordlessCapable
        methodsRegistered                             = ($_.methodsRegistered -join ', ')
        isSystemPreferredAuthenticationMethodEnabled  = $_.isSystemPreferredAuthenticationMethodEnabled
        systemPreferredAuthenticationMethods          = ($_.systemPreferredAuthenticationMethods -join ', ')
        userPreferredMethodForSecondaryAuthentication = $_.userPreferredMethodForSecondaryAuthentication
        lastUpdatedDateTime                           = $_.lastUpdatedDateTime
        defaultMfaMethod                              = $_.defaultMfaMethod
    }
}

# Export
$results | Export-Csv -Path $outputCsv -NoTypeInformation -Encoding UTF8
Write-Host "Exported $($results.Count) user registration details to $outputCsv" -ForegroundColor Green

# Optional: disconnect the session
 Disconnect-MgGraph | Out-Null

# ============================================================================
# END TIME TRACKING AND REPORT
# ============================================================================
$scriptEnd      = Get-Date
$elapsedSeconds = [math]::Round(($scriptEnd - $scriptStart).TotalSeconds, 2)
$elapsedMinutes = [math]::Round(($scriptEnd - $scriptStart).TotalMinutes, 2)
Write-Host "Total time taken: $elapsedSeconds seconds ($elapsedMinutes minutes)" -ForegroundColor Cyan
