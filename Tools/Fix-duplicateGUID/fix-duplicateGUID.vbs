Set oWMI = GetObject("winmgmts:\\.\root\cimv2") 
Set oComputerSystem = oWMI.ExecQuery("Select Name from Win32_ComputerSystem") 
For Each oInstance in oComputerSystem 
oName = oInstance.name 
Next 
Set WshShell = WScript.CreateObject("WScript.Shell") 
Set filesys = CreateObject("Scripting.FileSystemObject") 
Dim arrFileLines() 
i = 0 
Set objFSO = CreateObject("Scripting.FileSystemObject") 
Set objFile = objFSO.OpenTextFile("\\MyServer\MyShare\SMS Tools\DuplicateGuids.txt", 1) 
Do Until objFile.AtEndOfStream 
Redim Preserve arrFileLines(i) 
arrFileLines(i) = objFile.ReadLine 
i = i + 1 
Loop 
objFile.Close 
For l = Ubound(arrFileLines) to LBound(arrFileLines) Step -1 
If UCase(arrFileLines(l)) = oName Then 
If filesys.FileExists("c:\Windows\smscfg.ini") Then 
CreateFlagFolder 
End If 
End If 
Next 
Sub CreateFlagFolder 
If filesys.FolderExists("c:\TranGuid") Then 
CreateFlagFile 
Else 
Set folder = filesys.CreateFolder("c:\TranGuid") 
CreateFlagFile 
End If 
End Sub 
Sub CreateFlagFile 
If NOT (filesys.FileExists("c:\TranGuid\TranGuid.txt")) Then 
WSHShell.Run "TranGuid.bat" 
Set filetxt = filesys.CreateTextFile("c:\TranGuid\TranGuid.txt", True) 
End If 
End Sub