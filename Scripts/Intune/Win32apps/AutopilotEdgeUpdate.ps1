# Parameters for update channel and architecture
param (
	[Parameter(Mandatory = $False)]
	[ValidateNotNullorEmpty()]
	[ValidateSet('Stable', 'Beta', 'Canary', 'Dev')]
	[String]
	$UpdateChannel = 'Stable',
	[Parameter(Mandatory = $False)]
	[ValidateNotNullorEmpty()]
	[ValidateSet('x86', 'x64', 'arm64')]
	[String]
	$Architecture = 'x64'
)

# Check if running in a 32-bit PowerShell instance and restart as 64-bit if needed
if ($ENV:PROCESSOR_ARCHITEW6432 -eq 'AMD64') {
	&"$ENV:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -File $PSCOMMANDPATH
	exit
}

# Registry path for results
$Keypath = "HKLM:\Software\eskonr\EdgeUpdateAuto"
$ExitCode = 0

# Determine Edge app GUID based on the update channel
switch ($UpdateChannel) {
	'Stable' { $AppGUID = '{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}' }
	'Beta' { $AppGUID = '{2CD8A007-E189-409D-A2C8-9AF4EF3C72AA}' }
	'Canary' { $AppGUID = '{65C35B14-6C1D-4122-AC46-7148CC9D6497}' }
	'Dev' { $AppGUID = '{0D50BFEC-CD6A-4F9A-964C-C7416E3ACB10}' }
}

# Start logging
Start-Transcript -Append -Path "$env:ProgramData\eskonr\Logs\AutopilotEdgeUpdate.log" | Out-Null

# Retrieve all installed versions of Microsoft Edge for the specified channel
$EdgePackages = Get-AppxPackage -AllUsers -Name "Microsoft.MicrosoftEdge.$UpdateChannel"

if ($EdgePackages) {
	# Sort the versions and select the latest one
	$LatestEdgePackage = $EdgePackages | Sort-Object { [System.Version]$_.Version } -Descending | Select-Object -First 1
	[System.Version]$EdgeVersionOld = [System.Version]$LatestEdgePackage.Version
	Write-Host "Current Microsoft Edge $UpdateChannel version: $EdgeVersionOld"
} else {
	Write-Error "Microsoft Edge $UpdateChannel not installed"
	$ExitCode = 1
}

if ($ExitCode -eq 0) {
	# Get latest Edge version
	$EdgeInfo = Invoke-WebRequest -UseBasicParsing -Uri 'https://edgeupdates.microsoft.com/api/products?view=enterprise'
	[System.Version]$EdgeVersionLatest = ((($EdgeInfo.Content | ConvertFrom-Json) | Where-Object { $_.product -eq $UpdateChannel }).releases | Where-Object { $_.Platform -eq 'Windows' -and $_.architecture -eq $Architecture })[0].productversion

	# Check if update is needed
	if ($EdgeVersionOld -lt $EdgeVersionLatest) {
		# Trigger Edge update
		Start-Process -FilePath 'C:\Program Files (x86)\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe' -ArgumentList "/silent /install appguid=$AppGUID&appname=Microsoft%20Edge&needsadmin=True"
		Start-Sleep -Seconds 60

		# Wait for update to complete
		[System.Version]$EdgeVersionNew = (Get-AppxPackage -AllUsers -Name "Microsoft.MicrosoftEdge.$UpdateChannel").Version
		while ($EdgeVersionNew -lt $EdgeVersionLatest) {
			Start-Sleep -Seconds 15
			$EdgeVersionNew = (Get-AppxPackage -AllUsers -Name "Microsoft.MicrosoftEdge.$UpdateChannel").Version
		}
	}
}

# Record result in registry
$NOW = Get-Date -Format 'yyyyMMdd-hhmmss'
$PropertyName = if ($ExitCode -eq 0) { 'Success' } else { 'Failure' }
$PropertyValue = $NOW

# Create the registry key if it doesn't exist
if (-not (Test-Path $KeyPath)) {
	New-Item -Path $KeyPath -Force | Out-Null
}


# Create or update the registry key value
New-ItemProperty -Path $Keypath -Name $PropertyName -Value $PropertyValue -PropertyType String -Force | Out-Null
# Stop logging
Stop-Transcript

# Exit script
exit $ExitCode