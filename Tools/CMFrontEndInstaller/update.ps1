Write-Host "-----------------------------"
Write-Host "ConfigMgr Frontend Updater"
Write-Host "Scott Keiffer, 2016"
Write-Host "-----------------------------"

$ErrorActionPreference = "Stop"
$scriptPath=Split-Path -parent $MyInvocation.MyCommand.Definition

Write-Host "Stopping Services..."
Stop-Service "CMFrontEndBkg" | Out-Null
Stop-Service "W3SVC" | Out-Null
sleep 10


write-host "gathering data from existing web.config"
if (!(Test-Path "$env:SystemDrive\inetpub\wwwroot\Web.config"))
{
    write-error "Could not find web.config."
}
[xml]$OrigWebConfig = Get-Content "$env:SystemDrive\inetpub\wwwroot\Web.config"
$ADConnectionString = $null
$ADRPConnectionString = $null
for ($i = 0; $i -lt $OrigWebConfig.configuration.connectionStrings.add.count; $i++) 
{
    $currConnectionString = $OrigWebConfig.configuration.connectionStrings.add[$i]
    if ($currConnectionString.name -eq "ADConnectionString") 
    {
        $ADConnectionString = $currConnectionString.connectionString
    }
    if ($currConnectionString.name -eq "ADRPConnectionString") 
    {
        $ADRPConnectionString = $currConnectionString.connectionString
    }
}

if ($ADRPConnectionString -eq $null -or $ADConnectionString -eq $null) 
{
    Write-Warning "Could not find AD connection strings in existing web.config. ADConnectionString and ADRPConnectionString in the web.config file will need to be corrected manually."
}

Write-Host "Copying files..."
Remove-Item "${env:ProgramFiles(x86)}\CMFrontEnd\*" -recurse
Remove-Item "$env:SystemDrive\inetpub\wwwroot\*" -recurse
Copy-Item -Path "$scriptPath\Service\*" -Destination "${env:ProgramFiles(x86)}\CMFrontEnd\" -Recurse -Force | Out-Null
Copy-Item -Path "$scriptPath\Web\*" -Destination "$env:SystemDrive\inetpub\wwwroot\" -Recurse -Force | Out-Null

if ($ADRPConnectionString -ne $null -and $ADConnectionString -ne $null) 
{
    Write-Host "Saving configuration changes to new web.config"
    [xml]$NewWebConfig = Get-Content "$env:SystemDrive\inetpub\wwwroot\Web.config"
    for ($i = 0; $i -lt $NewWebConfig.configuration.connectionStrings.add.count; $i++) 
    {
        $currConnectionString = $NewWebConfig.configuration.connectionStrings.add[$i]
        if ($currConnectionString.name -eq "ADConnectionString") 
        {
            $currConnectionString.connectionString = $ADConnectionString
        }
        if ($currConnectionString.name -eq "ADRPConnectionString") 
        {
            $currConnectionString.connectionString = $ADRPConnectionString
        }
    }
    $NewWebConfig.Save("$env:SystemDrive\inetpub\wwwroot\Web.config")
}


Write-Host "Starting Services..."
Start-Service "W3SVC" | Out-Null
Start-Service "CMFrontEndBkg" | Out-Null

Write-Host -ForegroundColor Green "Update complete!"