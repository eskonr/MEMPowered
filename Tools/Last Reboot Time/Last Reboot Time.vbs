'******************************************************************** 
'* File: LastReboot.vbs 
'* Author: Manoj Nair | Created on 09/10/2009 
'* Version 1.0 
'* 
'* Main Function: Displays the last reboot time of a computer 
'* 
'******************************************************************** 
 
On Error Resume Next 
Const ForReading = 1 
Set objFSO = CreateObject("Scripting.FileSystemObject") 
 
    ' ===================================================================== 
     'Gets the script to run against each of the computers listed  
     'in the text file path for which should be specified in the syntax below 
    ' ===================================================================== 
Set objTextFile = objFSO.OpenTextFile("C:\Users\FRIOWIN19\Desktop\Last Reboot Time\servers.txt", ForReading) 
Set outfile = objFSO.CreateTextFile("Report.txt") 
Do Until objTextFile.AtEndOfStream  
    strComputer = objTextFile.Readline 
    ' =============================================================================== 
    ' Code to get the Last Boot Time using LastBootupTime from Win32_Operating System 
    ' =============================================================================== 
Set objWMIService = GetObject _ 
    ("winmgmts:\\" & strComputer & "\root\cimv2") 
Set colOperatingSystems = objWMIService.ExecQuery _ 
    ("Select * from Win32_OperatingSystem") 
For Each objOS in colOperatingSystems 
    dtmBootup = objOS.LastBootUpTime 
    dtmLastBootupTime = WMIDateStringToDate(dtmBootup) 
    'OutFile.WriteLine "==========================================" 
    OutFile.WriteLine "Computer: " & strComputer & " Last Reboot: " & dtmLastBootupTime 
    OutFile.WriteLine "==========================================" 
     
     
Next 
 
    ' ===================================================================== 
    ' End 
    ' ===================================================================== 
Loop 
objTextFile.Close 
 ' =============================================================================== 
 ' Displaying to the user that the script execution is completed 
 ' =============================================================================== 
MsgBox "Script Execution Completed. The Report is saved as Report.txt in the current directory" 
 ' =============================================================================== 
 ' Function to convert UNC time to readable format 
 ' =============================================================================== 
Function WMIDateStringToDate(dtmBootup) 
    WMIDateStringToDate = CDate(Mid(dtmBootup, 5, 2) & "/" & _ 
         Mid(dtmBootup, 7, 2) & "/" & Left(dtmBootup, 4) _ 
         & " " & Mid (dtmBootup, 9, 2) & ":" & _ 
         Mid(dtmBootup, 11, 2) & ":" & Mid(dtmBootup, _ 
         13, 2)) 
End Function