# Requires: RSAT ActiveDirectory module
Import-Module ActiveDirectory -ErrorAction Stop

# Config: set one of these identifiers for the starting manager
$ManagerIdentity = 'eswar@eskonr.com'   # can be email (mail), UPN, sAMAccountName, or CN
$DomainServer = 'domainame' #intranet.eskonr or your domain name                      # optional, can be a DC or domain name; set $null to let AD choose
$MaxDepth = 7                                   # levels deep
$OutputCsv = 'C:\temp\AD_Reportees_Level7.csv' # output path

# ===== Start time tracking =====
$scriptStart = Get-Date

# Helper: resolve an AD user by common identifiers
function Resolve-AdUser {
    param(
        [Parameter(Mandatory = $true)][string]$Identity,
        [string]$Server
    )
    # Try by UPN
    $user = $null
    try { $user = Get-ADUser -Filter "userPrincipalName -eq '$Identity'" -Server $Server -Properties mail, title, department, manager } catch {}
    if (-not $user) {
        # Try by mail
        try { $user = Get-ADUser -Filter "mail -eq '$Identity'" -Server $Server -Properties mail, title, department, manager } catch {}
    }
    if (-not $user) {
        # Try by sAMAccountName
        try { $user = Get-ADUser -Filter "sAMAccountName -eq '$Identity'" -Server $Server -Properties mail, title, department, manager } catch {}
    }
    if (-not $user) {
        # Try by CN (name)
        try { $user = Get-ADUser -Filter "cn -eq '$Identity'" -Server $Server -Properties mail, title, department, manager } catch {}
    }
    return $user
}

# Helper: get direct reports of a manager DN
function Get-DirectReports {
    param(
        [Parameter(Mandatory = $true)][string]$ManagerDistinguishedName,
        [string]$Server
    )
    # direct reports are users whose 'manager' attribute equals the manager's DN
    try {
        $reports = Get-ADUser -LDAPFilter "(manager=$ManagerDistinguishedName)" -Server $Server -Properties mail, title, department, manager, userPrincipalName, sAMAccountName, displayName, distinguishedName
        return $reports
    } catch {
        return @()
    }
}

# Resolve the starting manager
$managerUser = Resolve-AdUser -Identity $ManagerIdentity -Server $DomainServer
if (-not $managerUser) { throw "Manager not found in AD for identity: $ManagerIdentity" }

Write-Host "Starting manager: $($managerUser.DisplayName) ($($managerUser.UserPrincipalName))" -ForegroundColor Cyan

# Build a queue for BFS up to MaxDepth
$results = New-Object System.Collections.Generic.List[object]
$visited = New-Object System.Collections.Generic.HashSet[string]  # DN hash to avoid cycles

# Seed level 0 (manager themselves optional; comment out if not needed)
$managerProps = Get-ADUser -Identity $managerUser.DistinguishedName -Server $DomainServer -Properties mail, title, department, manager, userPrincipalName, sAMAccountName, displayName, distinguishedName
$managerRecord = [pscustomobject]@{
    Level             = 0
    Name              = $managerProps.DisplayName
    sAMAccountName    = $managerProps.sAMAccountName
    UserPrincipalName = $managerProps.UserPrincipalName
    Email             = $managerProps.mail
    Title             = $managerProps.title
    Department        = $managerProps.department
    ManagerName       = $null
    ManagerUPN        = $null
    ManagerEmail      = $null
    DistinguishedName = $managerProps.DistinguishedName
}
$results.Add($managerRecord) | Out-Null
[void]$visited.Add($managerProps.DistinguishedName)

# Queue holds tuples: @{ Level = n; ManagerDN = dn; ManagerInfo = managerProps }
$queue = New-Object System.Collections.Generic.Queue[object]
$queue.Enqueue(@{ Level = 1; ManagerDN = $managerProps.DistinguishedName; ManagerInfo = $managerProps })

while ($queue.Count -gt 0) {
    $item = $queue.Dequeue()
    $level = [int]$item.Level
    if ($level -gt $MaxDepth) { continue }

    $mgrDN = [string]$item.ManagerDN
    $mgrInfo = $item.ManagerInfo

    $directs = Get-DirectReports -ManagerDistinguishedName $mgrDN -Server $DomainServer

    foreach ($u in $directs) {
        # Skip if visited to avoid cycles
        if ($visited.Contains($u.DistinguishedName)) { continue }
        [void]$visited.Add($u.DistinguishedName)

        $rec = [pscustomobject]@{
            Level             = $level
            Name              = $u.DisplayName
            sAMAccountName    = $u.sAMAccountName
            UserPrincipalName = $u.UserPrincipalName
            Email             = $u.mail
            Title             = $u.title
            Department        = $u.department
            ManagerName       = $mgrInfo.DisplayName
            ManagerUPN        = $mgrInfo.UserPrincipalName
            ManagerEmail      = $mgrInfo.mail
            DistinguishedName = $u.DistinguishedName
        }
        $results.Add($rec) | Out-Null

        # Enqueue for next level if we haven't reached MaxDepth
        if ($level + 1 -le $MaxDepth) {
            # Get full properties for this user to carry as manager for next level
            $uFull = Get-ADUser -Identity $u.DistinguishedName -Server $DomainServer -Properties mail, title, department, manager, userPrincipalName, sAMAccountName, displayName, distinguishedName
            $queue.Enqueue(@{ Level = ($level + 1); ManagerDN = $uFull.DistinguishedName; ManagerInfo = $uFull })
        }
    }
}

# Output
#$results | Sort-Object Level, Name | Format-Table Level, Name, sAMAccountName, UserPrincipalName, Email, Title, Department, ManagerName -AutoSize

# Export CSV
$results | Sort-Object Level, Name | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host "Exported reportees (up to level $MaxDepth) to: $OutputCsv" -ForegroundColor Green

# ===== End time tracking and report =====
$scriptEnd = Get-Date
$elapsedSeconds = [math]::Round(($scriptEnd - $scriptStart).TotalSeconds, 2)
$elapsedMinutes = [math]::Round(($scriptEnd - $scriptStart).TotalMinutes, 2)
Write-Host "Total time taken: $elapsedSeconds seconds ($elapsedMinutes minutes)" -ForegroundColor Cyan