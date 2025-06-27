<#
.SYNOPSIS
    Removes ARM64 architecture from requirement rules for all Win32 apps in Intune.
.DESCRIPTION
    This script performs the following actions:
    1. Checks for and installs the required Microsoft.Graph.Beta module if needed
    2. Connects to Microsoft Graph with required permissions
    3. Retrieves all Win32 apps from Intune
    4. Checks each app for ARM64 architecture in requirement rules
    5. Removes ARM64 if found while preserving other settings
    6. Logs all actions and results to script location with file named 'RemoveARM64Fromwin32AppsRequirementRules.log'
    7. Provides detailed console output


.NOTES
    File Name      : RemoveARM64Fromwin32AppsRequirementRules.ps1
    Author        : Eswar Koneti @eskonr
    Prerequisite  : PowerShell 5.1 or later
    Modules: Microsoft.Graph.Beta.Devices.CorporateManagement
    Scopes:DeviceManagementApps.ReadWrite.All
    #>

#region Initialization

# Create log directory if it doesn't exist
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$logFile = "$dir\RemoveARM64Fromwin32AppsRequirementRules.log"
if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

# Initialize summary counters
$summary = @{
    TotalApps = 0
    ARM64Found = 0
    ARM64NotFound = 0
    SuccessfullyUpdated = 0
    FailedUpdates = 0
}

# Function to write to log and console
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Color = "White"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp > [$Level] $Message"

    Add-Content -Path $logFile -Value $logMessage
    #Write-Host $Message -ForegroundColor $Color
}

# Start fresh log file

#region Module Check and Installation
$moduleName = "Microsoft.Graph.Beta.Devices.CorporateManagement"

try {
    # Check if module is installed
    if (-not (Get-Module -ListAvailable -Name $moduleName -ErrorAction SilentlyContinue)) {
       write-host "Module $moduleName not found. Installing..." -ForegroundColor "Yellow"

        # Install the module
        Install-Module -Name $moduleName -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
        write-host "Successfully installed $moduleName module" -ForegroundColor "Green"
    }

    # Import the module
    Import-Module $moduleName -ErrorAction Stop
    } catch {
        write-host "Failed to install or import $moduleName module: $_" -ForegroundColor "Red"
    exit 1
}
#endregion

#region Graph Connection
# Required permissions
$scopes = @(
    "DeviceManagementApps.ReadWrite.All"
)

try {
    Connect-MgGraph -Scopes $scopes -ErrorAction Stop -NoWelcome
    Write-host "Successfully connected to Microsoft Graph" -ForegroundColor "Green"
} catch {
    write-host "Failed to connect to Microsoft Graph: $_" -ForegroundColor "Red"
    exit 1
}
#endregion

#region Main Processing
Write-Log -Message "Script Started" -Level 'INFO' -Color 'Cyan'
try {
    Write-host "Retrieving all Win32 apps, please wait..." -ForegroundColor Green
    $win32Apps = Get-MgBetaDeviceAppManagementMobileApp -Filter "isof('microsoft.graph.win32LobApp')" -All -ErrorAction Stop
    $summary.TotalApps = $win32Apps.Count
    #Write-Log -Message "Found $($win32Apps.Count) Win32 apps to process" -Level "INFO" -Color "Green"
} catch {
    Write-host "Failed to retrieve Win32 apps: $_" -ForegroundColor "Red"
    Disconnect-MgGraph
    exit 1
}

# Process each app
foreach ($app in $win32Apps) {
    $appId = $app.Id
    $appName = $app.DisplayName

    try {
        # Get the full app details with all properties
        $fullApp = Get-MgBetaDeviceAppManagementMobileApp -MobileAppId $appId -ErrorAction Stop

        # Check if we have AdditionalProperties
        if (-not $fullApp.AdditionalProperties) {
            $summary.ARM64NotFound++
            continue
        }

        # Create a clean update payload
        $params = @{
            "@odata.type" = "#microsoft.graph.win32LobApp"
            "displayName" = $fullApp.DisplayName
            "publisher" = $fullApp.Publisher
        }

        # Track changes and status
        $arm64Found = $false
        $changesMade = $false
        $statusMessage = "$appName (ID: $appId)"

        # Check allowedArchitectures
        $currentAllowed = $fullApp.AdditionalProperties.allowedArchitectures
        if ($currentAllowed -like "*ARM64*") {
            $arm64Found = $true
            $newAllowed = ($currentAllowed -split ',') | Where-Object { $_ -ne "ARM64" -and $_ -ne "" }
            $params["allowedArchitectures"] = $newAllowed -join ','
            $changesMade = $true
            $statusMessage += " - Found ARM64 in allowedArchitectures"
                    }

        # Check applicableArchitectures
        $currentApplicable = $fullApp.AdditionalProperties.applicableArchitectures
        if ($currentApplicable -like "*ARM64*") {
            $arm64Found = $true
            $newApplicable = ($currentApplicable -split ',') | Where-Object { $_ -ne "ARM64" -and $_ -ne "" }
            $params["applicableArchitectures"] = $newApplicable -join ','
            $changesMade = $true
            $statusMessage += " - Found ARM64 in applicableArchitectures"
                    }

        if (-not $arm64Found) {
            $summary.ARM64NotFound++
            $statusMessage = "$appName (ID: $appId) - No ARM64 found in requirement rules"

            continue
        }

        $summary.ARM64Found++

        if ($changesMade) {
            try {

                Update-MgBetaDeviceAppManagementMobileApp -MobileAppId $appId -BodyParameter $params -ErrorAction Stop

                $summary.SuccessfullyUpdated++
                $statusMessage += " - ARM64 successfully removed"
                Write-Log -Message $statusMessage -Level "SUCCESS" -Color "Green"

                # Add delay between updates to avoid throttling
                Start-Sleep -Seconds 2
            } catch {
                $summary.FailedUpdates++
                $statusMessage += " - Failed to update: $($_.Exception.Message)"
                Write-Log -Message $statusMessage -Level "ERROR" -Color "Red"
                # Log full error details
                $errorDetails = $_.Exception | Format-List -Force | Out-String
            }
        } else {
           # $statusMessage += " - No changes needed (ARM64 found but already correct)"
           # Write-Log -Message $statusMessage -Level "INFO" -Color "DarkGray"
        }
    }
    catch {
        $summary.FailedUpdates++
        $errorMsg = "Error processing app $appName (ID: $appId): $_"
        Write-Log -Message $errorMsg -Level "ERROR" -Color "Red"
        continue
    }
}

# Add summary report to log and console
$summaryMessage = @"
FINAL SUMMARY REPORT
 >Total Win32 Apps Processed: $($summary.TotalApps)
    > Apps with ARM64 detected: $($summary.ARM64Found)
    > Apps without ARM64 detected: $($summary.ARM64NotFound)
    > Successfully updated apps: $($summary.SuccessfullyUpdated)
    > Failed updated apps: $($summary.FailedUpdates)
"@
write-host ""
write-host $summaryMessage
Write-Log -Message $summaryMessage -Level "INFO" -Color "Cyan"
write-host ""
Write-Log -Message "Script completed." -Level "INFO" -Color "Cyan"
Write-host "Script completed, Log file created at '$logFile'" -ForegroundColor 'green'
Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
write-host ""
