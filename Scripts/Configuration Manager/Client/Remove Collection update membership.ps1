<#
Title: Update collection membership schedule
Following are the collection membership values for refreshtype
1:No Scheduled Update
2:Full Scheduled Update
4:Incremental Update (Only)
6:Incremental and Full Update Scheduled
Author: Eswar Koneti
Blog:www.eskonr.com
Date:31-12-2018
#>

$scriptPath = $script:MyInvocation.MyCommand.Path #Get the current folder of the script that is located
$CD = Split-Path $scriptpath
$RefreshTypefrom='6' #This is to identify the collections with Incremental and Full Update Scheduled
$RefreshTypeto='2' #This is to convert Incremental and Full Update Scheduled collections to Full Scheduled Update
$date = (get-date -f dd-MM-yyyy-hhmmss)
$exclusions="$CD\ExclusionIDs.txt" #High Priority collections (need your input with list of all collectionID's including device /used based)
$collectionsfound="$CD\collections with inc and full-"+$date+".csv" #Collections that are found with Incremental and Full Update Scheduled membership for your reference later (outfile)
$Outfile = "$CD\collection Membership Update-"+$date+".csv"

$ErrorActionPreference= 'silentlycontinue' 

#Load SCCM module and map the powershell drive
Try
{
  import-module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
  $SiteCode=Get-PSDrive -PSProvider CMSITE
  cd ((Get-PSDrive -PSProvider CMSite).Name + ':')
}
Catch
{
  Write-Host "[ERROR]`t SCCM Module couldn't be loaded. Script will stop!"
  Exit 1
}

#Get the collection ID (HIGH PRIORITY) exclusions that you want to exclude from being removing the collection membership 
 $exc= @()
 foreach ($exc1 in get-content $exclusions )
 {
 $exc += $exc1
 }

#Get all device collections that have both incremental and full update schedule but skip from the exclusion of the collection ID's that we imported above using exc variable
Get-CMCollection  | where-object {$_.RefreshType -eq $RefreshTypefrom -and $_.collectionID -notin $exc} | select collectionID,Name | Export-CSV -NoTypeInformation $collectionsfound -append
#import the collection into variable
$CollectionIDs=Import-Csv $collectionsfound | select -ExpandProperty collectionID
Foreach ($CollID in $CollectionIDs)  {
#Get the collection details that we want to change the membership (removal of incremental collection)
           $Collection = Get-CMCollection -CollectionId $CollID
            $Collection.RefreshType = $RefreshTypeto
            $Collection.Put()

}