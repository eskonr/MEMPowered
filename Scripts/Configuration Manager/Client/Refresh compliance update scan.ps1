$SCCMUpdatesStore = New-Object -ComObject Microsoft.CCM.UpdatesStore
$SCCMUpdatesStore.RefreshServerComplianceState()