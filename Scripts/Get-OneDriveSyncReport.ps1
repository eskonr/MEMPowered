<#
.SYNOPSIS
    Exports OneDrive Sync App Health data (from config.office.com) to CSV
    with portal-friendly formatting for Power BI / Known Folder Move reporting.
.NOTES
    Author : Eswar Koneti
    Updated: 21-Jul-2026
#>

$bearertoken="eyJ0"
    

    $reportarray = @()

    # Get report data
    $report = Invoke-RestMethod -Method Get -Uri "https://clients.config.office.net/odbhealth/v1.0/synchealth/reports?orderby=UserName%20asc" -Headers @{
        "authority"                 = "clients.config.office.net"
        "scheme"                    = "https"
        "path"                      = "/odbhealth/v1.0/synchealth/reports?orderby=UserName%20asc"
        "x-manageoffice-client-sid" = "b095b2a1-c688-471d-98cb-d05cab21131e"
        "x-correlationid"           = "1e5b8c76-c130-4b65-b91b-f065137c4edc"
        "sec-ch-ua-mobile"          = "?0"
        "authorization"             = "Bearer $bearertoken"
        "accept"                    = "application/json"
        "x-requested-with"          = "XMLHttpRequest"
        "user-agent"                = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.77 Safari/537.36 Edg/91.0.864.41"
        "sec-ch-ua"                 = "`" Not;A Brand`";v=`"99`", `"Microsoft Edge`";v=`"91`", `"Chromium`";v=`"91`""
        "x-start-time"              = "1623340536521"
        "origin"                    = "https://config.office.com"
        "sec-fetch-site"            = "cross-site"
        "sec-fetch-mode"            = "cors"
        "sec-fetch-dest"            = "empty"
        "referer"                   = "https://config.office.com/"
        "accept-encoding"           = "gzip, deflate, br"
        "accept-language"           = "en-US,en;q=0.9"
    }

    # Add record to array
    foreach ($user in $report.reports) {
        $record = @{
            "userName"                     = ""
            "userEmail"                    = ""
            "kfmState"                     = ""
            "kfmOptInWithWizardGPOEnabled" = ""
            "kfmSilentOptInGPOEnabled"     = ""
            "kfmFolderCount"               = ""
            "kfmFolders"                   = ""
            "totalErrorCount"              = ""
            "lastUpToDateSyncTimestamp"    = ""
            "reportTimestamp"              = ""
            "oneDriveDeviceId"             = ""
            "deviceName"                   = ""
            "oneDriveVersion"              = ""
            "updateRing"                   = ""
        }
        $record."userName" = $user.userName
        $record."userEmail" = $user.userEmail 
        $record."kfmState" = $user.kfmState
        $record."kfmOptInWithWizardGPOEnabled" = $user.kfmOptInWithWizardGPOEnabled
        $record."kfmSilentOptInGPOEnabled" = $user.kfmSilentOptInGPOEnabled
        $record."kfmFolderCount" = $user.kfmFolderCount
        $record."kfmFolders" = $user.kfmFolders | Out-String
        $record."totalErrorCount" = $user.totalErrorCount
        $record."lastUpToDateSyncTimestamp" = $user.lastUpToDateSyncTimestamp
        $record."reportTimestamp" = $user.reportTimestamp
        $record."oneDriveDeviceId" = $user.oneDriveDeviceId
        $record."deviceName" = $user.deviceName
        $record."oneDriveVersion" = $user.oneDriveVersion
        $record."updateRing" = $user.updateRing

        $objRecord = New-Object PSObject -property $record
        $reportarray += $objrecord
    }

    while ($report.skipToken) {
        # Get next set of report data
        $report = Invoke-RestMethod -Method Get -Uri "https://clients.config.office.net/odbhealth/v1.0/synchealth/reports?skiptoken=$($report.skiptoken)&collectionId=0&orderby=UserName%20asc" -Headers @{
            "authority"                 = "clients.config.office.net"
            "scheme"                    = "https"
            "path"                      = "/odbhealth/v1.0/synchealth/reports"
            "x-manageoffice-client-sid" = "b095b2a1-c688-471d-98cb-d05cab21131e"
            "x-correlationid"           = "1e5b8c76-c130-4b65-b91b-f065137c4edc"
            "sec-ch-ua-mobile"          = "?0"
            "authorization"             = "Bearer $bearertoken"
            "accept"                    = "application/json"
            "x-requested-with"          = "XMLHttpRequest"
            "user-agent"                = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.77 Safari/537.36 Edg/91.0.864.41"
            "sec-ch-ua"                 = "`" Not;A Brand`";v=`"99`", `"Microsoft Edge`";v=`"91`", `"Chromium`";v=`"91`""
            "x-start-time"              = "1623340536521"
            "origin"                    = "https://config.office.com"
            "sec-fetch-site"            = "cross-site"
            "sec-fetch-mode"            = "cors"
            "sec-fetch-dest"            = "empty"
            "referer"                   = "https://config.office.com/"
            "accept-encoding"           = "gzip, deflate, br"
            "accept-language"           = "en-US,en;q=0.9"
        }

        # Add record to array
        foreach ($user in $report.reports) {
            $record = @{
                "userName"                     = ""
                "userEmail"                    = ""
                "kfmState"                     = ""
                "kfmOptInWithWizardGPOEnabled" = ""
                "kfmSilentOptInGPOEnabled"     = ""
                "kfmFolderCount"               = ""
                "kfmFolders"                   = ""
                "totalErrorCount"              = ""
                "lastUpToDateSyncTimestamp"    = ""
                "reportTimestamp"              = ""
                "oneDriveDeviceId"             = ""
                "deviceName"                   = ""
                "oneDriveVersion"              = ""
                "updateRing"                   = ""
            }
            $record."userName" = $user.userName
            $record."userEmail" = $user.userEmail 
            switch ($user.kfmState) {
        0  { $record."kfmState" = "None" }
        56 { $record."kfmState" = "All" }
        default { $record."kfmState" = $user.kfmState }
        }

            $record."kfmOptInWithWizardGPOEnabled" = $user.kfmOptInWithWizardGPOEnabled
            $record."kfmSilentOptInGPOEnabled" = $user.kfmSilentOptInGPOEnabled
            $record."kfmFolderCount" = $user.kfmFolderCount
            
$Folders = @()

foreach ($Folder in $user.kfmFolders) {

    switch ($Folder) {

        1 { $Folders += "Desktop" }

        2 { $Folders += "Documents" }

        3 { $Folders += "Pictures" }

        default { $Folders += $Folder }

    }
}

$record."kfmFolders" = $Folders -join "; "

            #$record."kfmFolders" = $user.kfmFolders | Out-String
            #$record."totalErrorCount" = $user.totalErrorCount
            
if ($user.totalErrorCount -eq 0) {$ErrorStatus = "Healthy"}else {$ErrorStatus = "Errors"}

            #$record."lastUpToDateSyncTimestamp" = $user.lastUpToDateSyncTimestamp
            
$record."lastUpToDateSyncTimestamp" =([datetime]$user.lastUpToDateSyncTimestamp).ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss")

            #$record."reportTimestamp" = $user.reportTimestamp
            $record."reportTimestamp" =([datetime]$user.reportTimestamp).ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss")
            $record."oneDriveDeviceId" = $user.oneDriveDeviceId
            $record."deviceName" = $user.deviceName
            $record."oneDriveVersion" = $user.oneDriveVersion
            $record."updateRing" = $user.updateRing

            $objRecord = New-Object PSObject -property $record
            $reportarray += $objrecord
        }
    }

    $Results = $reportarray | Select-Object `
    userName,
    userEmail,
    deviceName,
    kfmState,
    kfmOptInWithWizardGPOEnabled,
    kfmSilentOptInGPOEnabled,
    kfmFolderCount,
    kfmFolders,
    totalErrorCount,
    lastUpToDateSyncTimestamp,
    reportTimestamp,
    oneDriveDeviceId,
    oneDriveVersion,
    updateRing

$CsvPath = Join-Path `
    $PSScriptRoot `
    "OneDriveSyncHealth_$(Get-Date -Format yyyyMMdd_HHmmss).csv"

$Results | Export-Csv `
    -Path $CsvPath `
    -NoTypeInformation `
    -Encoding UTF8

Write-Host ""
Write-Host "Devices: $($Results.Count)"
Write-Host "CSV: $CsvPath"
