<#
.SYNOPSIS
Microsoft has recently updated the requirements for KB that needs atleast 250 MB free space in WINRE recovery parition.
If any devices that contains less than 250 MB of free space in recovery partition, the Jan 2024 patches will fail to install.
For more information, please read https://support.microsoft.com/en-us/topic/kb5034439-windows-recovery-environment-update-for-windows-server-2022-january-9-2024-6f9d26e6-784c-4503-a3c6-0beedda443ca

https://support.microsoft.com/en-us/topic/kb5028997-instructions-to-manually-resize-your-partition-to-install-the-winre-update-400faa27-9343-461c-ada9-24c8229763bf

https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/add-update-to-winre?view=windows-11#extend-the-windows-re-partition

.DESCRIPTION
Check the freespace of WINRE recovery partition and report the status.

.NOTES
File Name      : Detect - WINRERecoveryPartition.ps1
Author         : Eswar Koneti
Date           : 26-Feb-2024
Reference      : https://support.microsoft.com/en-us/topic/kb5028997-instructions-to-manually-resize-your-partition-to-install-the-winre-update-400faa27-9343-461c-ada9-24c8229763bf
                 https://memv.ennbee.uk/posts/winre-parition-resize-kb5034441/
               
#>
#Recovery Partition free size required for KB5028997
$freePartitionSpace = '250000000' #bytes

Try {

    $computerDisks = Get-PhysicalDisk
    foreach ($computerDisk in $computerDisks) {
        $diskPartitions = Get-Partition -DiskNumber $computerDisk.DeviceId -ErrorAction Ignore
        if ($diskPartitions.DriveLetter -contains 'C' -and $null -ne $diskPartitions) {
            $systemDrive = $computerDisk
        }
    }
    $recPartition = Get-Partition -DiskNumber $systemDrive.DeviceId | Where-Object { $_.Type -eq 'Recovery' }

    $recVolume = Get-Volume -Partition $recPartition

    if ($recVolume.SizeRemaining -le $freePartitionSpace) {
        Write-Output "Free Space $([Math]::Round($recVolume.SizeRemaining / 1MB, 2)) MB of $([Math]::Round($recVolume.Size / 1MB, 2)) MB"
        # $($($recVolume.Size) / 1000000) MB "
        Exit 1
        #go to remediation https://github.com/Action1Corp/EndpointScripts/blob/main/FixWinREKB5034441.ps1
    }
    else {
        Write-Output "Free Space $([Math]::Round($recVolume.SizeRemaining / 1MB, 2)) MB of $([Math]::Round($recVolume.Size / 1MB, 2)) MB"
        Exit 0
    }
}
Catch {
    Write-Output 'Partition not found.'
    Exit 1
}
