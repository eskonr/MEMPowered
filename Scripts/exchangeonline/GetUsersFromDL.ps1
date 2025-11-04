<#
This script helps to extract the list of users from the DL using exchange online.

Date: 04Nov 2025
Author: Eswar Koneti

#>
Connect-ExchangeOnline

## Set Variables:  
$membersList = New-Object System.Collections.Generic.List[PSCustomObject]

## Create the Function  
function getMembership($group) {  
    $searchGroup = Get-DistributionGroupMember $group -ResultSize Unlimited  
    foreach ($member in $searchGroup) {  
        if ($member.RecipientTypeDetails -match "Group" -and $member.PrimarySMTPAddress -ne "") {  
            getMembership($member.PrimarySMTPAddress)  
        }             
        else {  
            if ($member.DisplayName -ne "") {  
                if (-not ($membersList | Where-Object { $_.PrimarySMTPAddress -eq $member.PrimarySMTPAddress })) {
                    $membersList.Add([PSCustomObject]@{
                        DisplayName = $member.DisplayName
                        PrimarySMTPAddress = $member.PrimarySMTPAddress
                    })
                }  
            }  
        }  
    }  
}

## Define the groups
$groupIdentities = @(
    "anothergroup@domain.com",
    "another_group@domain.com",
    "yet_another_group@domain.com"
    # Add more group identities as needed
)

## Run the function for each group
foreach ($groupIdentity in $groupIdentities) {  
    Write-Host "`nProcessing Group: " $groupIdentity -ForegroundColor Green  
    $group = Get-DistributionGroup -Identity $groupIdentity
    if ($group) {
        getMembership($group.PrimarySMTPAddress)
    } else {
        Write-Host "Group not found: $groupIdentity" -ForegroundColor Red
    }
}

## Export to CSV
$membersList | Sort-Object PrimarySMTPAddress | Export-Csv -Path "GroupMembers.csv" -NoTypeInformation