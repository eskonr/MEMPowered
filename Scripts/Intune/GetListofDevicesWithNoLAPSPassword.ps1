#https://x.com/NathanMcNulty/status/1785051227568632263
#Compare the devices that dont have LAPS password.

$alldevices = Get-MgDevice -Filter "OperatingSystem eq 'Windows'"
$laps = Get-MgDirectoryDeviceLocalCredential
Compare-Object -ReferenceObject $alldevices.DeviceId -DifferenceObject $laps.Id