# Import the Active Directory module
Import-Module ActiveDirectory

# Define variables
$date=$(Get-Date -Format 'ddMMyyyy-HHmmss')
$csvPath = "G:\Temp\AD-Device-Cleanup\DeviceCleanupReport-$date.csv"
$fromEmail = "from@domain.com"
$toEmail = "to@domain.com"
$smtpServer = "smtp.office365.com"

#$credential = Get-Credential

# Define the threshold for inactive devices (2 months)
$inactiveThreshold = (Get-Date).AddMonths(-3)

# Create an array to store the results
$results = @()

# Get a list of inactive workstations
$workstations = Get-ADComputer -Filter {OperatingSystem -like "*Windows*" -and OperatingSystem -notlike "*Server*" } -Properties LastLogonDate,OperatingSystem |
    Where-Object { $_.LastLogonDate -lt $inactiveThreshold }

# Iterate through each workstation
foreach ($workstation in $workstations) {
    $deviceName = $workstation.Name
    $lastLogonDate = $workstation.LastLogonDate
    $dn = $workstation.DistinguishedName
    $os = $workstation.OperatingSystem

    # Remove the device from Active Directory
    $status= Remove-ADObject -Identity $dn -Recursive -Confirm:$false
     if ($status) {

        $result = [PSCustomObject]@{
        DeviceName = $deviceName
        OS= $os
        LastLogonDate = $lastLogonDate
        DN = $dn
        Status = "Removed" }

    } else {
        $result = [PSCustomObject]@{
        DeviceName = $deviceName
        OS= $os
        LastLogonDate = $lastLogonDate
        DN = $dn
        Status = "NotRemoved"
        }
    }

 $results += $result
}

# Count the number of successfully removed and failed devices
$successCount = ($results | Where-Object { $_.Status -eq "Removed" }).Count
$failedCount = ($results | Where-Object { $_.Status -eq "NotRemoved" }).Count

# Export the results to a CSV file
$results | Export-Csv -Path $csvPath -NoTypeInformation

# Send an email with the count of status in the subject and attach the output file
$mailParams = @{
    SmtpServer = $smtpServer
    From = $fromEmail
    To = $toEmail
    Subject = "Device Cleanup Report - Success: $successCount, Failed: $failedCount"
    Body = "Hi Team, `r`nPlease find the attached device cleanup report in AD.`r`nThank you. `r`nDo no reply to this email."
    Attachments = $csvPath
    Port= '587' # or '25' if not using TLS
    #UseSSL= $true ## or not if using non-TLS
    #Credential= $credential

}
#Send-MailMessage @mailParams
