<#

This script gets the recovery protector from the OS Drive then pushes the recovery key associated with that protector to Azure AD as associated with the

OS Drive.

#>

#Narrow scope to applicable recovery protector

$AllProtectors = (Get-BitlockerVolume -MountPoint $env:SystemDrive).KeyProtector

$RecoveryProtector = ($AllProtectors | where-object { $_.KeyProtectorType -eq "RecoveryPassword" })

#Push Recovery Password AAD

BackupToAAD-BitLockerKeyProtector $env:systemdrive -KeyProtectorId $RecoveryProtector.KeyProtectorID