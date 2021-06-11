#Load Configuration Manager PowerShell Module
Import-module ($Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5) + '\ConfigurationManager.psd1')

#Get SiteCode
$SiteCode = Get-PSDrive -PSProvider CMSITE
Set-location $SiteCode":"

# Import Boundaries from CSV file

$Boundaries = Import-Csv Path "$PSScriptRoot\Boundaries.csv"
foreach($Boundary in $Boundaries)
{
    Write-Output -InputObject "Creating $($Boundary.Name)"
    #Create the Boundary
    New-CMBoundary -Name $Boundary.Name -Type IPRange -Value "$($Boundary.'StartRange')-$($Boundary.'EndRange')" | Out-Null
}