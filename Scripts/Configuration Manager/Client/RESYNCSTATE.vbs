'If you are running the script on 64bit,use C:\windows\syswow64\ folder to 'run the script else it will fail
RefreshServerComplianceState()

Sub RefreshServerComplianceState() 
    dim newCCMUpdatesStore 
    set newCCMUpdatesStore = CreateObject ("Microsoft.CCM.UpdatesStore") 
    newCCMUpdatesStore.RefreshServerComplianceState 
End Sub
