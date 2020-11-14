Set fso=CreateObject("Scripting.FileSystemObject")
Set WshShell = CreateObject("WScript.Shell")
bRemoveMSECACHE = False

sProgramFiles = WshShell.ExpandEnvironmentStrings("%ProgramFiles%") 
If sProgramFiles = "%ProgramFiles%" Then sProgramFiles = WshShell.RegRead("HKLM\Software\Microsoft\Windows\CurrentVersion\ProgramFilesDir")

sMSECACHEPath = sProgramFiles & "\MSECACHE"
If Not fso.FolderExists(sMSECACHEPath) Then 
    fso.CreateFolder(sMSECACHEPath) 
    bRemoveMSECACHE = True
End If

sTargetPath = sMSECACHEPath & "\WICU3"
If Not fso.FolderExists(sTargetPath) Then fso.CreateFolder(sTargetPath) 

fso.CopyFile fso.GetParentFolderName(WScript.ScriptFullName) & "\M*.*", sTargetPath 
fso.CopyFile fso.GetParentFolderName(WScript.ScriptFullName) & "\r*.*", sTargetPath 

sCmd = "msiexec.exe /i """ & sTargetPath & "\msicuu.msi"""
iRC = WshShell.Run(sCmd, 4, True)

If iRC <> 0 And iRC <> 3010 Then 
   fso.DeleteFolder sTargetPath, True
   If bRemoveMSECACHE Then fso.DeleteFolder sMSECACHEPath, True
End If