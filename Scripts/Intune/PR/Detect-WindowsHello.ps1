function Get-WindowsHelloStatus {
    # Define machine-wide registry paths
    $PinKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\{D6886603-9D2F-4EB2-B667-1971041FA96B}"
    $BioKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WinBio\AccountInfo"

    # Initialize output
    $windowsHelloEnabled = $false

    # Check if the PIN key exists and whether it has relevant values
    if (Test-Path -Path $PinKeyPath) {
        # Check for all user SIDs under the PIN key
        $userSIDs = Get-ChildItem -Path $PinKeyPath
        foreach ($userSID in $userSIDs) {
            $pinValue = Get-ItemProperty -Path $userSID.PSPath -Name "LogonCredsAvailable" -ErrorAction SilentlyContinue
            if ($pinValue.LogonCredsAvailable -eq 1) {
                $windowsHelloEnabled = $true
                break
            }
        }
    }

    # Check if the biometric key exists
    if (Test-Path -Path $BioKeyPath) {
        # Check for all user SIDs under the biometric key
        $userSIDs = Get-ChildItem -Path $BioKeyPath
        foreach ($userSID in $userSIDs) {
            $bioValue = Get-ItemProperty -Path $userSID.PSPath -Name "EnrolledFactors" -ErrorAction SilentlyContinue
            if ($bioValue.EnrolledFactors -ne 0) {
                $windowsHelloEnabled = $true
                break
            }
        }
    }

    # Output result
    if ($windowsHelloEnabled) {
        return "Enabled"
    } else {
        return "Disabled"
    }
}

# Call the function and output the result
Get-WindowsHelloStatus
