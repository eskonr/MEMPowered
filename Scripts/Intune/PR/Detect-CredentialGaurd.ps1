function Get-CredentialGuardStatus {
    $keyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
    $guardEnabled = $false

    if (Test-Path -Path $keyPath) {
        $settings = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue
        if ($settings -and $settings.EnableVirtualizationBasedSecurity -eq 1) {
            $guardEnabled = $true
        }
    }

    if ($guardEnabled) {
        return "Enabled"
    } else {
        return "Disabled"
    }
}

# Call the function and output the result
Get-CredentialGuardStatus