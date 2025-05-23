$Storeapps=Get-AppxPackage -AllUsers | Where-Object { 
  $_.IsFramework -eq $false -and ($_.SignatureKind -eq 'Store' -or $_.SignatureKind -eq 'Developer') -and ($_.NonRemovable -eq $false)
}
$Storeapps | Select-Object Name,PublisherId,Architecture,Version,PackageFullName,InstallLocation,SignatureKind | Out-GridView