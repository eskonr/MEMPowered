# Connect to Microsoft Graph
Connect-MgGraph #-Scopes "DeviceManagementApps.Read.All"

$scriptpath = $MyInvocation.MyCommand.Path
$directory = Split-Path $scriptpath
$date = (Get-Date -Format 'ddMMyyyy-HHmmss')
$csvfile="$dir\ListofWin32Apps_$date.csv"

# Initialize an array to store the app information
$appInfoList = @()

# Get all Win32 applications
$apps = Get-MgBetaDeviceAppManagementMobileApp -MobileAppId "ace6ef60-529f-4bad-a050-2f6932748c8a" #-Filter "microsoft.graph.win32LobApp"

foreach ($app in $apps) {
    
    $detectionRuleType = "Unknown"
    $detectionrule=$app.AdditionalProperties.detectionRules

    # Check detection rules
    if ($null -ne $detectionrule) {
        foreach ($rule in $detectionrule) {
            switch ($rule.'@odata.type') {
                "#microsoft.graph.win32LobAppProductCodeDetection" {
                    $detectionRuleType = "MSI"
                }
                "#microsoft.graph.win32LobAppRegistryDetection" {
                    $detectionRuleType = "Registry"
                }
                "#microsoft.graph.win32LobAppFileSystemDetection" {
                    $detectionRuleType = "fileOrFolderName"
                }
                "#microsoft.graph.win32LobAppPowerShellScriptDetection" {
                    $detectionRuleType = "Script"
                }
                default {
                    $detectionRuleType = "Unknown"
                }
            }
        }
    }
    $RequirementRuleScript="NONE"
      foreach ($rule in $app.AdditionalProperties.requirementRules)
        {
        If ($rule."@odata.type" -ieq "#microsoft.graph.win32LobAppPowerShellScriptRequirement")
            {
            
            if ($RequirementRuleScript -eq "NONE")
                {
            $RequirementRuleScript=$rule.displayName
                }
            else
                {
            #if more than one script requirement rules
                $RequirementRuleScript=$RequirementRuleScript + "`n" + $rule.displayName
                }
            }
        else
            {
            
            }
        }

    #Check if any dependencies?
    if ($app.dependentAppCount -gt 0)
        {
        $HasDependencies="Yes"
        }
    else
        {
        $HasDependencies="No"
        }
        
    # Add the app information to the list
    $appInfoList += [PSCustomObject]@{
        displayName=$app.DisplayName;
        displayVersion=$app.AdditionalProperties.displayVersion;
        description=$app.description;
        publisher=$app.publisher;
        setupFilePath=$app.AdditionalProperties.setupFilePath;
        installCommandLine=$app.AdditionalProperties.installCommandLine;
        uninstallCommandLine=$app.AdditionalProperties.uninstallCommandLine;
        requirementRulesScript=$RequirementRuleScript;
        detectionRuletype=$detectionRuleType;
        hasDependencies=$HasDependencies;
        createdDateTime=(([datetime]$app.createdDateTime).ToLocalTime()).ToString("MM/dd/yyyy HH:mm:ss");              #createdDateTime is a string that converts to UTC time, so converted to local time, then needs reformatting
        lastModifiedDateTime=(([datetime]$app.lastModifiedDateTime).ToLocalTime()).ToString("MM/dd/yyyy HH:mm:ss");    #lastModifiedDateTime is a string that converts to UTC time, so converted to local time, then needs reformatting
        owner=$app.owner;
        developer=$app.developer;
        notes=$app.notes;
        uploadState=$app.uploadState;
        publishingState=$app.publishingState;
        isAssigned=$app.isAssigned;
        id=$app.id;
        }
    }


# Export the app information to a CSV file
$appInfoList | Export-Csv -Path $csvfile -NoTypeInformation

# Disconnect from Microsoft Graph
#Disconnect-MgGraph