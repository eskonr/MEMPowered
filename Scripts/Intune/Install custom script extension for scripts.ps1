$fileUri = @("https://cb1cmg02.blob.core.windows.net/scripts/VMextention.ps1")

$settings = @{"fileUris" = $fileUri};

$storageAcctName = "cb1cmg02"
$storageKey = "12345"
$protectedSettings = @{"storageAccountName" = $storageAcctName; "storageAccountKey" = $storageKey; "commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File VMextention.ps1"};

#run command
New-AzConnectedMachineExtension -ResourceGroupName "Intune-svc-logs" `
    -Location "Southeast Asia" `
    -MachineName "AZ-SRV-003" `
    -Name "TestInstall" `
    -Publisher "Microsoft.Compute" `
    -ExtensionType "CustomScriptExtension" `
    -TypeHandlerVersion "1.10" `
    -Settings $settings `
    -ProtectedSettings $protectedSettings;