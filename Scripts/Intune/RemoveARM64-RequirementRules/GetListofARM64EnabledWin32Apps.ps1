<#
.SYNOPSIS
    Get list of Win32 Apps with ARM64 requirement rules in Intune
.DESCRIPTION
    This script performs the following actions:
    1. Checks for and installs the required Microsoft.Graph.Beta module if needed
    2. Connects to Microsoft Graph with required permissions
    3. Retrieves all Win32 apps from Intune
    4. Checks each app for ARM64 architecture in requirement rules
    5. Provides a comprehensive summary report

.NOTES
    File Name      : GetListofARM64enabledWin32Apps.ps1
    Author        : Eswar Koneti
    Prerequisite  : PowerShell 5.1 or later
    Modules: Microsoft.Graph.Beta.Devices.CorporateManagement
    Scopes:DeviceManagementApps.Read.All
#>

#region Initialization

# Create log directory if it doesn't exist
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$logFile = "$dir\ListOfAMR64Win32Apps.log"
if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath -Force | Out-Null
}

# Initialize summary counters
$summary = @{
    TotalApps = 0
    ARM64Found = 0
    ARM64NotFound = 0
    ARM64EnabledApps = @()
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
    Import-Module $moduleName -MinimumVersion $moduleRequiredVersion -ErrorAction Stop
} catch {
    write-host "Failed to install or import $moduleName module: $_" -ForegroundColor "Red"
    exit 1
}
#endregion

#region Graph Connection
# Required permissions
$scopes = @(
    "DeviceManagementApps.Read.All"
)

try {
    Connect-MgGraph -Scopes $scopes -ErrorAction Stop -NoWelcome
    Write-host "Successfully connected to Microsoft Graph" -ForegroundColor "Green"
} catch {
    write-host  "Failed to connect to Microsoft Graph: $_" -ForegroundColor "Red"
    exit 1
}
#endregion

Write-Log -Message "Script started." -Level "INFO" -Color "Cyan"

#region Main Processing
Write-host "Processing Win32 applications for ARM64 enabled applications, please wait...." -ForegroundColor Cyan
try {
    $win32Apps = Get-MgBetaDeviceAppManagementMobileApp -Filter "isof('microsoft.graph.win32LobApp')" -All -ErrorAction Stop
    $summary.TotalApps = $win32Apps.Count
    } catch {
    Write-host "Failed to retrieve Win32 apps: $_" -Color "Red"
    Disconnect-MgGraph
    exit 1
}


foreach ($app in $win32Apps) {
    $appId = $app.Id
    $appName = $app.DisplayName
    
    try {
        $fullApp = Get-MgBetaDeviceAppManagementMobileApp -MobileAppId $appId -ErrorAction Stop
        
        if (-not $fullApp.AdditionalProperties) {
            $summary.ARM64NotFound++
            continue
        }
        
        $params = @{
            "@odata.type" = "#microsoft.graph.win32LobApp"
            "displayName" = $fullApp.DisplayName
            "publisher" = $fullApp.Publisher
        }
        
        $arm64Found = $false
        $statusMessage = "$appName (ID: $appId)"
        
        # Check allowedArchitectures
        $currentAllowed = $fullApp.AdditionalProperties.allowedArchitectures
        if ($currentAllowed -like "*ARM64*") {
            $arm64Found = $true
            $newAllowed = ($currentAllowed -split ',') | Where-Object { $_ -ne "ARM64" -and $_ -ne "" }
            $params["allowedArchitectures"] = $newAllowed -join ','
            $statusMessage += " - Found ARM64 in allowedArchitectures"
        }
        
        # Check applicableArchitectures
        $currentApplicable = $fullApp.AdditionalProperties.applicableArchitectures
        if ($currentApplicable -like "*ARM64*") {
            $arm64Found = $true
            }
        
        if (-not $arm64Found) {
            $summary.ARM64NotFound++
            continue
        }
                if ($arm64Found) {
            $summary.ARM64EnabledApps += "$appName (ID: $appId)"
           $archInfo = $archDetails -join ", "
         
        }
        
        $summary.ARM64Found++
        
    }
    catch {
        $summary.FailedUpdates++
        Write-Log -Message "Error processing app $appName (ID: $appId): $_" -Level "ERROR" -Color "Red"
        continue
    }
}

# Add summary report to log and console
$summaryMessage = @"
Summary of Win32 Apps for ARM64
 > Total Win32 Apps detected: $($summary.TotalApps)
  > Apps with ARM64-enabled detected: $($summary.ARM64EnabledApps.Count)
  > Apps without ARM64 detected: $($summary.ARM64NotFound)

LIST OF ARM64-ENABLED APPLICATIONS
$($summary.ARM64EnabledApps -join "`n")
"@
write-host ""
Write-Host $summaryMessage
Write-Log -Message $summaryMessage -Level "INFO" -Color "Cyan"


Write-Log -Message "Script completed." -Level "INFO" -Color "Cyan"
write-host ""
Write-host "Script completed, please see results at '$logFile'" -ForegroundColor Green

Disconnect-MgGraph -ErrorAction SilentlyContinue