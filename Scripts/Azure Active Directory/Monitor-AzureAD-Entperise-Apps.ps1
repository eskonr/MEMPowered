<# 
Store the Password into secure file (.key)
Run the following single line (4) manually to store your password. This is onetime only.
Read-Host -Prompt "Enter your tenant password" -AsSecureString | ConvertFrom-SecureString | Out-File "C:\Users\eswarkoneti\Documents\Scripts\o365.key"
#>
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
#Get the current date
$date = (get-date -f dd-MM-yyyy-hhmmss)
#Store the outputfile
$file="$dir\ListAzureADApps-$date.csv"
#Email to be sent from
$From="NewAADApps@eskonr"
$To="Sec1@eskonr.com","sec1@eskonr.com"
$Subject="New Azure AD apps added by Microsoft"
$Body="Hi,
Please find the list of newly added Microsoft apps in Azure Active Directory.

Thanks,
AAD Team
"
 $UserName = "eswarkoneti@eskonr.com"
 #change the key file path that you saved in the line 4
 $Pass= cat "C:\Users\eswarkoneti\Documents\Scripts\o365.key" | ConvertTo-SecureString
 $Credentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $UserName, $Pass

$AadModule = Get-Module -Name "AzureAD" #-ListAvailable
if ($AadModule -eq $null) 
{
Write-Host "AzureAD PowerShell module not found, looking for AzureADPreview"
$AadModule = Get-Module -Name "AzureADPreview" #-ListAvailable
}
 if ($AadModule -eq $null) {
        write-host
        write-host "AzureAD Powershell module not installed..." -f Red
        write-host "Install by running 'Install-Module AzureAD' or 'Install-Module AzureADPreview' from an elevated PowerShell prompt" -f Yellow
        write-host "Script can't continue..." -f Red
        write-host
        exit
    }
    
    if($AadModule.count -gt 1)
    {
    $Latest_Version = ($AadModule | select version | Sort-Object)[-1]

    $aadModule = $AadModule | ? { $_.version -eq $Latest_Version.version }
    # Checking if there are multiple versions of the same module found
    if($AadModule.count -gt 1){
    $aadModule = $AadModule | select -Unique
    Import-Module $AadModule.name
    }
            }
Import-Module $AadModule.name
Connect-AzureAD -Credential $TenantCredentials
Get-AzureADServicePrincipal -All:$true | Where-Object {$_.PublisherName -like "*Microsoft*"}|
Select-Object DisplayName, AccountEnabled,ObjectId, AppId, AppOwnerTenantId,AppRoleAssignmentRequired,Homepage,LogoutUrl,PublisherName  |
Export-Csv -path $file -NoTypeInformation -Append
$New = Import-Csv (Get-Item "$dir\ListAzureADApps*.csv" | Sort-Object LastWriteTime -Descending |Select-Object -First 1 -ExpandProperty name)
$Old = Import-Csv (Get-Item "$dir\ListAzureADApps*.csv" | Sort-Object LastWriteTime -Descending |Select-Object -Skip 1 -First 1 -ExpandProperty name)
$AppsInBoth = Compare-Object -ReferenceObject $Old.DisplayName -DifferenceObject $New.DisplayName -IncludeEqual |
Where-Object {$_.SideIndicator -eq "=>"} |
Select-Object -ExpandProperty InputObject 
$results = ForEach($App in $AppsInBoth) {
    $o = $Old | Where-Object {$_.DisplayName -eq $App}
    $n = $new | Where-Object {$_.DisplayName -eq $app}
    New-Object -TypeName psobject -Property @{
        "DisplayName" = $app
        "AccountEnabled"=$n.AccountEnabled
        "ObjectId"=$n.ObjectID
        "AppId"=$n.AppId
        "AppOwnerTenantId"=$n.AppOwnerTenantId
        "AppRoleAssignmentRequired"=$n.AppRoleAssignmentRequired
        "Homepage"=$n.Homepage
        "LogoutUrl"=$n.LogoutUrl
        "PublisherName"=$n.PublisherName
  }
}
If ($results)
{
$results | select displayname,AccountEnabled,ObjectId,AppId,AppOwnerTenantId,AppRoleAssignmentRequired,Homepage,LogoutUrl,PublisherName `
| Export-CSV -Path "$dir\NewAzureADApps-$date.csv" -NoTypeInformation -Append

$NewApps=(Get-Item "$dir\NewAzureADApps*.csv" | Sort-Object LastWriteTime -Descending|Select-Object -First 1 -ExpandProperty name)
Send-MailMessage -From $From -To $To -SmtpServer "outlook.office365.com" -Subject $Subject -Body $Body -Attachments "$dir\$NewApps"
}
