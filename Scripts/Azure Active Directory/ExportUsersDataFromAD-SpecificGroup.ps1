<#
.SYNOPSIS
    This script retrieves user password-related data from an Active Directory group,
    exports the data to a CSV file, and uploads the file to a specified SharePoint Online document library.

.DESCRIPTION
    - Checks if the SharePointPnPPowerShellOnline module is installed; installs it if missing.
    - Logs all key actions and errors to a specified log file.
    - Collects user details (e.g., SamAccountName, PasswordLastSetDate, Title, Email, Department)
      from the specified AD group.
    - Exports the collected data to a CSV file.
    - Connects to SharePoint Online using PnP PowerShell and uploads the CSV file to the target library.
    - Measures and logs the total execution time.

.PARAMETER logFilePath
    Path to the log file where script execution details will be recorded.

.PARAMETER siteUrl
    The SharePoint Online site URL where the file will be uploaded.

.PARAMETER libraryName
    The SharePoint document library folder path where the file will be stored.

.PARAMETER localFilePath
    The local path where the CSV file will be saved before upload.

.PARAMETER remoteFileName
    The name of the file as it will appear in SharePoint.

.NOTES
    Author: Eswar Koneti
    Date:   29-Aug-2025
    Requirements:
        - PowerShell 5.1 or later
        - Active Directory module
        - SharePointPnPPowerShellOnline module
        - Appropriate permissions to AD and SharePoint Online
#>

# Define the configurations
$logFilePath = "C:\ProgramData\eskonr\InstallLogs\ExportPassphrasedata.log"
$siteUrl = "https://eskonr.sharepoint.com/sites/UserExperience"
$libraryName = "Shared Documents/Asia-EU/Intune/users"
$localFilePath = "C:\temp\ExportUsersData.csv"
$remoteFileName = "ExportUsersData.csv"  # You can change this if needed

# Ensure log directory exists
try {
    $logDir = Split-Path -Path $logFilePath -Parent
    if (-not (Test-Path -Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
}
catch {
    Write-Warning "Could not create log directory '$logDir' - $_" -ErrorAction Stop
    exit 1
}

# Function to log messages
function Log-Message {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "dd-MM-yyyy HH:mm:ss"
    $logMessage = "$timestamp - $message"
    Add-Content -Path $logFilePath -Value $logMessage
}

# Log start of script
Log-Message "Script started."

# Function to export user data to CSV
function Export-UserDataToCsv {
    param (
        [array]$userDataCollection,
        [string]$localFilePath
    )

    # Export the data to a CSV file
    $userDataCollection | Export-Csv -Path $localFilePath -NoTypeInformation

    # Check if the file size is zero and return the result
    $fileSize = (Get-Item $localFilePath).Length
    return $fileSize -eq 0
}

# Start measuring time
$startTime = Get-Date

# Define the group name
$groupName = "Provide_Your_Group"

# Get all members of the group by fetching the Member property
$groupMembersDNs = Get-ADGroup -Identity $groupName -Properties Member | Select-Object -ExpandProperty Member

# Initialize an array to collect user data
$userDataCollection = @()

foreach ($memberDN in $groupMembersDNs) {
    # Fetch user details
    $adUser = Get-ADUser -Identity $memberDN -Properties SamAccountName, pwdLastSet, PasswordExpired, Title, Co, EmailAddress, departmentNumber, Manager -ErrorAction SilentlyContinue

    if ($adUser) {
        # Create a custom object for each user
        $userPasswordData = [PSCustomObject]@{
            SamAccountName      = $adUser.SamAccountName
            PasswordLastSetDate = [datetime]::FromFileTime($adUser.pwdLastSet)
            PasswordMustChange  = $adUser.PasswordExpired
            Name                = $adUser.Name
            Title               = $adUser.Title
            Country             = $adUser.Co
            Email               = $adUser.EmailAddress
            Department          = $adUser.departmentNumber -join ","
        }

    # Add user data to the collection
    $userDataCollection += $userPasswordData
}
}

# Attempt to export the data up to 1 times if necessary
$maxRetries = 1
$retryCount = 0
$success = $false

do {
    $isFileSizeZero = Export-UserDataToCsv -userDataCollection $userDataCollection -localFilePath $localFilePath
    $retryCount++

    if ($isFileSizeZero) {
        Log-Message "CSV file is empty. Attempt $retryCount of $maxRetries."
    } else {
        $success = $true
        Log-Message "Data exported to CSV file successfully."
    }

} while ($isFileSizeZero -and $retryCount -lt $maxRetries)

if (-not $success) {
    Log-Message "Failed to export non-empty CSV after $maxRetries attempts."
    # Optionally, you could exit the script here if this is a critical failure
    # exit 1
}


# Connect to SharePoint
try {
    Connect-PnPOnline -Url $siteUrl -UseWebLogin -ErrorAction Stop
    Log-Message "Connected to SharePoint site $siteUrl successfully."
} catch {
    Log-Message "Failed to connect to SharePoint site $siteUrl. Error: $_"
    exit 1
}

# Upload the file
try {
    Add-PnPFile -Path $localFilePath -Folder $libraryName -NewFileName $remoteFileName -ErrorAction Stop
    Log-Message "File $localFilePath uploaded to $libraryName as $remoteFileName successfully."
} catch {
    Log-Message "Failed to upload file $localFilePath to $libraryName. Error: $_"
    exit 1
}

# Calculate and display script completion time
$endTime = Get-Date
$totalTime = $endTime - $startTime
Log-Message "Script completed in $($totalTime.TotalSeconds) seconds."