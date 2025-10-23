<#
.SYNOPSIS
   Export members of an Azure AD/Entra ID group to CSV format.
.DESCRIPTION
   This script exports all members of a specified Azure AD/Entra ID group, including direct and transitive members, to a CSV file.
   The script requires delegated permissions to Microsoft Graph for group membership access.
.AUTHOR
   Eswar Koneti (@eskonr)
.DATE
   15-May-2024
#>

# Get script directory
$directory = Split-Path -Path $MyInvocation.MyCommand.Path

# Get current date for file naming
$date = Get-Date -Format 'dd-MM-yyyy-HHmmss'

# Output file paths
$outputFile = "$directory\ObjectIDinfo.csv"
$logFile = "$directory\add-devices-aad.log"

# Ensure Microsoft.Graph.Groups module is installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Groups)) {
    Write-Host "Microsoft.Graph.Groups module not installed, installing..." -ForegroundColor Red
    Install-Module -Name Microsoft.Graph.Groups -Force -Scope CurrentUser
}

# Connect to Microsoft Graph
$EntraIDConnected = $false
try {
    Connect-MgGraph -Scopes 'Group.Read.All' -ErrorAction Stop
    $EntraIDConnected = $true
} catch {
    Write-Host "Unable to connect to Entra ID services." -ForegroundColor Red
    exit
}

# Proceed if connected to Entra ID
if ($EntraIDConnected) {
    Write-Host "Enter Entra ID Group Name to export members: " -ForegroundColor Yellow
    $groupName = Read-Host

    # Find the group by name
    $group = Get-MgGroup -Filter "DisplayName eq '$GroupName'" | Select-Object -First 1
    if (-not $group) {
        Write-Host "Group '$groupName' not found. Exiting..." -ForegroundColor Red
        exit
    }

    Write-Host "Group '$groupName' found. Exporting members..." -ForegroundColor Green

    # Export group members to CSV
    try {
        Get-MgGroupTransitiveMember -GroupId $group.id -All | `
        Select-Object @{Name='DeviceName'; Expression={$_.additionalProperties['displayName']}}, `
                      @{Name='OS'; Expression={$_.additionalProperties['operatingSystem']}}, `
                      @{Name='OSVersion'; Expression={$_.additionalProperties['operatingSystemVersion']}}, `
                      @{Name='CreatedDateTime'; Expression={$_.additionalProperties['createdDateTime']}}, `
                      @{Name='RegistrationDate'; Expression={$_.additionalProperties['registrationDateTime']}}, `
                      @{Name='LastSigninDate'; Expression={$_.additionalProperties['approximateLastSignInDateTime']}}, `
                      @{Name='Enabled'; Expression={$_.additionalProperties['accountEnabled']}}, `
                      @{Name='DeviceId'; Expression={$_.additionalProperties['deviceId']}} | 
        Export-Csv "$directory\$groupName-$date.csv" -NoTypeInformation
        Write-Host "Data exported successfully to a file '$directory\$groupName-$date.csv'." -ForegroundColor Green
    } catch {
        Write-Host "Failed to export members." -ForegroundColor Red
    }
}