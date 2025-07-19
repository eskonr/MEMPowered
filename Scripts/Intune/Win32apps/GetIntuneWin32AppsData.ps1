<#
.SYNOPSIS
    Generates detailed list of all win32 apps with their properties including all detection and requirement rules.
.DESCRIPTION
    This script performs the following actions:
    1. Checks for and installs the required Microsoft.Graph.Beta module if needed
    2. Connects to Microsoft Graph with required permissions
    3. Retrieves all Win32 apps from Intune
    4. Extracts comprehensive properties of each application including all detection and requirement rules
    5. Logs all the data into CSV format

.NOTES
    File Name      : GetIntuneWin32Appsdata.ps1
    Author         : Eswar Koneti @eskonr
    Prerequisite   : PowerShell 5.1 or later
    Modules        : Microsoft.Graph.Beta.Devices.CorporateManagement
    Scopes         : DeviceManagementApps.Read.All
#>

#region Initialization
$scriptpath = $MyInvocation.MyCommand.Path
$directory = Split-Path $scriptpath
$date = (Get-Date -Format 'ddMMyyyy')
$csvfile = "$directory\ListofWin32Apps_$date.csv"
$AssignmentIncludeAllUsers="#microsoft.graph.allLicensedUsersAssignmentTarget"    #Target type of assignment that represents an 'All users' inclusion assignment
$AssignmentExclusionTarget="#microsoft.graph.exclusionGroupAssignmentTarget"  #Target type of assignment that represents an exclusion assignment
$AssignmentIncludeAllDevices="FUTURE"    #Target type of assignment that represents an 'All device' inclusion assignment

#endregion

#region Module Check and Installation
$moduleName = "Microsoft.Graph.Beta.Devices.CorporateManagement"

try {
    # Check if module is installed
    if (-not (Get-Module -ListAvailable -Name $moduleName -ErrorAction SilentlyContinue)) {
        Write-Host "Module $moduleName not found. Installing..." -ForegroundColor "Yellow"
        Install-Module -Name $moduleName -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
        Write-Host "Successfully installed $moduleName module" -ForegroundColor "Green"
    }
    Import-Module $moduleName -ErrorAction Stop
} catch {
    Write-Host "Failed to install or import $moduleName module: $_" -ForegroundColor "Red"
    exit 1
}
#endregion

#region Graph Connection
$scopes = @('DeviceManagementApps.Read.All','GroupMember.Read.All')

try {
    Connect-MgGraph -Scopes $scopes -ErrorAction Stop -NoWelcome
    Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor "Green"
} catch {
    Write-Host "Failed to connect to Microsoft Graph: $_" -ForegroundColor "Red"
    exit 1
}
#endregion

# Initialize an array to store the app information
$appInfoList = @()

# Get all Win32 applications
Write-Host "Getting the list of win32 apps. Please wait....."
$apps = Get-MgBetaDeviceAppManagementMobileApp -Filter "isof('microsoft.graph.win32LobApp')" -All -ExpandProperty Assignments  -ErrorAction Stop
Write-Host "Total Win32 apps found: $($apps.Count), extracting the data of each application" -ForegroundColor Cyan

foreach ($app in $apps) {

    #Set initial values
    $Apps=@()

    #What about assignments?
        If ($app.Assignments)
            {
            #This application is assigned.  Lets capture each group that it is assigned to and indicate include / exclude, required / available / uninstall
            $Assignments=""
            foreach ($Assignment in $app.assignments)
                {
                #for each assignment, get the intent (required / available / uninstall)
                $AssignmentIntent=$Assignment.intent
                if ($Assignment.target.AdditionalProperties."@odata.type" -eq $AssignmentExclusionTarget)
                    {
                    #This is an exclusion assignment
                    $AssignmentMode="exclude"
                    $AssignmentGroupName=""
                    }
                elseif ($Assignment.target.AdditionalProperties."@odata.type" -eq $AssignmentIncludeAllUsers)
                    {
                    #This is the all users assignment!
                    $AssignmentMode="include"
                    $AssignmentGroupName="All users"
                    }
                elseif ($Assignment.target.AdditionalProperties."@odata.type" -eq $AssignmentIncludeAllDevices)
                    {
                    #This is the all devices assignment!
                    $AssignmentMode="include"
                    $AssignmentGroupName="All devices"
                    }
                else
                    {
                    #This is an inclusion assignment
                    $AssignmentMode="include"
                    $AssignmentGroupName=""
                    }
                #Get the name corresponding to the assignment groupID (objectID in Azure)
                if ($AssignmentGroupName -eq "")
                    {
                    $AssignmentGroupID=$($Assignment.target.AdditionalProperties."groupId")   #"groupId" is case sensitive!
                    if ($null -ne $AssignmentGroupID)
                        {
                        <#
                        Permissions required as per: https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.groups/get-mggroup?view=graph-powershell-1.0
                        GroupMember.Read.All
                        #>
                        try
                            {
                            $AssignmentGroupName=$(Get-MgGroup -GroupId $AssignmentGroupID -ErrorAction Stop).displayName
                            #If here, the group assignment on the app is still valid
                            }
                        catch
                            {
                            #If here, the group assignment on the app is invalid (the group no longer exists)
                            Write-Host "Group ID $($AssignmentGroupID) on app $($Title) no longer exists!"
                            $AssignmentGroupName=$AssignmentGroupID + "_NOTEXIST"
                            }
                        }
                    else
                        {
                        #if we cannot search for it
                        $AssignmentGroupName="UNKNOWN"
                        }
                    }
                #Save the assignment info
                If ($Assignments -eq "")
                    {
                    #First assignment for this app
                    $Assignments="$AssignmentIntent / $AssignmentMode / " + $AssignmentGroupName
                    }
                else
                    {
                    #additional assignment for this app
                    $Assignments=$Assignments + "`n" + "$AssignmentIntent / $AssignmentMode / " + $AssignmentGroupName
                    }
                }
            }
        else
            {
            #This application isn't assigned
            $Assignments="NONE"
            }

# Process detection rules
# Process detection rules
$detectionRules = @()
$detectionDetails = @()

if ($null -ne $app.AdditionalProperties.detectionRules) {
    foreach ($rule in $app.AdditionalProperties.detectionRules) {
        switch ($rule.'@odata.type') {
            "#microsoft.graph.win32LobAppProductCodeDetection" {
                $detectionRules += "MSI"
                $detectionDetails += "MSI ProductCode: $($rule.productCode)"
            }
            "#microsoft.graph.win32LobAppRegistryDetection" {
                $detectionRules += "Registry"
                $detectionDetails += "Registry: $($rule.keyPath)\$($rule.valueName) | Type: $($rule.detectionType)"
            }
            "#microsoft.graph.win32LobAppFileSystemDetection" {
                $detectionRules += "FileSystem"
                $detectionDetails += "FileSystem: $($rule.path)\$($rule.fileOrFolderName) | Type: $($rule.detectionType)"
            }
            "#microsoft.graph.win32LobAppPowerShellScriptDetection" {
                $detectionRules += "Script"
                $detectionDetails += "Script: $($rule.scriptContent)"
            }
            default {
                $detectionRules += "Unknown"
                $detectionDetails += "Unknown rule type: $($rule.'@odata.type')"
            }
        }
    }
}

# Convert to strings for CSV output
$detectionRulesString = $detectionRules -join ", "
$detectionDetailsString = $detectionDetails -join " | "

    # Process requirement rules
    $requirementRules = @()
    $requirementDetails = @()
    $requirementRuleScript = "NONE"

    if ($null -ne $app.AdditionalProperties.requirementRules) {
        foreach ($rule in $app.AdditionalProperties.requirementRules) {
            $ruleType = switch ($rule.'@odata.type') {
                "#microsoft.graph.win32LobAppPowerShellScriptRequirement" {
                    $requirementDetails += "Script: $($rule.displayName)"
                    "Script"
                    break
                }
                "#microsoft.graph.win32LobAppRegistryRequirement" {
                    $requirementDetails += "Registry: $($rule.keyPath)\$($rule.valueName)"
                    "Registry"
                    break
                }
                "#microsoft.graph.win32LobAppFileSystemRequirement" {
                    $requirementDetails += "FileSystem: $($rule.path)\$($rule.fileOrFolderName)"
                    "FileSystem"
                    break
                }
                "#microsoft.graph.win32LobAppProductCodeRequirement" {
                    $requirementDetails += "MSI"
                    "MSI"
                    break
                }
                default { "Unknown"; break }
            }
            $requirementRules += $ruleType
        }
    }

    $requirementRulesString = $requirementRules -join ", "
    $requirementDetailsString = $requirementDetails -join " | "

    # Check dependencies
    $HasDependencies = if ($app.dependentAppCount -gt 0) { "Yes" } else { "No" }

    # Add the app information to the list
    $appInfoList += [PSCustomObject]@{
        displayName            = $app.DisplayName
        displayVersion         = $app.AdditionalProperties.displayVersion
        description           = $app.description
        publisher             = $app.publisher
        setupFilePath         = $app.AdditionalProperties.setupFilePath
        installCommandLine    = $app.AdditionalProperties.installCommandLine
        uninstallCommandLine  = $app.AdditionalProperties.uninstallCommandLine
        allowedArchitectures=$app.AdditionalProperties.allowedArchitectures
        detectionRules        = $detectionRulesString
        detectionDetails      = $detectionDetailsString
        requirementRules      = $requirementRulesString
        requirementDetails    = $requirementDetailsString
        hasDependencies       = $HasDependencies
        createdDateTime       = (([datetime]$app.createdDateTime).ToLocalTime()).ToString("MM/dd/yyyy HH:mm:ss")
        lastModifiedDateTime  = (([datetime]$app.lastModifiedDateTime).ToLocalTime()).ToString("MM/dd/yyyy HH:mm:ss")
        owner                 = $app.owner
        developer             = $app.developer
        notes                 = $app.notes
        uploadState           = $app.uploadState
        publishingState       = $app.publishingState
        isAssigned            = $app.isAssigned
        Assignments           = $Assignments
        Appid                 = $app.id

    }
}

# Export the app information to a CSV file
$appInfoList | Export-Csv -Path $csvfile -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "Script completed, Log file created at '$csvfile'" -ForegroundColor 'Green'
Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
Write-Host ""