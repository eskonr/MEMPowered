#https://x.com/NathanMcNulty/status/1818885106662047819
#EntraID apps expiring the secret in next 30 days
Get-MgApplication | Where-Object { $_.PasswordCredentials.keyId -ne $null -and $_.PasswordCredentials.EndDateTime -lt (Get-Date).AddDays(30) } | ForEach-Object { $_.DisplayName,$_.Id,$_.PasswordCredentials } | Format-List