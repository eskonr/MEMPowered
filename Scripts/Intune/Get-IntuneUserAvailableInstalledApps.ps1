<#
.SYNOPSIS
    Export Intune "available" apps that are "installed" on Windows devices where the input user is primary user.
    Assignment groups are filtered to ONLY those the user is a member of (including nested groups).
    One CSV + one log per user, named by UPN.

.PERMISSIONS
    User.Read.All, Group.Read.All, GroupMember.Read.All,
    DeviceManagementManagedDevices.Read.All, DeviceManagementApps.Read.All,
    DeviceManagementConfiguration.Read.All
#>

$ErrorActionPreference = "Stop"

$TimeStamp    = Get-Date -Format 'yyyyMMdd_HHmmss'
$todayDate    = Get-Date -Format 'dd-MM-yyyy'
$scriptPath   = $PSScriptRoot
$OutputFolder = Join-Path -Path $scriptPath -ChildPath $todayDate

if (-not (Test-Path -Path $OutputFolder)) {
    New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
}

# Master run log (shared across all users)
$RunLogFile = Join-Path $OutputFolder "_RunLog_$TimeStamp.log"

$script:AppCache        = @{}
$script:AssignmentCache = @{}
$script:UserGroupCache  = @{}

$TotalUsers                  = 0
$TotalDevices                = 0
$TotalInstalledAvailableApps = 0
$TotalErrors                 = 0

#---------------------------------------------------------
# Helpers
#---------------------------------------------------------

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO",

        [string]$UserLogFile
    )

    $Line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Write-Host $Line

    Add-Content -Path $RunLogFile -Value $Line

    if (-not (Test-Empty $UserLogFile)) {
        Add-Content -Path $UserLogFile -Value $Line
    }
}

function Test-Empty {
    param($Value)

    if ($null -eq $Value) {
        return $true
    }

    if ("$Value".Trim().Length -eq 0) {
        return $true
    }

    return $false
}

function Escape-ODataString {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return $Value.Replace("'", "''")
}

function Invoke-GraphGet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [int]$MaxRetry = 5
    )

    $Attempt = 0

    while ($true) {
        try {
            return Invoke-MgGraphRequest -Method GET -Uri $Uri
        }
        catch {
            $Attempt++

            $StatusCode = $null
            try {
                $StatusCode = [int]$_.Exception.Response.StatusCode
            }
            catch {
                $StatusCode = $null
            }

            if (($StatusCode -eq 429 -or $StatusCode -ge 500) -and $Attempt -le $MaxRetry) {

                $SleepSeconds = $Attempt * 5
                if ($SleepSeconds -gt 30) {
                    $SleepSeconds = 30
                }

                Write-Log "Transient Graph error or throttling. Retry in $SleepSeconds s. URI: $Uri" "WARN"
                Start-Sleep -Seconds $SleepSeconds
                continue
            }

            throw
        }
    }
}

function Get-GraphCollection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri
    )

    $Items   = @()
    $NextUri = $Uri

    while (-not (Test-Empty $NextUri)) {

        $Response = Invoke-GraphGet -Uri $NextUri

        if ($null -ne $Response.value) {
            foreach ($Item in $Response.value) {
                $Items += $Item
            }
        }
        else {
            $Items += $Response
        }

        $NextUri = $Response.'@odata.nextLink'
    }

    return $Items
}

function Get-InputUsers {

    $InputValue = Read-Host "Enter User UPN or TXT file path"

    if (Test-Empty $InputValue) {
        throw "Input cannot be empty."
    }

    if (Test-Path -Path $InputValue) {

        $Users = Get-Content -Path $InputValue |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not (Test-Empty $_) } |
            Sort-Object -Unique

        Write-Log "Loaded $($Users.Count) user(s) from file: $InputValue"
        return $Users
    }
    else {
        Write-Log "Single user mode selected."
        return @($InputValue.Trim())
    }
}

function Get-EntraUserByUpn {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UPN
    )

    $EscapedUPN = Escape-ODataString -Value $UPN
    $Uri = "https://graph.microsoft.com/v1.0/users('$EscapedUPN')?`$select=id,displayName,userPrincipalName"

    return Invoke-GraphGet -Uri $Uri
}

function Get-UserGroupMembershipSet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserId,

        [string]$UserLogFile
    )

    if ($script:UserGroupCache.ContainsKey($UserId)) {
        return $script:UserGroupCache[$UserId]
    }

    $Set = @{}

    $Uri = "https://graph.microsoft.com/v1.0/users/$UserId/transitiveMemberOf/microsoft.graph.group?`$select=id,displayName"

    try {
        $Groups = Get-GraphCollection -Uri $Uri

        foreach ($Group in $Groups) {
            if (-not (Test-Empty $Group.id)) {
                $Set[$Group.id] = $Group.displayName
            }
        }
    }
    catch {
        Write-Log "Failed to get transitive group membership for user $UserId. $($_.Exception.Message)" "WARN" $UserLogFile
    }

    $script:UserGroupCache[$UserId] = $Set
    return $Set
}

function Get-WindowsManagedDevicesForUser {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UPN
    )

    $EscapedUPN = Escape-ODataString -Value $UPN

    $Uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=userPrincipalName eq '$EscapedUPN' and operatingSystem eq 'Windows'&`$select=id,deviceName,userPrincipalName,operatingSystem,osVersion,lastSyncDateTime,azureADDeviceId,serialNumber"

    return Get-GraphCollection -Uri $Uri
}

function Get-MobileAppIntentStateForUserDevice {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserId,

        [Parameter(Mandatory = $true)]
        [string]$ManagedDeviceId,

        [string]$UserLogFile
    )

    $Uri = "https://graph.microsoft.com/beta/users('$UserId')/mobileAppIntentAndStates('$ManagedDeviceId')"

    try {
        return Invoke-GraphGet -Uri $Uri
    }
    catch {
        Write-Log "mobileAppIntentAndStates lookup failed for device $ManagedDeviceId. $($_.Exception.Message)" "WARN" $UserLogFile
        return $null
    }
}

function Get-IntuneMobileAppById {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppId,

        [string]$UserLogFile
    )

    if ($script:AppCache.ContainsKey($AppId)) {
        return $script:AppCache[$AppId]
    }

    $Uri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$AppId"

    try {
        $App = Invoke-GraphGet -Uri $Uri
        $script:AppCache[$AppId] = $App
        return $App
    }
    catch {
        Write-Log "Failed to get Intune app details for appId $AppId. $($_.Exception.Message)" "WARN" $UserLogFile
        $script:AppCache[$AppId] = $null
        return $null
    }
}

function Get-AvailableAssignmentsForApp {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppId,

        [Parameter(Mandatory = $true)]
        [string]$UserId,

        [Parameter(Mandatory = $true)]
        [hashtable]$UserGroupSet,

        [string]$UserLogFile
    )

    $CacheKey = "$UserId|$AppId"

    if ($script:AssignmentCache.ContainsKey($CacheKey)) {
        return $script:AssignmentCache[$CacheKey]
    }

    $Uri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps('$AppId')/assignments"

    try {
        $Assignments = Get-GraphCollection -Uri $Uri

        $AvailableAssignments = @(
            $Assignments | Where-Object {
                $_.intent -eq "available" -or $_.intent -eq "availableWithoutEnrollment"
            }
        )

        $AssignmentTexts = @()

        foreach ($Assignment in $AvailableAssignments) {

            $Target     = $Assignment.target
            $Intent     = $Assignment.intent
            $TargetType = $null

            if ($null -ne $Target) {
                $TargetType = $Target.'@odata.type'
            }

            switch ($TargetType) {

                "#microsoft.graph.groupAssignmentTarget" {
                    if ($UserGroupSet.ContainsKey($Target.groupId)) {
                        $GroupName = $UserGroupSet[$Target.groupId]
                        $AssignmentTexts += "$Intent / include / $GroupName"
                    }
                }

                "#microsoft.graph.allLicensedUsersAssignmentTarget" {
                    $AssignmentTexts += "$Intent / include / All licensed users"
                }

                "#microsoft.graph.allDevicesAssignmentTarget" {
                    $AssignmentTexts += "$Intent / include / All devices"
                }

                default {
                    # Exclusion / unknown target types are skipped
                }
            }
        }

        $AssignmentText = ($AssignmentTexts | Sort-Object -Unique) -join " | "

        if (Test-Empty $AssignmentText) {
            $AssignmentText = "No matching available assignment for this user"
        }

        $script:AssignmentCache[$CacheKey] = $AssignmentText
        return $AssignmentText
    }
    catch {
        Write-Log "Failed to get assignments for appId $AppId. $($_.Exception.Message)" "WARN" $UserLogFile
        $script:AssignmentCache[$CacheKey] = "Assignment lookup failed"
        return "Assignment lookup failed"
    }
}

function Get-FallbackValue {
    param(
        $PrimaryValue,
        $FallbackValue
    )

    if (-not (Test-Empty $PrimaryValue)) {
        return $PrimaryValue
    }

    return $FallbackValue
}

#---------------------------------------------------------
# Main
#---------------------------------------------------------

try {
    Write-Log "Script started. Output folder: $OutputFolder"

    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        Write-Log "Microsoft.Graph.Authentication module not found. Installing for CurrentUser." "WARN"
        Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force -AllowClobber
    }

    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

    $Scopes = @(
        "User.Read.All",
        "Group.Read.All",
        "GroupMember.Read.All",
        "DeviceManagementManagedDevices.Read.All",
        "DeviceManagementApps.Read.All",
        "DeviceManagementConfiguration.Read.All"
    )

    Write-Log "Connecting to Microsoft Graph interactively."
    Connect-MgGraph -Scopes $Scopes -NoWelcome | Out-Null

    $Context = Get-MgContext
    Write-Log "Connected as $($Context.Account)" "SUCCESS"

    $Users = Get-InputUsers

    foreach ($UPN in $Users) {

        $TotalUsers++

        # Per-user output files named by UPN (raw UPN, @ preserved)
        $UserCsvFile = Join-Path $OutputFolder "$UPN`_$TimeStamp.csv"
        $UserLogFile = Join-Path $OutputFolder "$UPN`_$TimeStamp.log"

        # *** FIX: reset the results collection for THIS user ***
        $UserResultsRaw = @()

        Write-Log "==== Processing user: $UPN ====" "INFO" $UserLogFile

        try {
            $User = Get-EntraUserByUpn -UPN $UPN
        }
        catch {
            $TotalErrors++
            Write-Log "Failed to get user $UPN. $($_.Exception.Message)" "ERROR" $UserLogFile
            continue
        }

        $UserGroupSet = Get-UserGroupMembershipSet -UserId $User.id -UserLogFile $UserLogFile
        Write-Log "User $UPN is a member of $($UserGroupSet.Count) group(s) (including nested)." "INFO" $UserLogFile

        try {
            $Devices = Get-WindowsManagedDevicesForUser -UPN $UPN
        }
        catch {
            $TotalErrors++
            Write-Log "Failed to get Windows devices for $UPN. $($_.Exception.Message)" "ERROR" $UserLogFile
            continue
        }

        Write-Log "Windows devices found for $UPN : $($Devices.Count)" "INFO" $UserLogFile
        $TotalDevices += $Devices.Count

        foreach ($Device in $Devices) {

            $DeviceName      = $Device.deviceName
            $ManagedDeviceId = $Device.id

            if (Test-Empty $ManagedDeviceId) {
                Write-Log "Skipping device with empty managedDeviceId for $UPN." "WARN" $UserLogFile
                continue
            }

            Write-Log "Reading managed apps for device: $DeviceName" "INFO" $UserLogFile

            $AppState = Get-MobileAppIntentStateForUserDevice -UserId $User.id -ManagedDeviceId $ManagedDeviceId -UserLogFile $UserLogFile

            if ($null -eq $AppState -or $null -eq $AppState.mobileAppList) {
                Write-Log "No mobileAppList returned for $DeviceName." "WARN" $UserLogFile
                continue
            }

            foreach ($AppStateItem in $AppState.mobileAppList) {

                $RawIntent       = $AppStateItem.mobileAppIntent
                $RawInstallState = $AppStateItem.installState

                if ($RawIntent -ne "available" -or $RawInstallState -ne "installed") {
                    continue
                }

                $AppId = $AppStateItem.applicationId

                if (Test-Empty $AppId) {
                    Write-Log "Skipping app with empty applicationId on $DeviceName. App: $($AppStateItem.displayName)" "WARN" $UserLogFile
                    continue
                }

                $TotalInstalledAvailableApps++

                $IntuneApp   = Get-IntuneMobileAppById -AppId $AppId -UserLogFile $UserLogFile
                $Assignments = Get-AvailableAssignmentsForApp -AppId $AppId -UserId $User.id -UserGroupSet $UserGroupSet -UserLogFile $UserLogFile

                $DisplayName = Get-FallbackValue -PrimaryValue $IntuneApp.displayName -FallbackValue $AppStateItem.displayName
                $Description = Get-FallbackValue -PrimaryValue $IntuneApp.description -FallbackValue ""
                $FinalAppId  = Get-FallbackValue -PrimaryValue $IntuneApp.id -FallbackValue $AppId

                # *** FIX: add to the PER-USER collection ***
                $UserResultsRaw += [PSCustomObject]@{
                    displayName = $DisplayName
                    description = $Description
                    assignments = $Assignments
                    id          = $FinalAppId
                    deviceName  = $DeviceName
                }
            }
        }

        #-------------------------------------------------
        # *** FIX: group + export INSIDE the loop, per user ***
        #-------------------------------------------------

        $UserFinalResults = $UserResultsRaw |
            Group-Object id |
            ForEach-Object {

                $Rows  = $_.Group
                $First = $Rows | Select-Object -First 1

                [PSCustomObject]@{
                    displayName = $First.displayName
                    description = $First.description
                    assignments = $First.assignments
                    id          = $First.id
                    deviceName  = (($Rows.deviceName | Sort-Object -Unique) -join " | ")
                }
            } |
            Sort-Object displayName

        if ($UserFinalResults.Count -gt 0) {
            $UserFinalResults |
                Export-Csv -Path $UserCsvFile -NoTypeInformation -Encoding UTF8

            Write-Log "Exported $($UserFinalResults.Count) app(s) for $UPN -> $UserCsvFile" "SUCCESS" $UserLogFile
        }
        else {
            Write-Log "No available+installed apps found for $UPN. No CSV created." "WARN" $UserLogFile
        }
    }

    Write-Log "--------------------------------------------"
    Write-Log "Users processed                     : $TotalUsers"
    Write-Log "Windows devices found               : $TotalDevices"
    Write-Log "Available + installed app instances : $TotalInstalledAvailableApps"
    Write-Log "Output folder                       : $OutputFolder"
    Write-Log "Run log                             : $RunLogFile"
    Write-Log "--------------------------------------------"
    Write-Log "Script completed." "SUCCESS"
}
catch {
    $TotalErrors++
    Write-Log "Fatal error: $($_.Exception.Message)" "ERROR"
    throw
}
finally {
    try {
        Disconnect-MgGraph | Out-Null
        Write-Log "Disconnected from Microsoft Graph."
    }
    catch {
        # Ignore disconnect issues
    }
}