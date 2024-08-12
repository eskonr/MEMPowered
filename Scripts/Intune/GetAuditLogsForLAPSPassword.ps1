#https://x.com/NathanMcNulty/status/1785051227568632263
#Oh, you wanted to dump all the LAPS passwords from Entra ID for... reasons? =)

Get-MgAuditLogDirectoryAudit -Filter "ActivityDisplayName eq 'Recover device local administrator password' and ActivityDateTime gt $((Get-Date).AddHours(-2).ToString('yyyy-MM-dd'))"