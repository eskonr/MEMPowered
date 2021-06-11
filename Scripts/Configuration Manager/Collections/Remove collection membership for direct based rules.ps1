<#
Title: Update membership schedule for collections with direct based rule. Direct rule based collections do not need membership enabled.
Following are the collection membership values for refreshtype
1:No Scheduled Update
2:Full Scheduled Update
4:Incremental Update (Only)
6:Incremental and Full Update Scheduled
Author: Eswar Koneti
Blog:www.eskonr.com
Date:31-12-2018
#>

$scriptPath = $script:MyInvocation.MyCommand.Path
$CD = Split-Path $scriptpath
$RefreshTypeto='1' #This is to convert the membership schedule .1 is to remove the schedule.
$date = (get-date -f dd-MM-yyyy-hhmmss) #Get the current date and time when script runs
$collectionsfound="$CD\collections with direct rules-"+$date+".csv" #This is our output file to pipe all collections with direct based rules for our reference later.

$ErrorActionPreference= 'silentlycontinue' 

#Load SCCM module and map the powershell drive
Try
{
  import-module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1) #Import the powershell module . Make sure you have SCCM console installed on the PC that you run the script .
  $SiteCode=Get-PSDrive -PSProvider CMSITE #Get the sitecode 
  cd ((Get-PSDrive -PSProvider CMSite).Name + ':')
}
Catch
{
  Write-Host "[ERROR]`t SCCM Module couldn't be loaded. Script will stop!"
  Exit 1
}
 #Get all collections with membership enabled and direct membership rule only and export the collection details to CSV file for reference
get-CMcollection | where-object {$_.RefreshType -in ('2','4','6') -and ($_.Properties.CollectionRules.SmsProviderObjectPath -eq "SMS_CollectionRuleDirect")} `
|  select collectionID,Name | Export-CSV -NoTypeInformation $collectionsfound -append 

foreach ($Coll in Import-Csv $collectionsfound ) #start the for loop for each each collection that found in SCCM and remove the collection membership schedule
{
$Collection = Get-CMCollection -CollectionId $Coll.collectionID
#write-host $Coll.collectionID $Coll.Name
  $Collection.RefreshType = $RefreshTypeto
  $Collection.Put()
}
write-host "Execution of script completed:" -foregroundcolor Yellow




