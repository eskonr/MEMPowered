<#
This script will check if any disconnected users found, force logoff.
This is useful when there are multiple users logging to the server remotely and not logoffing properly which tend to increase the memory utilisation due to the number of apps opened by each user session.
This script can be schedule to run with system account and run it every few hours or so to check and force logoff users.

Author: Eswar
Date:10/15/2025
#>
Start-Transcript -Path "C:\Temp\forcelogoffdisconnected.log"
# Get all sessions using quser (direct or filtered)
$sessionOutput = quser.exe #| Select-String 'youraccountForTesting'

foreach ($line in $sessionOutput) {
<#
    # Handle both MatchInfo and String types
    if ($line -is [Microsoft.PowerShell.Commands.MatchInfo]) {
        $textLine = $line.Line.Trim()
    } else {
        $textLine = $line.Trim()
    }
    #>

    $textLine = $line.Trim()

    # Skip header and empty lines
    if ($textLine -match "USERNAME\s+SESSIONNAME" -or $textLine -eq "") { continue }

    # Use regex to extract fields
    if ($textLine -match '^(?<Username>\S+)\s+(?<SessionName>\S+)?\s+(?<ID>\d+)\s+(?<State>\S+)\s+(?<IdleTime>\S+)?\s+(?<LogonTime>.+)?$') {
        $username = $matches['Username']
        $sessionId = $matches['ID']
        $sessionState = $matches['State']

        if ($sessionState -eq "Disc") {
            Write-Host "Logging off disconnected session for user '$username' (Session ID: $sessionId)..."
            # Uncomment the next line to actually log off the session
             logoff.exe $sessionId /v
        }
    }
}
Stop-Transcript