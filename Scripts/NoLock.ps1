clear-host
$myshell = New-Object -com "Wscript.Shell"
while ($True) {
    $myshell.sendkeys("{SCROLLLOCK}")
    Start-Sleep -milliseconds 200
    $myshell.sendkeys("{SCROLLLOCK}")
    Start-Sleep -Seconds 200
}