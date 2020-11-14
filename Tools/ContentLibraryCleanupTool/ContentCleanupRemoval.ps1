<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2017 v5.4.139
	 Created on:   	05/05/2017 15:11
	 Created by:   	Maurice.Daly
	 Filename:     	ContentCleanupRemoval.ps1
	===========================================================================
	.DESCRIPTION
		This script works in conjuction with the content library clean up tool 
		in SCCM CB1702 onwards to automate the function of deleting orphaned 
		content on your distribution ponts

		Use : This script is provided as it and I accept no responsibility for any issues arising from its use.
 
		Twitter : @modaly_it
		Blog : http://www.scconfigmgr.com

#>

function Get-ScriptDirectory
{
	[OutputType([string])]
	param ()
	if ($null -ne $hostinvocation)
	{
		Split-Path $hostinvocation.MyCommand.path
	}
	else
	{
		Split-Path $script:MyInvocation.MyCommand.Path
	}
}

[string]$ScriptDirectory = Get-ScriptDirectory

# Logging Function
function Write-CMLogEntry
{
	param (
		[parameter(Mandatory = $true, HelpMessage = "Value added to the log file.")]
		[ValidateNotNullOrEmpty()]
		[string]$Value,
		[parameter(Mandatory = $true, HelpMessage = "Severity for the log entry. 1 for Informational, 2 for Warning and 3 for Error.")]
		[ValidateNotNullOrEmpty()]
		[ValidateSet("1", "2", "3")]
		[string]$Severity,
		[parameter(Mandatory = $false, HelpMessage = "Name of the log file that the entry will written to.")]
		[ValidateNotNullOrEmpty()]
		[string]$FileName = "ScheduledContentLibraryCleanup-$(Get-Date -Format dd-MM-yyyy).log"
	)
	
	# Determine log file location
	$LogFilePath = Join-Path -Path $ScriptDirectory -ChildPath $FileName
	
	# Construct time stamp for log entry
	$Time = -join @((Get-Date -Format "HH:mm:ss.fff"), "+", (Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias))
	
	# Construct date for log entry
	$Date = (Get-Date -Format "MM-dd-yyyy")
	
	# Construct context for log entry
	$Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
	
	# Construct final log entry
	$LogText = "<![LOG[$($Value)]LOG]!><time=""$($Time)"" date=""$($Date)"" component=""ScheduledContentLibraryCleanup"" context=""$($Context)"" type=""$($Severity)"" thread=""$($PID)"" file="""">"
	
	# Add value to log file
	try
	{
		Add-Content -Value $LogText -LiteralPath $LogFilePath -ErrorAction Stop
	}
	catch [System.Exception] {
		Write-Warning -Message "Unable to append log entry to ScheduledContentLibraryCleanup.log file. Error message: $($_.Exception.Message)"
	}
}


# Import SCCM PowerShell Module
$ModuleName = (Get-Item $env:SMS_ADMIN_UI_PATH).parent.FullName + "\ConfigurationManager.psd1"
Write-CMLogEntry -Value "RUNNING: ConfigMgr PS commandlets path set to $ModuleName" -Severity 1

# Specify SCCM Site Vairables
$SiteServer = %SITESERVER%
Write-CMLogEntry -Value "RUNNING: Site server identified as $SiteServer" -Severity 1
$SiteCode = %SITECODE%
Write-CMLogEntry -Value "RUNNING: SMS site code identified as $SiteCode" -Severity 1


# Define Content Library Path Location
$ContentLibraryExe = ("$($env:SMS_LOG_PATH | Split-Path -Parent)" + "\cd.latest\SMSSETUP\TOOLS\ContentLibraryCleanup\ContentLibraryCleanup.exe")

# Define Arrays
$DistributionPoints = New-Object -TypeName System.Collections.ArrayList

# Import SCCM Module
Import-Module $ModuleName

# Connect to Site Code PS Drive
Set-Location -Path ($SiteCode + ":")

# List Distribution Points
$DistributionPoints = @(((Get-CMDistributionPoint | Select-Object NetworkOSPath).NetworkOSPath).TrimStart("\\"))

# Specify Temp Log Location
$LogDir = ($ScriptDirectory + "\ContentLibraryCleanerLogs")

function CleanContent
{
	param
	(
		[parameter(Mandatory = $true)]
		[String]$DistributionPoint,
		[parameter(Mandatory = $true)]
		[String]$SiteServer,
		[parameter(Mandatory = $true)]
		[String]$SiteCode
	)
	
	try
	{
		Write-CMLogEntry -Value "CLEANING: Setting location to $ScriptDirectory" -Severity 1
		Set-Location -Path $ScriptDirectory
		# Content Library Cleanup switches
		Write-CMLogEntry -Value "CLEANING: Setting execution switches to $ContentCleanupString" -Severity 1
		$ContentCleanupStrings = "/q /ps $SiteServer /dp $DistributionPoint /sc $SiteCode /delete"
		Write-Host "Running process for $DistributionPoint"
		Write-CMLogEntry -Value "CLEANING: Starting clean up process for server $DistributionPoint" -Severity 1
		$RunningProcess = Start-Process -FilePath $ContentLibraryExe -ArgumentList $ContentCleanupStrings -NoNewWindow -RedirectStandardOutput $($LogDir + "\$DistributionPoint-ScheduledDeletionJob.log") -PassThru
		# Wait for Process completion
		While ((Get-Process | Where-Object { $_.Id -eq $RunningProcess.Id }).Id -ne $null)
		{
			Write-CMLogEntry -Value "CLEANING: Waiting for process PID:$($RunningProcess.Id) to finish" -Severity 1
			sleep -Seconds 1
		}
		# Get most recent log file generated
		$ContentCleanUpLog = Get-ChildItem -Path $LogDir -Filter *.log | Where-Object { ($_.Name -match "$DistributionPoint-ScheduledDeletionJob") } | select -First 1
		
		# Exception for reports with active distributions preventing the content rule from estimating space
		if ((Get-Content -Path $ContentCleanUpLog.FullName | Where-Object { $_ -match "This content library cannot be cleaned up right now" }) -ne $null)
		{
			Write-CMLogEntry -Value "CLEANING: $DistributionPoint currently has active transfers. Skipping." -Severity 2
			$RowData = @($DistributionPoint, "N/A - Active Transfers")
		}
		else
		{
			Write-CMLogEntry -Value "CLEANING: Process completed" -Severity 1
		}
		
	}
	catch [System.Exception] {
		Write-CMLogEntry -Value "ERROR: $($_.Exception.Message)" -Severity 3
		Write-Warning -Message "ERROR: $($_.Exception.Message)"
	}
	Write-CMLogEntry -Value "Finished: Job Complete" -Severity 1
}

foreach ($DistributionPoint in $DistributionPoints)
{
	Write-CMLogEntry -Value "RUNNING: Starting clean up process for server $DistributionPoint" -Severity 1
	CleanContent $DistributionPoint $SiteServer $SiteCode
}

# // ------------- Clean Up Log Files ----------- // #

# Define Maximum Log File Age
$MaxLogAge = 30
# Remove Logs
Write-CMLogEntry -Value "CLEANING: Removing log files older than $MaxLogAge days old" -Severity 2
Get-ChildItem -Path $ScriptDirectory -Filter "ScheduledContentLibrary*.log" -File | Where-Object {$_.LastWriteTime -lt ((Get-Date).AddDays(-$MaxLogAge))} | Remove-Item
