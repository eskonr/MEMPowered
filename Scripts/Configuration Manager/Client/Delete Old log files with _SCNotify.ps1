$Global:ErrorActionPreference = "SilentlyContinue"

stop-Transcript | out-null
Start-Transcript -path C:\windows\Temp\Logs\CleanSCCMSCLogs.log -append
$startdate = Get-Date
Get-ChildItem c:\windows\ccm\logs | Where-Object {$_.Name -like 'SCNotify*' -or $_.Name -like 'SCClient*' -or $_.Name -like '_SCNotify*' -or $_.Name -like '_SCClient*'} | Foreach-object {
$difference = New-TimeSpan -Start $startdate -End $_.LastWriteTime
  "Log: $($_.Name)"
  "Day difference: $($difference.Days)"
  # Delet all the files that are older than 7 days 
 if ($difference.Days -lt -7) 
{
     del $_.FullName
}
}