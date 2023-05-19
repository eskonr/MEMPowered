#Ref:https://2pintsoftware.com/news/details/delivery-optimization-internals-%E2%80%93-get-win32-app-download-info
# Optional: Get App information from Intune (requires the Microsoft.Graph.Intune module to be installed)
#Install-Module Microsoft.Graph.Intune
#Connect-MSGraph -ForceInteractive
#$AppSearch = "100 MB Single File" # Search is wildcard (contains)
#$App = Get-DeviceAppManagement_MobileApps -Filter "contains(displayName, '$AppSearch')"
#$AppName = $App.displayName
#$AppId = $App.id
 
# Select what application to search for
$AppName = "P2P Test Application - 100 MB Single File"
$AppId = "956e00ed-3da5-4e87-aaa7-ec7a0f06ef41"
 
# Get download metrics from the Get-DeliveryOptimizationStatus cmdlet (filter for the selected app only)
$DOStatusOutPut = Get-DeliveryOptimizationStatus
$DOStatusData = $DOStatusOutPut | Where-Object { `
  ($_.FileId -match "intunewin-bin_$($AppId)_1") `
  -and ($_.Status -in "Complete","Caching") `
  -and ($_.PredefinedCallerApplication -eq "IntuneAppDownload") }
 
If ($DOStatusData){
Foreach ($Status in $DOStatusData){
  Write-host "Writing some interesting metrics to the console"
  Write-host "Application name: $($AppName)"
  Write-host "Application size (FileSize): $($Status.FileSize)"
  Write-host "Total bytes downloaded from DO status data: $($Status.TotalBytesDownloaded)"
  Write-host "Download priority mode: $($Status.Priority)"
  Write-Host "Downloaded bytes from Internet (BytesFromHttp): $($Status.BytesFromHttp)"
  Write-Host "Downloaded bytes from peers (BytesFromPeers): $($Status.BytesFromPeers)"
  Write-Host "Peering efficiency (PercentPeerCaching): $($Status.PercentPeerCaching)"
  Write-Host "Downloaded bytes from MCC (BytesFromCacheServer): $($Status.BytesFromCacheServer)"
  Write-Host "Downloaded bytes from LAN peers (BytesFromLanPeers): $($Status.BytesFromLanPeers)"
  Write-Host "Downloaded bytes from Group peers (BytesFromGroupPeers): $($Status.BytesFromGroupPeers)"
  Write-Host "Downloaded bytes from Group peers (BytesFromInternetPeers): $($Status.BytesFromInternetPeers)"
  Write-Host "Download duration (DownloadDuration): $("{0:dd}d:{0:hh}h:{0:mm}m:{0:ss}s" -f $($Status.DownloadDuration))"
  Write-host ""
}
}
Else{
  Write-Host "No DO status data found for application: $AppName. Continuing checking for log data"
}
 
# Get additional info from the Get-DeliveryOptimizationLog cmdlet (filter for the selected app only)
$DOLogsOutPut = Get-DeliveryOptimizationLog
$DOLogData = $DOLogsOutPut | Where-Object { `
  ($_.Function -Like "*::_InternalTraceDownloadCompleted") `
  -and ($_.Message -match "intunewin-bin_$($AppId)_1") `
  -and ($_.Message -match "caller: IntuneAppDownload")} # Not interested in the DOContentPolicy caller downloads
 
If ($DOLogData){
  foreach ($LogEntry in $DOLogData){
    Write-host "Writing some interesting metrics to the console"
    Write-host "Application name: $($AppName)"
    Write-host "Download time: $($LogEntry.TimeCreated)"
    Write-host "Details (Message): $($LogEntry.Message)"
    Write-host ""
  }
}
Else{
Write-Host "No DO log data found for application: $AppName."
}