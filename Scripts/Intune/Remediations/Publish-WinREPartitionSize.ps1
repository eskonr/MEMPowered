# Get all partitions
$partitions = Get-Partition
$recoveryPartitions = Get-Partition | Where-Object { $_.gpttype -eq '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}'}

# Check if any recovery partitions are found
if (($recoveryPartitions| Measure-Object).count -gt 0) {
    foreach ($partition in $recoveryPartitions) {
        # Get the drive letter (if available)
        $driveLetter = if ($partition.DriveLetter) { $partition.DriveLetter } else { "Not Assigned" }

        # Get the size of the recovery partition
        $recoverySize = $partition.Size
        
        # Convert size to GB for better readability
        $recoverySizeGB = [math]::Round($recoverySize / 1024KB, 2)
        Write-Host "Size: $recoverySizeGB MB and "Type: $($partition.Type)""
        exit 0
        
    }
} else {
    Write-Host "No recovery partitions found."
    exit 1
    }
