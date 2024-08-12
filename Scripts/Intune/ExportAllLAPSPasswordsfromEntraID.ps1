#https://x.com/NathanMcNulty/status/1785051227568632263
#Oh, you wanted to dump all the LAPS passwords from Entra ID for... reasons? =)

Connect-MgGraph -Scopes 'DeviceLocalCredential.Read.All'

Get-MgDevice -Filter "OperatingSystem eq 'Windows'" | ForEach-Object {
[array]$b64 = (Get-MgDirectoryDeviceLocalCredential -DeviceLocalCredentialInfoId $_.DeviceId -Property credentials).credentials.PasswordBase64
[string]$pw = if (!([string]::IsNullOrEmpty($b64))) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($b64)[0])) }
[array]$lapsReport += "$($_.displayName),$pw"
}
$lapsReport