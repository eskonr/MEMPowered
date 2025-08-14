<#
.SYNOPSIS
    Event logging Script for intune remediations
.DESCRIPTION
    This script performs is template to be used for tasks via Microsoft Intune and logs detailed execution
    information to Windows Event Viewer. It tracks:
    - Script execution start/stop times
    - Success/failure status
    - Execution duration
    - Error details (when failures occur)

    Events are logged under a custom source that includes the script name for easy filtering.
.PARAMETER None
    This script currently doesn't accept parameters
.OUTPUTS
    Logs entries to Windows Event Viewer (Application log)
    Returns nothing to the pipeline
.NOTES
    FileName:    TemplateforIntuneRemediationEventLogging
    Author:      Eswar Koneti
    Created:     14-Aug-2025
    Version:     1.0
    Requires:    PowerShell 5.1 or later
    Execution:   Deployed via Microsoft Intune as Remediation Script
#>

# Define event viewer log creation
$logName = 'Application'
$ScriptName = 'ScriptName'  # Replace with your actual script name
$sourceName = "IntuneRemediationScript-$ScriptName"  # Use double quotes for variable expansion
$eventID = 1

# Create the event source if it doesn't exist
if (-not [System.Diagnostics.EventLog]::SourceExists($sourceName)) {
	[System.Diagnostics.EventLog]::CreateEventSource($sourceName, $logName)
}

# Function to write to event log
function Write-EventLogEntry {
	param (
		[string]$message,
		[ValidateSet('Information', 'Warning', 'Error')]
		[string]$entryType = 'Information',
		[int]$eventId = $eventID
	)

	try {
		Write-EventLog -LogName $logName -Source $sourceName -EventId $eventId -EntryType $entryType -Message $message -Category 0
		return $true
	} catch {
		Write-Output "Failed to write to event log: $_"
		return $false
	}
}

# Capture start time at the beginning of script execution
$startTime = Get-Date

try {
	# Your existing remediation code here
	# ...

	# Example success log
	$executionTime = [math]::Round((New-TimeSpan -Start $startTime -End (Get-Date)).TotalSeconds, 2)
	Write-EventLogEntry -message "$sourceName completed successfully in $executionTime seconds" -entryType 'Information'
} catch {
	# Log errors
	$errorMsg = "$sourceName failed: $($_.Exception.Message)"
	Write-EventLogEntry -message $errorMsg -entryType 'Error' -eventId 1
}