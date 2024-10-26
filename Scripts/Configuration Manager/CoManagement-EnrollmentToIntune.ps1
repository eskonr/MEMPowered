<#
.SYNOPSIS
   Reenrolls a device in Intune and resynchronizes policies by removing specific registry keys related to co-management
   and running the compliance baseline rule for Co-Management settings.

.DESCRIPTION
   This script checks the registry for co-management enrollment details, removes the corresponding registry entries,
   reenrolls the device in Intune, and then triggers an evaluation of the co-management compliance baseline.
   
   - Deletes registry entries associated with co-management if enrolled via Microsoft’s Intune.
   - Initiates the device re-enrollment process using Device Enroller.
   - Pauses briefly to allow for enrollment processing.
   - Runs the co-management compliance baseline rule to ensure proper policy synchronization.

.AUTHOR
   Eswar Koneti
#>

# Define the path for Intune enrollment registry entries
$EnrollmentsPath = "HKLM:\SOFTWARE\Microsoft\Enrollments\"

# Retrieve all items (registry keys) under the Enrollments path
$Enrollments = Get-ChildItem -Path $EnrollmentsPath

# Loop through each enrollment found
Foreach ($Enrollment in $Enrollments) {
    # Get registry properties for the current enrollment
    $EnrollmentObject = Get-ItemProperty Registry::$Enrollment

    # Check if the enrollment is managed by Intune using the specific DiscoveryService URL
    if ($EnrollmentObject."DiscoveryServiceFullURL" -eq "https://enrollment.manage.microsoft.com/enrollmentserver/discovery.svc")
         {
        # Construct the full path to the registry key that needs to be removed
        $EnrollmentPath = $EnrollmentsPath + $EnrollmentObject."PSChildName"

        # Delete the registry key associated with the enrollment
        Remove-Item -Path $EnrollmentPath -Recurse
    }
}

# Reenroll the device in Intune using the Device Enroller command
cmd.exe /c "c:\windows\system32\deviceenroller.exe /c /AutoEnrollMDM"

# Pause for 60 seconds to allow the re-enrollment process to complete
Start-Sleep 60

# Define the name of the co-management compliance baseline to be evaluated
$BLName = "CoMgmtSettingsProd"

# Retrieve the co-management baseline configuration by its display name
$Baselines = Get-WmiObject -Namespace root\ccm\dcm -Class SMS_DesiredConfiguration | Where-Object { $_.DisplayName -like $BLName }

try {
    # Loop through each baseline and trigger an evaluation to apply compliance settings
    $Baselines | ForEach-Object {
        ([wmiclass]"\\root\ccm\dcm:SMS_DesiredConfiguration").TriggerEvaluation($_.Name, $_.Version)
    }
    Write-Host "Successfully ran CoMgmtSettingsProd"  # Confirm success to the user
} catch {
    Write-Host "Failed to run CoMgmtSettingsProd"  # Display failure message if baseline execution fails
}