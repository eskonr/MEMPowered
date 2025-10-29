# Check if winget is available
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "Winget is already installed." -ForegroundColor Green
} else {
    Write-Host "Winget not found. Attempting to register DesktopAppInstaller..." -ForegroundColor Yellow
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
        # Verify again
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "Winget registration successful." -ForegroundColor Green
        } else {
            Write-Host "Winget registration failed." -ForegroundColor Red
        }
    } catch {
        Write-Host "Error during registration: $_" -ForegroundColor Red
    }
}