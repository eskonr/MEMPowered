@echo off 

::----- Deletes the contents of Patches ----- 
IF EXIST C:\Windows\Installer\$PatchCache$\Managed ( 
forfiles /p "C:\Windows\Installer\$PatchCache$\Managed" /s /m * /D -0 /C "cmd /c del /Q /F /S /A:R @path" 
)

::----- Deletes the contents of Download Installations -----
IF EXIST "C:\Windows\Downloaded Installations" (
forfiles /p "C:\Windows\Downloaded Installations" /s /m *.* /D -0 /C "cmd /c del /Q @path" 
)

::----- Deletes the ServiceProfiles for Citrix Servers ----- 
IF EXIST C:\Windows\ServiceProfiles\LocalService\AppData\Local ( 
forfiles /P "C:\Windows\ServiceProfiles\LocalService\AppData\Local" /M FontCache* /D -5 /C "cmd /c del @path" 
)

::----- Deletes the contents of Windows Temp files ----- 
IF EXIST c:\windows\temp\ ( 
forfiles /p "C:\Windows\Temp" /s /m * /C "cmd /c del /Q @path"
)
 
::----- Deletes the KB files of SQL Server -----
IF EXIST "C:\Program Files\Microsoft SQL Server\100\Setup Bootstrap\Update Cache" (
forfiles /p "C:\Program Files\Microsoft SQL Server\100\Setup Bootstrap\Update Cache" /s /m "KB*.*" /D -0 /C "cmd /c del /Q @path" 
)

::----- Deletes the contents of Users Temp Internet and ReportQueue files for WinServer 2k8 -----  
IF EXIST "C:\Users\" (
for /D %%x in ("C:\Users\*") do (                
forfiles /p "%%x\AppData\Local\Temp" /s /m *.* /D -0 /C "cmd /c del /Q @path" 
forfiles /p "%%x\AppData\Local\Microsoft\Windows\Temporary Internet Files" /s /m *.* /D -7 /C "cmd /c del /Q @path" 
forfiles /p "%%x\AppData\Local\Microsoft\Windows\WER\ReportQueue" /s /m *.* /C "cmd /c del /Q @path" 
)
)                       

::----- Deletes the contents of Users Temp folder for WinServer 2k3 -----
IF EXIST "C:\Documents and Settings\" ( 
for /D %%x in ("C:\Documents and Settings\*") do (                
forfiles /p "%%x\Local Settings\Temp" /s /m *.* /D -0 /C "cmd /c del /Q @path" 
forfiles /p "%%x\Local Settings\Temporary Internet Files" /s /m *.* /D -7 /C "cmd /c del /Q @path"  
)
)                       

::----- Deletes the contents of Install Temp files older than 5 days -----
IF EXIST C:\install ( 
forfiles /p "C:\install" /s /m *.* /D -5 /C "cmd /c del /Q @path"
)

::----- Deletes the contents of C:\temp\test -----
IF EXIST C:\temp\test ( 
forfiles /p "C:\temp\test" /s /m *.* /C "cmd /c del /Q @path"
)


::----- Deletes the contents of Recycle bin for WinServer 2k8 and 2k12 -----
IF EXIST C:\$Recycle.Bin ( 
forfiles /p "C:\$Recycle.Bin" /s /m *.* /C "cmd /c del /Q @path" 
) 

::----- Deletes the contents of Recycle bin for WinServer 2k3 -----
IF EXIST C:\RECYCLER ( 
forfiles /p "C:\RECYCLER" /s /m *.* /C "cmd /c del /Q @path" 
) 

::----- Compress the IIS logs older than 10 days & Delete Log Files Older than 365 Days -----
IF EXIST "C:\inetpub\logs\LogFiles" ( 
forfiles /p "C:\inetpub\logs\LogFiles" /s /m "*.log" /D -10 /C "cmd /c compact /c /f /Q @path" 
forfiles /p "C:\inetpub\logs\LogFiles" /s /m "*.log" /D -365 /C "cmd /c del /Q /F @path"
)

::----- Compress the IIS logs in C:\Windows\System32 older than 10 days & Delete Log Files Older than 365 Days -----
IF EXIST "C:\Windows\System32\LogFiles" ( 
forfiles /p "C:\Windows\System32\LogFiles\" /s /m "*.log" /D -10 /C "cmd /c compact /c /f /Q @path" 
forfiles /p "C:\Windows\System32\LogFiles\" /s /m "*.log" /D -365 /C "cmd /c del /Q /F @path"
)

::----- Compress the Archived Event logs -----
IF EXIST "C:\Windows\System32\winevt\Logs" ( 
forfiles /p "C:\Windows\System32\winevt\Logs" /s /m "Archive-*.evtx" /D -0 /C "cmd /c compact /c /f /Q @path" 
)