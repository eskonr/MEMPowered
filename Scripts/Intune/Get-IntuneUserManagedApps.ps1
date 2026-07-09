#=========================================================
# Intune Managed Apps Report by User
#
# Purpose:
#   Export Intune managed apps for all devices assigned
#   to one or more users (Primary User)
#
# Requirements:
#   Install-Module Microsoft.Graph.Authentication
#=========================================================

$ErrorActionPreference = "Stop"

#---------------------------------------------------------
# Output location: date folder next to the script
#---------------------------------------------------------

$todayDate    = Get-Date -Format 'dd-MM-yyyy'
$scriptPath   = $PSScriptRoot
$OutputFolder = Join-Path -Path $scriptPath -ChildPath $todayDate

if (-not (Test-Path -Path $OutputFolder)) {
    New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
}

# Master run log (shared across all users)
$RunLogFile = Join-Path $OutputFolder "_RunLog.log"

#---------------------------------------------------------
# Logging
#---------------------------------------------------------


function Write-Log {
    param(
        [string]$Message,
        [string]$Level = 'INFO',
        [string]$UserLogFile
    )

    $Line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Write-Host $Line

    Add-Content -Path $RunLogFile -Value $Line

    if ($UserLogFile -and $UserLogFile.Trim().Length -gt 0) {
        Add-Content -Path $UserLogFile -Value $Line
    }
}


#---------------------------------------------------------
# Graph Connect
#---------------------------------------------------------

Write-Log 'Connecting to Microsoft Graph...'

Connect-MgGraph -Scopes `
    'User.Read.All', `
    'DeviceManagementManagedDevices.Read.All', `
    'DeviceManagementApps.Read.All' `
    -NoWelcome

$Context = Get-MgContext
Write-Log "Connected as $($Context.Account)"

#---------------------------------------------------------
# Prompt Input
#---------------------------------------------------------

$InputValue = Read-Host 'Enter User UPN or TXT File '

if (Test-Path $InputValue) {
    $Users = Get-Content $InputValue |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ }

    Write-Log "Loaded $($Users.Count) user(s) from file: $InputValue"
}
else {
    $Users = @($InputValue.Trim())
    Write-Log 'Single user mode'
}

#---------------------------------------------------------
# Processing
#---------------------------------------------------------

$TotalUsers   = 0
$TotalDevices = 0
$TotalApps    = 0

foreach ($UPN in $Users) {

    $TotalUsers++

    # Per-user output files named by UPN (no timestamp)
    $CsvFile = Join-Path $OutputFolder "$UPN.csv"
    $LogFile = Join-Path $OutputFolder "$UPN.log"

    # Per-user results collection (reset each user)
    $Results = [System.Collections.Generic.List[Object]]::new()

    Write-Log "==== Processing $UPN ====" 'INFO' $LogFile

    try {

        $User = Get-MgUser `
            -UserId $UPN `
            -Property Id,DisplayName,UserPrincipalName

        if (-not $User) {
            Write-Log "User not found: $UPN" 'ERROR' $LogFile
            continue
        }

        #-------------------------------------------------
        # Find Intune devices where user is primary user
        #-------------------------------------------------

        $DeviceUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=userPrincipalName eq '$UPN'"

        $DeviceResponse = Invoke-MgGraphRequest `
            -Method GET `
            -Uri $DeviceUri

        $Devices = $DeviceResponse.value

        Write-Log "Devices found: $($Devices.Count)" 'INFO' $LogFile
        $TotalDevices += $Devices.Count

        foreach ($Device in $Devices) {

            $DeviceName      = $Device.deviceName
            $ManagedDeviceId = $Device.id

            Write-Log "Reading apps from $DeviceName" 'INFO' $LogFile

            try {

                $IntentUri = "https://graph.microsoft.com/beta/users('$($User.Id)')/mobileAppIntentAndStates('$ManagedDeviceId')"

                $AppState = Invoke-MgGraphRequest `
                    -Method GET `
                    -Uri $IntentUri

                if (-not $AppState.mobileAppList) {
                    Write-Log "No apps returned for $DeviceName" 'WARN' $LogFile
                    continue
                }

                foreach ($App in $AppState.mobileAppList) {

                    $TotalApps++

                    # ----------------------------
                    # Friendly Status Mapping
                    # ----------------------------

                    $FriendlyStatus = switch ($App.mobileAppIntent) {

                        "available" {
                            switch ($App.installState) {
                                "unknown"      { "Available for install" }
                                "installed"    { "Installed" }
                                "failed"       { "Failed" }
                                "notInstalled" { "Not Installed" }
                                default        { $App.installState }
                            }
                        }

                        "required" {
                            switch ($App.installState) {
                                "unknown"      { "Waiting for install status" }
                                "installed"    { "Installed" }
                                "failed"       { "Failed" }
                                "notInstalled" { "Not Installed" }
                                default        { $App.installState }
                            }
                        }

                        "uninstall" {
                            switch ($App.installState) {
                                "unknown"      { "Waiting for uninstall status" }
                                "installed"    { "Installed" }
                                "failed"       { "Failed uninstall" }
                                default        { $App.installState }
                            }
                        }

                        "exclude" {
                            "Excluded"
                        }

                        default {
                            $App.installState
                        }
                    }

                    $InstallStateDetail = $null
                    if ($App.PSObject.Properties.Name -contains "installStateDetail") {
                        $InstallStateDetail = $App.installStateDetail
                    }

                    $Results.Add(
                        [PSCustomObject]@{

                            UserUPN          = $UPN
                            DisplayName      = $User.DisplayName

                            DeviceName       = $DeviceName
                            ManagedDeviceId  = $ManagedDeviceId

                            AzureADDeviceId  = $Device.azureADDeviceId
                            SerialNumber     = $Device.serialNumber

                            OperatingSystem  = $Device.operatingSystem
                            OSVersion        = $Device.osVersion

                            LastSyncDateTime = $Device.lastSyncDateTime

                            AppName          = $App.displayName
                            AppVersion       = $App.displayVersion
                            ApplicationId    = $App.applicationId

                            RawIntent        = $App.mobileAppIntent
                            RawInstallState  = $App.installState

                            FriendlyStatus   = $FriendlyStatus

                            InstallStateDetail = $InstallStateDetail
                        }
                    )
                }

                Write-Log "$DeviceName - Apps Found: $($AppState.mobileAppList.Count)" 'INFO' $LogFile
            }
            catch {
                Write-Log "$DeviceName - App query failed: $($_.Exception.Message)" 'ERROR' $LogFile
            }
        }
    }
    catch {
        Write-Log "$UPN - Failed: $($_.Exception.Message)" 'ERROR' $LogFile
    }

    #-----------------------------------------------------
    # Export Results (per user)
    #-----------------------------------------------------

    if ($Results.Count -gt 0) {

        $Results |
            Sort-Object UserUPN, DeviceName, AppName |
            Export-Csv `
                -Path $CsvFile `
                -Encoding UTF8 `
                -NoTypeInformation

        Write-Log "Exported $($Results.Count) app record(s) for $UPN -> $CsvFile" 'SUCCESS' $LogFile
    }
    else {
        Write-Log "No app records for $UPN. No CSV created." 'WARN' $LogFile
    }
}

#---------------------------------------------------------
# Summary
#---------------------------------------------------------

Write-Log '--------------------------------------------'
Write-Log "Users Processed : $TotalUsers"
Write-Log "Devices Found   : $TotalDevices"
Write-Log "Apps Exported   : $TotalApps"
Write-Log "Output Folder   : $OutputFolder"
Write-Log "Run Log         : $RunLogFile"
Write-Log '--------------------------------------------'

Disconnect-MgGraph

Write-Host ''
Write-Host 'Completed.'
Write-Host "Output Folder : $OutputFolder"