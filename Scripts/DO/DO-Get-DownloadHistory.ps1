# Converts completed download job entries from the Delivery Optimization Log into useable PS objects
$DOLogsOutPut = Get-DeliveryOptimizationLog
$CompletedDownloads = $DOLogsOutPut | Where-Object { $_.Function -Like "*::_InternalTraceDownloadCompleted" } 
$date=(get-date -format dd-MM-yyyy-HHmmss)

# Custom classes to contain put the parsed data into
class bytes {
    [int]$File 
    [int]$CDN 
    [int]$DOINC 
    [int]$rledbat
    [int]$LAN 
    [int]$LinkLocal
    [int]$Group 
    [int]$inet 
    [int]$lcache
    [int]$req
    [string]$total
}

class conns {
    [int]$CDN 
    [int]$DOINC 
    [int]$LAN 
    [int]$LinkLocal 
    [int]$Group
    [int]$inet 
}

class Message {
    [datetime]$TimeCreated
    [string]$jobId
    [string]$fileId
    [string]$sessionId
    [string]$updateId
    [string]$caller
    [System.Uri]$cdnUrl
    [string]$cdnIp
    [string]$cacheHost 
    [bytes]$bytes
    [int]$peers 
    [int]$localpeers
    [conns]$conns 
    [int]$downBps
    [int]$upBps
    [int]$downUsageBps
    [int]$upUsageBps
    [int]$timeMs
    [int]$sessionTimeMs
    [string]$groupId
    [int]$isBackground
    [int]$uploadRestr
    [int]$downloadMode
    [int]$downloadModeSrc
    [int]$reason
    [int]$isVpn
    [int]$isEncrypted
    [datetime]$expireAt
    [int]$isThrottled
}

# Temporarily set the EA pref to silently continue to avoid console errors if some data is missing
$EAPDefault = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

# Read each log entry message and add to an object
$LogEntries = [System.Collections.ArrayList]::new()
foreach ($CompletedDownload in $CompletedDownloads)
{
    $LogEntryMessageArray = $CompletedDownload.Message.Split(',').Trim()
    $Message = [Message]::new()
    $Message.bytes = [bytes]::new()
    $Message.conns = [conns]::new()
    $Message.TimeCreated = $CompletedDownload.TimeCreated
    $Message.jobId = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "jobId:"}).Split()[-1]
    $Message.fileId = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "fileId:"}).Split()[-1]
    $Message.sessionId = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "sessionId:"}).Split()[-1]
    $Message.updateId = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "updateId:"}).Split()[-1]  -replace "updateId:" -replace "{" -replace "}"
    $Message.caller = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "caller:"}).Split(':')[-1].Trim()
    $Message.cdnUrl = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "cdnUrl ="}).Split()[-1]
        $Index = [System.Array]::FindIndex($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "cdnIp ="})
        $NextIndex = ($Index + 1)
        do {$NextItem = $LogEntryMessageArray[$NextIndex];$NextIndex ++} until ($NextItem -match "cacheHost")
        $Difference = ($NextIndex - 2) - $Index
        $cdnIp = $LogEntryMessageArray[$Index]
        if ($cdnIp -match ',')
        {
            $cdnIp = $LogEntryMessageArray[$Index].Split()[-1]
            0..$Difference | foreach {
                $cdnIp = $cdnIp,$LogEntryMessageArray[($Index + $_)] -join ","
            }
        }
    If ($cdnIp -notmatch ",cdnIp")
    {
        $Message.cdnIp = $cdnIp.Split('=')[1].Trim()
    }
    $Message.cacheHost = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "cacheHost"}).Split()[-1] -replace "="
    $Message.bytes.File = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "File:"}).Split()[-1]
    $Message.bytes.CDN = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "CDN:"}).Split()[-1]
    $Message.bytes.DOINC = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "DOINC:"}).Split()[-1]
    $Message.bytes.rledbat = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "rledbat:"}).Split()[-1]
    $Message.bytes.LAN = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "LAN:"}).Split()[-1]
    $Message.bytes.LinkLocal = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "LinkLocal:"}).Split()[-1]
    $Message.bytes.Group = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "Group:"}).Split()[-1]
    $Message.bytes.inet = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "inet:"}).Split()[-1]
    $Message.bytes.lcache = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "lcache:"}).Split()[-1]
    $Message.bytes.req = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "req:"}).Split()[-1]
    $Message.bytes.total = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "total:"}).Split()[-1] -replace ";" -replace "]"
    $Message.peers = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "peers:"}).Split()[1]
    $Message.localpeers = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "peers"}).Split()[-1].TrimEnd(')')
    $Message.conns.CDN = [System.Array]::FindAll($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "CDN:"})[-1].Split()[-1]
    $Message.conns.DOINC = [System.Array]::FindAll($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "DOINC:"})[-1].Split()[-1]
    $Message.conns.LAN = [System.Array]::FindAll($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "LAN:"})[-1].Split()[-1]
    $Message.conns.LinkLocal = [System.Array]::FindAll($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "LinkLocal:"})[-1].Split()[-1]
    $Message.conns.Group = [System.Array]::FindAll($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "Group:"})[-1].Split()[-1]
    $Message.conns.inet = [System.Array]::FindAll($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "inet:"})[-1].Split()[-1].TrimEnd(']')
    $Message.downBps = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "downBps:"}).Split()[-1]
    $Message.upBps = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "upBps:"}).Split()[-1]
    $Message.downUsageBps = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "downUsageBps:"}).Split()[-1]
    $Message.upUsageBps = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "upUsageBps:"}).Split()[-1]
    $Message.timeMs = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "timeMs:"}).Split()[-1]
    $Message.sessionTimeMs = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "sessionTimeMs:"}).Split()[-1]
    $Message.groupId = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "groupId"}).Split()[-1] -replace "="
    $Message.isBackground = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "background"}).Split()[-1]
    $Message.uploadRestr = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "uploadRestr:"}).Split()[-1]
    $Message.downloadMode = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "downloadMode:"}).Split()[-1]
    $Message.downloadModeSrc = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "downloadModeSrc:"}).Split()[-1]
    $Message.reason = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "reason:"}).Split()[-1]
    $Message.isVpn = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "isVpn:"}).Split()[-1]
    $Message.isEncrypted = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "encrypted"}).Split()[-1]
    $Message.expireAt = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "expire at"}).Split()[-1]
    $Message.isThrottled = [System.Array]::Find($LogEntryMessageArray,[Predicate[string]]{ $args[0] -match "isThrottled ="}).Split()[-1]
    [void]$LogEntries.Add($Message)
}

# Set the EA preference back to previous value
$ErrorActionPreference = $EAPDefault

##############################################
## A few examples for filtering the results ##
##############################################

# Display all objects in grid view
$LogEntries | Export-Csv "C:\temp\$env:COMPUTERNAME-DOHistory-$date.csv" -NoTypeInformation
#Out-GridView

# Count log entries by the caller type, eg 'WU Client Download', 'EdgeUpdate DO Job', 'IntuneAppDownload','Windows Package Manager' etc
$LogEntries | Group-Object -Property caller -NoElement | Sort Count -Descending | ft -AutoSize

# Filter entries by a caller type
$LogEntries | where {$_.caller -eq "IntuneAppDownload"}

# Count of foreground DO download jobs
($LogEntries | where {$_.isBackground -eq 0}).count

# Count log entries by the Download Mode
$LogEntries | Group-Object -Property downloadMode -NoElement | Sort Count -Descending

# Total MB/GB downloaded from CDN by a specific caller
$TotalBytes = (($LogEntries | where {$_.caller -eq "WU Client Download"}).bytes.CDN | Measure-Object -Sum).Sum
"$([math]::Round(($TotalBytes / 1MB),2)) MB" + "  |  " + "$([math]::Round(($TotalBytes / 1GB),2)) GB"

# Completed download jobs per day
$LogEntries | Select-Object @{l='TimeCreated';e={$_.TimeCreated.ToString("yyyy-MM-dd")}} | Group-Object -Property TimeCreated -NoElement | Sort Name -Descending