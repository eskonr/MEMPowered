@ECHO OFF
REM Script for copying logs, traces, events, etc for troubleshooting WU, Servicing, ETC
REM Modify date 2/26/2021
REM Version 1.24
REM Author: Leonard.Severt@microsoft.com

REM - Get Reagent /info output  - Done reagentc.txt
REM - Get DISM /online /Get-CurrentEdition and DISM /online /Get-TargetEditions - Done DISM-EditionInfo.txt
REM - Store on desktop - Done
REM - Get servicing package state using Andrei PS - Done  Servicing_PackageState
REM - Attempting fix MDMDiag 0 byte file issues...thanks Andrei -
REM - Get OneSettings - Done WindowsUpdate_Reg_Onesettings.txt
REM - Get Powershell output on MBAM Server - Done 
REM - Add HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power toplevel to Surface Reg output - Done
REM - Get all of HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power - Done Reg_Power.txt
REM - Move servicing hive registry output to end of processing incase of hang - done


REM Check for admin permission
FOR /f "usebackq" %%f IN (`whoami /priv`) DO IF "%%f"=="SeTakeOwnershipPrivilege" GOTO :IS_ADMIN
ECHO CreateObject("Shell.Application").ShellExecute Chr(34) ^& "%WINDIR%\System32\cmd.exe" ^& Chr(34), "/K " ^& Chr(34) ^& "%~dpfx0 %*" ^& Chr(34), "", "runas", 1 >"%TEMP%\RunAs.vbs"
WScript.exe "%TEMP%\RunAs.vbs"
GOTO :EOF

:IS_ADMIN

@ECHO ##################################################################################################
@ECHO # THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED   #
@ECHO # OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR      #
@ECHO # FITNESS FOR A PARTICULAR PURPOSE.                                                              #
@ECHO #                                                                                                #
@ECHO # Copyright (c) Microsoft Corporation. All rights reserved                                       #
@ECHO #                                                                                                #
@ECHO # This script is not supported under any Microsoft standard support program or service.          #
@ECHO # The script is provided AS IS without warranty of any kind. Microsoft further disclaims all     #
@ECHO # implied warranties including, without limitation, any implied warranties of merchantability    #
@ECHO # or of fitness for a particular purpose. The entire risk arising out of the use or performance  #
@ECHO # of the scripts and documentation remains with you. In no event shall Microsoft, its authors, #
@ECHO # or anyone else involved in the creation, production, or delivery of the script be liable for   #
@ECHO # any damages whatsoever (including, without limitation, damages for loss of business profits,   #
@ECHO # business interruption, loss of business information, or other pecuniary loss) arising out of   #
@ECHO # the use of or inability to use the script or documentation, even if Microsoft has been advised #
@ECHO # of the possibility of such damages.                                                            #
@ECHO ##################################################################################################
@echo OFF

:Ask
@Echo Do you accept the user agreement?
Set /p choice=Y or N [ENTER=Y]? 
if /i '%choice%' NEQ 'N' goto Begin
if '%choice%' =='y' goto Begin
goto Good_Bye

:Begin

setlocal
set _DATASTORE=0
REM Flush Windows Update logs by stopping services before copying...usually not needed.
set _FLUSH_LOGS=0
REM Gather upgrade logs.
set _UPGRADE=1
REM DXDiag isn't usually needed.
set _DXDIAG=0
REM Get Winsxs and .Net file version info - Supported on systems with PowerShell 4+
set _GETWINSXS=0
REM Get App Compat info
set _APPCOMPAT=0
REM Get Detail Power info
set _POWERCFG=0
Rem Get mimimum info
set _Min=0
Rem Get max info
set _Max=0
Rem Surface Device
set _Surface=0



:START
REM Get today's date and remove delimiters from it like "/", ".", "-" and append this to the folder name
set _DATESTRING=%DATE%
set _DATESTRING=%_DATESTRING:/=%
set _DATESTRING=%_DATESTRING:.=%
set _DATESTRING=%_DATESTRING:-=%
set _DATESTRING=%_DATESTRING: =%
set _FOLDERNAME=Setup_Report_%COMPUTERNAME%_%_DATESTRING%
REM - Store on desktop
set _TEMPDIR=%userprofile%\desktop\%_FOLDERNAME%
REM - To store on D drive if not enough space on C use this
REM set _TEMPDIR=D:\%_FOLDERNAME%
set _PREFIX=%_TEMPDIR%\%computername%_
set _CABNAME=Setup_Report-%USERNAME%-%COMPUTERNAME%
set _WUETLPATH=%windir%\Logs\WindowsUpdate
set _WUOLDETLPATH=%windir%.old\Windows\Logs\WindowsUpdate
set _OLDPROGRAMDATA=%windir%.old\ProgramData
set _ROBOCOPY_LOG=%_PREFIX%robocopy.log
set _ROBOCOPY_PARAMS=/W:1 /R:1 /NP /LOG+:%_ROBOCOPY_LOG%
set _WINDOWSUPDATE=Windows_Update_Logs
set _CBS=cbs_logs
set _CBSDIR=CBS-Servicing
set _WINSTORE=Winstore
set _BatchDir=%~dp0
set _line=--------------------------------------------------------------------------------------------------------
set _Errorfile=%_PREFIX%Errorout.txt
set _PS4ormore=0
set _PS5=0
set _MBAM-SYSTEM=0


REM =================================================================================================================================================
REM Process command line arguments
:BeginParam
If %1. == . goto EndParam
If "%1" == "/?" (
	goto explainparams
	)
If /i "%1" == "-?" (
    goto explainparams
)

If /i "%1" == "min" (
	Set _Min=1
	Goto EndParam
	)
If /i "%1" == "max" (
	Set _Max=1
	Goto EndParam
         )
If /i "%1" == "datastore" set _DATASTORE=1
If /i "%1" == "upgrade" set _UPGRADE=1
If /i "%1" == "dxdiag" set _DXDIAG=1
If /i "%1" == "fileinfo" set _GETWINSXS=1
If /i "%1" == "appcompat" set _APPCOMPAT=1
If /i "%1" == "power" set _POWERCFG=1
shift
goto BeginParam

:explainparams
Echo The following parameters are accepted (enter without quotes and in any case separated by spaces only)
Echo.
Echo min - Get minimum data
Echo max - Get maximum data
Echo datastore - Get the Windows Update database
Echo upgrade - Get Windows upgrade/setup logs
Echo dxdiag - Get DxDiag report
Echo fileinfo - Get Winsxs and .Net file version info if system is running Powershell 5+
Echo appcompat - Get appcompat info
Echo power - Get detailed Powercfg output
Echo.
REM endlocal
Pause
GOTO Good_Bye

:EndParam

REM ----- Setup initial stuff

If exist %_TEMPDIR% Goto DIREXIST
mkdir %_TEMPDIR% >NUL 2>&1

REM OS Version checks
for /f "skip=1 tokens=2 delims=[]" %%G in ('ver') Do (
  for /f "tokens=2,3,4 delims=. " %%x in ("%%G") Do (
    set _major=%%x& set _minor=%%y& set _build=%%z 
  )
)

echo OS Version: %_major%.%_minor%.%_build%

set _WIN8_OR_LATER=0
set _WINBLUE_OR_LATER=0
set _WIN10=0

If %_major% == 10 set _Win10=1

IF %_major% GEQ 7 (
    set _WIN8_OR_LATER=1
    set _WINBLUE_OR_LATER=1
    
) ELSE IF %_major% == 6 (
    IF %_minor% GEQ 2 (
        set _WIN8_OR_LATER=1
    )    
    IF %_minor% GEQ 3 (
        set _WINBLUE_OR_LATER=1
    )
)

Rem Determine if Surface by seeing if Manafacture is Microsoft
for /f "tokens=1* delims==" %%a in (
  'wmic computersystem get manufacturer /value'
  ) do for /f "delims=" %%c in ("%%~b") do set "_manufacturer=%%c"
If /i "%_manufacturer%" == "microsoft" set _Surface=1
If /i "%_manufacturer%" == "microsoft corporation" set _Surface=1
if "%_Surface%" == "1" set _POWERCFG=1


Rem Check for any registry keys needed later. Set flag for existance.

Rem Check for MBAM
Rem Errorlevel 0 key exist Errorlevel 1 it does not
reg query "HKLM\SOFTWARE\Microsoft\MBAM Server" >nul 2>>nul
if %errorlevel% equ 0 set _MBAM-SYSTEM=1
reg query "HKLM\SOFTWARE\Microsoft\MBAM" >nul 2>>nul
if %errorlevel% equ 0 set _MBAM-SYSTEM=1



REM =================================================================================================================================================
REM Section For things that need to be started early
REM - Now lets setup Error output file header
Echo SetupReport version 1.24 > "%_Errorfile%"
Echo %_line% >> "%_Errorfile%"
Echo "Beginning error recording" >> "%_Errorfile%"
Echo %_line% >> "%_Errorfile%"
Echo Starting at---------------------------------------------- %time% >> "%_Errorfile%"
REM - Write script version info to MiscInfo
Echo SetupReport Version is 1.24 > %_PREFIX%MiscInfo.txt
Echo Command Line and Flag Values >> "%_Errorfile%"
Echo Min - %_Min% >> "%_Errorfile%"
Echo Max - %_Max% >> "%_Errorfile%"
Echo Datastore - %_DATASTORE% >> "%_Errorfile%"
Echo Upgrade - %_Upgrade% >> "%_Errorfile%"
Echo Dxdiag - %_DXDIAG% >> "%_Errorfile%"
Echo GetWinsxs - %_GETWINSXS% >> "%_Errorfile%"
Echo AppCompat - %_APPCOMPAT% >> "%_Errorfile%"
Echo Powercfg - %_POWERCFG% >> "%_Errorfile%"
Echo Surface - %_Surface% >> "%_Errorfile%"

If EXIST "%_Batchdir%\SummaryRep.txt" (
Echo Summary Report script does exist and will therefore be gathered >> "%_Errorfile%"
) ELSE (
Echo Summary Report does not exist and therefore will not be gathered >> "%_Errorfile%"
)

If EXIST "%_Batchdir%\GetEvents.txt" (
Echo Event log script does exist and therefore text versions of some event logs will be gathered >> "%_Errorfile%"
) ELSE (
Echo Event log script does not exist and therefore text versions of event logs will not be gathered >> "%_Errorfile%"
)

Echo ------------------------------------------------------ >> "%_Errorfile%"
If %_DXDIAG% == 1 start dxdiag /t %_PREFIX%DxDiag.txt >NUL
start msinfo32.exe /report "%_PREFIX%msinfo32.txt" >NUL
start msinfo32.exe /nfo  "%_PREFIX%msinfo32.nfo" >NUL
start gpresult.exe /H "%_PREFIX%GPResult.htm" /F >NUL
start /b whoami.exe /all > "%_PREFIX%Whoami.txt"
copy %windir%\system32\config\components %_PREFIX%reg_Components.HIV /y >NUL 2>> %_Errorfile%
REM - Get Powershell version in a file
PowerShell $PSVersion = ($PSVersionTable.PSVersion).Major ;  $PSVerFile = $env:_TEMPDIR+'\PSver'+$PSVersion+'.txt' ;  Out-File -FilePath $PSVerFile -InputObject $PSVersionTable.PSVersion
If exist %_TEMPDIR%\PSver4.txt set _PS4ormore=1
If exist %_TEMPDIR%\PSver5.txt set _PS4ormore=1
If exist %_TEMPDIR%\PSver5.txt set _PS5=1


REM =================================================================================================================================================
REM Section for custom entries for individual customers


REM =================================================================================================================================================
REM New logic flow with functions
REM
REM - App Compat check
If "%_APPCOMPAT%"=="1" set _AP=1
If "%_Max%"=="1" set _AP=1
If "%_AP%"=="1" Call :Appcompat
Call :WINUPDATE

If "%_PS4ormore%"=="1" Call :GeneralFileVersion

If "%_GETWINSXS%"=="1" set _WINSXSVER=1
If "%_PS4ormore%" NEQ "1" set _WINSXSVER=0
If "%_WINSXSVER%"=="1" call :WINSXSVERSION

CALL :CBS
If "%_UPGRADE%"=="1" set _UPG=1
If "%_Max%"=="1" set _UPG=1
If "%_UPG%"=="1" Call :SETUP
Call :EVENTLOG
If "%_Min%" NEQ "1" Call :MISCREG
If "%_Min%" NEQ "1" CALL :NETWORK
Call :PERMPOLICY
If "%_Min%" NEQ "1" Call :STORAGE
If "%_Min%" NEQ "1" CALL :PROCESS
CALL :BITLOCKER
CALL :MISC
CALL :ACTIVATION
CALL :DIRECTORY
If "%_Max%"=="1" set "%_POWERCFG%"="1"
If "%_POWERCFG%"=="1" CALL :POWER
If "%_SURFACE%"=="1" CALL :SURFACE
CALL :SLOWPROCESSING
GOTO ENDSECTION



:AppCompat
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM Section for App Compat Info  Only run if flag set
Echo Getting App Compat Info
Echo App Compat Section--------------------------------------- %time% >> "%_Errorfile%"
MD %_TEMPDIR%\Appcompat >NUL >> "%_Errorfile%"
reg export HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer %_TEMPDIR%\Appcompat\Reg_WindowsInstaller.txt /y >NUL 2>> %_Errorfile%
reg export "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags" %_TEMPDIR%\Appcompat\Reg_LocalMachine-AppCompatFlags.txt /y >NUL 2>> %_Errorfile%
reg export "HKEY_CURRENT_USER\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags" %_TEMPDIR%\Appcompat\Reg_CurrentUser-AppCompatFlags.txt /y >NUL 2>> %_Errorfile%
If exist %windir%\AppPatch\CompatAdmin.log copy %windir%/AppPatch\CompatAdmin.log %_TEMPDIR%\Appcompat\Apppatch-CompatAdmin.log /y >NUL 2>> %_Errorfile%
If exist %windir%\AppPatch64\CompatAdmin.log copy %windir%/AppPatch64\CompatAdmin.log %_TEMPDIR%\Appcompat\Apppatch64-CompatAdmin.log /y >NUL 2>> %_Errorfile%
xcopy %windir%\System32\Winevt\Logs\*compatibility*.evtx %_TEMPDIR%\Appcompat /Y /H >NUL 2>> %_Errorfile%
xcopy %windir%\System32\Winevt\Logs\*inventory*.evtx %_TEMPDIR%\Appcompat /Y /H >NUL 2>> %_Errorfile%
xcopy %windir%\System32\Winevt\Logs\*program-telemetry*.evtx %_TEMPDIR%\Appcompat /Y /H >NUL 2>> %_Errorfile%
reg.exe export "HKLM\SOFTWARE" %_TEMPDIR%\Appcompat\Reg_LocalMachine-Software.txt /y >NUL 2>> %_Errorfile%
reg.exe export "HKEY_CURRENT_USER\Software" %_TEMPDIR%\Appcompat\Reg_CurrentUser-Software.txt /y >NUL 2>> %_Errorfile%
dir /a /s /r "C:\Program Files (x86)" > %_TEMPDIR%\Appcompat\dir_ProgramFilesx86.txt 2>> %_Errorfile%
dir /a /s /r "C:\Program Files" > %_TEMPDIR%\Appcompat\dir_ProgramFiles.txt 2>> %_Errorfile%
dir /a /s /r "C:\Program Files (Arm)" > %_TEMPDIR%\Appcompat\dir_ProgramFilesArm.txt 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\ODBC" /s > %_TEMPDIR%\Appcompat\Reg_ODBC-Drivers.txt 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\WOW6432Node\ODBC" /s >> %_TEMPDIR%\Appcompat\Reg_ODBC-Drivers.txt 2>> %_Errorfile%
Exit /B

:WINUPDATE
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM SECTION - Windows Update
REM Put everything except ETL's in the main folder
Echo Windows Update Section----------------------------------- %time% >> "%_Errorfile%"
echo Getting Windows Update info
copy %windir%\windowsupdate.log %_PREFIX%WindowsUpdate.log /y >NUL 2>> %_Errorfile%
copy %windir%\SoftwareDistribution\ReportingEvents.log %_PREFIX%WindowsUpdate_ReportingEvents.log /y >NUL 2>> %_Errorfile%
if exist %localappdata%\microsoft\windows\windowsupdate.log copy %localappdata%\microsoft\windows\windowsupdate.log %_PREFIX%WindowsUpdatePerUser.log /y >NUL 2>> %_Errorfile%
if exist "%windir%\windowsupdate (1).log" copy "%windir%\windowsupdate (1).log" %_PREFIX%WindowsUpdate.Old.log /y >NUL 2>> %_Errorfile%
if exist %systemdrive%\Windows.old\Windows\SoftwareDistribution\ReportingEvents.log copy %systemdrive%\Windows.old\Windows\SoftwareDistribution\ReportingEvents.log %_PREFIX%Old.ReportingEvents.log /y >NUL 2>> %_Errorfile%
if exist %windir%\SoftwareDistribution\Plugins\7D5F3CBA-03DB-4BE5-B4B36DBED19A6833\TokenRetrieval.log copy %windir%\SoftwareDistribution\Plugins\7D5F3CBA-03DB-4BE5-B4B36DBED19A6833\TokenRetrieval.log %_PREFIX%WindowsUpdate_TokenRetrieval.log /y >NUL 2>> %_Errorfile%
if exist c:\WindowsUpdateVerbose.etl copy c:\WindowsUpdateVerbose.etl %_PREFIX%_WindowsUpdateVerbose.etl /y >NUL 2>> %_Errorfile%


REM UUP logs and action list xmls
REM robocopy %windir%\SoftwareDistribution\Download %_TEMPDIR%\UUP *.log *.xml %_ROBOCOPY_PARAMS%
reg export HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate %_PREFIX%WindowsUpdate_reg_wu.txt /y >NUL 2>> %_Errorfile%
reg export HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate %_PREFIX%WindowsUpdate_reg_wupolicy.txt /y >NUL 2>> %_Errorfile%
echo %_line% >> %_PREFIX%WindowsUpdate_reg_wupolicy-mdm.txt
echo. >> %_PREFIX%WindowsUpdate_reg_wupolicy-mdm.txt
echo -------Get MDM PolicyManager Info Now HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Update----------- >> %_PREFIX%WindowsUpdate_reg_wupolicy-mdm.txt
echo -------Note this will not exist on some systems---------- >> %_PREFIX%WindowsUpdate_reg_wupolicy-mdm.txt
echo. >> %_PREFIX%WindowsUpdate_reg_wupolicy-mdm.txt
echo %_line% >> %_PREFIX%WindowsUpdate_reg_wupolicy-mdm.txt
reg query "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Update" /s >> %_PREFIX%WindowsUpdate_reg_wupolicy-mdm.txt 2>> %_Errorfile%

reg export HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate %_PREFIX%WindowsUpdate_reg_wuhandlers.txt /y >NUL 2>> %_Errorfile%
reg save HKLM\SOFTWARE\Microsoft\sih %_PREFIX%reg_SIH.hiv >NUL 2>> %_Errorfile%
reg export HKLM\SOFTWARE\Microsoft\sih %_PREFIX%reg_SIH.txt >NUL 2>> %_Errorfile%
reg.exe query "HKLM\Software\microsoft\windows\currentversion\oobe" /s >> "%_PREFIX%reg_oobe.txt" 2>> %_Errorfile%

REM - Get Onesettings for Targetrelease, etc
Echo HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsSelfHost\OneSettings > %_PREFIX%WindowsUpdate_reg_Onesettings.txt 2>> %_Errorfile%
Echo %_line% >> %_PREFIX%WindowsUpdate_reg_Onesettings.txt 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\WindowsSelfHost\OneSettings" /s >> %_PREFIX%WindowsUpdate_reg_Onesettings.txt 2>> %_Errorfile%
Echo. >> %_PREFIX%WindowsUpdate_reg_Onesettings.txt 2>> %_Errorfile%
Echo HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Wosc\Client\Persistent\ClientState >> %_PREFIX%WindowsUpdate_reg_Onesettings.txt 2>> %_Errorfile%
Echo %_line% >> %_PREFIX%WindowsUpdate_reg_Onesettings.txt 2>> %_Errorfile%
reg.exe query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Wosc\Client\Persistent\ClientState /s >> %_PREFIX%WindowsUpdate_reg_Onesettings.txt 2>> %_Errorfile%


dir %windir%\SoftwareDistribution /a /s /r > %_PREFIX%WindowsUpdate_dir_softwaredistribution.txt 2>> %_Errorfile%
bitsadmin /list /allusers /verbose > %_PREFIX%bitsadmin.log 2>> %_Errorfile%
SCHTASKS /query /v /TN \Microsoft\Windows\WindowsUpdate\ > %_PREFIX%WindowsUpdate_ScheduledTasks.log 2>> %_Errorfile%

REM WU ETLs for Win10+

IF EXIST %_WUETLPATH% (

  if "%_FLUSH_LOGS%"=="1" (  
REM   echo Flushing WU ETL ...
      net stop usosvc >NUL 2>> %_Errorfile%
      net stop wuauserv >NUL 2>> %_Errorfile%
  )

  echo Getting Windows Update logs
   Powershell -ExecutionPolicy Bypass -command "Get-WindowsUpdateLog -LogPath %_PREFIX%WindowsUpdateETL_Converted.txt" >NUL 2>> %_Errorfile%
REM  robocopy %SystemDrive%\ %_TEMPDIR%\%_WINDOWSUPDATE% WindowsUpdateVerbose.etl %_ROBOCOPY_PARAMS%
)

REM Get Datastore if set
If "%_DATASTORE%"=="1" (
  md %_tempdir%\datastore >NUL 2>> %_Errorfile%  
  xcopy %windir%\softwaredistribution\datastore\*.* %_tempdir%\datastore /Y /H /E /C >NUL 2>> %_Errorfile%   
  )

If NOT "%_PS4ormore%"=="1" goto ENDWUFILE
REM Begin Windows Update file versions-----------------------------------
set _VERSION_SCRIPT=%TEMP%\WUFileVersion.ps1

echo # WUFileVersion.ps1 > %_VERSION_SCRIPT%
echo $binaries = @("wuaext.dll", "wuapi.dll", "wuaueng.dll", "wucltux.dll", "wudriver.dll", "wups.dll", "wups2.dll", "wusettingsprovider.dll", "wushareduxresources.dll", "wuwebv.dll", "wuapp.exe", "wuauclt.exe", "storewuauth.dll", "wuuhext.dll", "wuuhmobile.dll", "wuau.dll", "wuautoappupdate.dll") >> %_VERSION_SCRIPT%

echo foreach($file in $binaries) >> %_VERSION_SCRIPT%
echo { >> %_VERSION_SCRIPT%
echo     if(test-path "$env:windir\system32\$file")  >> %_VERSION_SCRIPT%
echo     {  >> %_VERSION_SCRIPT%
echo        $version = (Get-Command "$env:windir\system32\$file").FileVersionInfo >> %_VERSION_SCRIPT%
echo        write-host "$file : $($version.FileMajorPart).$($version.FileMinorPart).$($version.FileBuildPart).$($version.FilePrivatePart)" >> %_VERSION_SCRIPT%
echo     }  >> %_VERSION_SCRIPT%
echo } >> %_VERSION_SCRIPT%

echo $muis = @("wuapi.dll.mui", "wuaueng.dll.mui", "wucltux.dll.mui", "wusettingsprovider.dll.mui", "wushareduxresources.dll.mui") >> %_VERSION_SCRIPT%

echo foreach($file in $muis) >> %_VERSION_SCRIPT%
echo { >> %_VERSION_SCRIPT%
echo     if(test-path "$env:windir\system32\en-US\$file")  >> %_VERSION_SCRIPT%
echo     {  >> %_VERSION_SCRIPT%
echo        $version = (Get-Command "$env:windir\system32\en-US\$file").FileVersionInfo >> %_VERSION_SCRIPT%
echo        write-host "$file : $($version.FileMajorPart).$($version.FileMinorPart).$($version.FileBuildPart).$($version.FilePrivatePart)" >> %_VERSION_SCRIPT%
echo     }  >> %_VERSION_SCRIPT%
echo } >> %_VERSION_SCRIPT%

powershell -ExecutionPolicy Bypass -Command %_VERSION_SCRIPT% > %_PREFIX%WindowsUpdate_FileVersions.log 2>> %_Errorfile%
del %_VERSION_SCRIPT% 2>> %_Errorfile%
)
REM End Windows Update file versions--------------------------------
:ENDWUFILE

REM -------------------------------------------------------------
REM MUSE logs for Win10+
sc query usosvc >NUL 2>&1
IF NOT ERRORLEVEL 1 (
    
  if "%_FLUSH_LOGS%"=="1" (
      net stop usosvc >NUL 2>> %_Errorfile%
  )
  
  echo Copying MUSE logs
  robocopy %programdata%\UsoPrivate\UpdateStore %_TEMPDIR%\MUSE %_ROBOCOPY_PARAMS% /S >NUL
  robocopy %programdata%\USOShared\Logs %_TEMPDIR%\MUSE %_ROBOCOPY_PARAMS% /S >NUL
  SCHTASKS /query /v /TN \Microsoft\Windows\UpdateOrchestrator\ > %_TEMPDIR%\MUSE\updatetaskschedules.txt
  
  robocopy %_OLDPROGRAMDATA%\USOPrivate\UpdateStore %_TEMPDIR%\Windows.old\MUSE %_ROBOCOPY_PARAMS% /S >NUL
  robocopy %_OLDPROGRAMDATA%\USOShared\Logs %_TEMPDIR%\Windows.old\MUSE %_ROBOCOPY_PARAMS% /S >NUL
)


REM Also copy ETLs pre-upgrade to see history
IF EXIST %_WUOLDETLPATH% (
  robocopy %_WUOLDETLPATH% %_TEMPDIR%\Windows.old\WU *.etl %_ROBOCOPY_PARAMS% >NUL
)

Echo Getting Installed Updates

REM Get update id list with wmic
wmic qfe list full /format:texttable >> %_PREFIX%Hotfix-WMIC.txt 2>> %_Errorfile%
Echo %_line% >> %_PREFIX%Hotfix-WindowsUpdateDatabase.txt
Echo This file contains the summary output of Windows Update history and full output of Windows Update history >> %_PREFIX%Hotfix-WindowsUpdateDatabase.txt
Echo %_line% >> %_PREFIX%Hotfix-WindowsUpdateDatabase.txt
Echo. >> %_PREFIX%Hotfix-WindowsUpdateDatabase.txt
Echo %_line% >> %_PREFIX%Hotfix-WindowsUpdateDatabase.txt

REM Get Windows Update History info - Summary First

Echo Getting Update History

Echo Windows Update history Summary >> %_PREFIX%Hotfix-WindowsUpdateDatabase.txt
Echo Operation 1=Installation 2=Uninstallation 3=Other >> %_PREFIX%Hotfix-WindowsUpdateDatabase.txt
Echo %_line% >> %_PREFIX%Hotfix-WindowsUpdateDatabase.txt
Set _UPDATE_HISTORY=%TEMP%\updatehistory.ps1
Echo $Session = New-Object -ComObject "Microsoft.Update.Session" > %_UPDATE_HISTORY%
Echo $Searcher = $Session.CreateUpdateSearcher() >> %_UPDATE_HISTORY%
Echo $historyCount = $Searcher.GetTotalHistoryCount() >> %_UPDATE_HISTORY%
Echo $Searcher.QueryHistory(0, $historyCount) ^| Select-Object Date, Operation, Title >> %_UPDATE_HISTORY%
powershell -ExecutionPolicy Bypass -Command %_UPDATE_HISTORY% >> %_PREFIX%Hotfix-WindowsUpdateDatabase.txt 2>> %_Errorfile%
del %_UPDATE_HISTORY% 2>> %_Errorfile%

REM Get Windows Update History Info - All fields
Echo.  >> %_PREFIX%Hotfix-WindowsUpdateDatabase.txt
Echo %_line% >> %_PREFIX%Hotfix-WindowsUpdateDatabase.txt
Echo Get all fields in Windows Update database  >> %_PREFIX%Hotfix-WindowsUpdateDatabase.txt
Echo %_line% >> %_PREFIX%Hotfix-WindowsUpdateDatabase.txt
Set _UPDATE_HISTORY=%TEMP%\updatehistory.ps1
Echo $Session = New-Object -ComObject "Microsoft.Update.Session" > %_UPDATE_HISTORY%
Echo $Searcher = $Session.CreateUpdateSearcher() >> %_UPDATE_HISTORY%
Echo $historyCount = $Searcher.GetTotalHistoryCount() >> %_UPDATE_HISTORY%
Echo $Searcher.QueryHistory(0, $historyCount) ^| Select-Object * >> %_UPDATE_HISTORY%
powershell -ExecutionPolicy Bypass -Command %_UPDATE_HISTORY% >> %_PREFIX%Hotfix-WindowsUpdateDatabase.txt 2>> %_Errorfile%
del %_UPDATE_HISTORY% 2>> %_Errorfile%

REM Get Windows Update Configuration info
Set _UPDATE_CONFIGURATION=%TEMP%\updateconfiguration.ps1
Echo $MUSM = New-Object -ComObject "Microsoft.Update.ServiceManager" > %_UPDATE_CONFIGURATION%
Echo $MUSM.Services ^| select Name, IsDefaultAUService, OffersWindowsUpdates >> %_UPDATE_CONFIGURATION%
powershell -ExecutionPolicy Bypass -Command %_UPDATE_CONFIGURATION% > %_PREFIX%WindowsUpdateConfiguration.txt 2>> %_Errorfile%
del %_UPDATE_CONFIGURATION% 2>> %_Errorfile%
Echo %_line% >> "%_PREFIX%WindowsUpdateConfiguration.txt"
Echo          Now get all data >> "%_PREFIX%WindowsUpdateConfiguration.txt"
Echo %_line% >> "%_PREFIX%WindowsUpdateConfiguration.txt"
Echo $MUSM = New-Object -ComObject "Microsoft.Update.ServiceManager" > %_UPDATE_CONFIGURATION%
Echo $MUSM.Services >> %_UPDATE_CONFIGURATION% >> %_UPDATE_CONFIGURATION%
powershell -ExecutionPolicy Bypass -Command %_UPDATE_CONFIGURATION% >> %_PREFIX%WindowsUpdateConfiguration.txt 2>> %_Errorfile%
del %_UPDATE_CONFIGURATION% 2>> %_Errorfile%

Exit /B


:GeneralFileVersion
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM SECTION for general file version info

Echo General file version info section ----------------------- %time% >> "%_Errorfile%"
Echo Getting File Version Info

REM Begin Windows System32 DLL File Versions-----------------------------------
Echo Getting DLL Version Info
set _VERSION_SCRIPT=%TEMP%\system32dllfileversion.ps1
echo #generalfileversion.ps1 > %_VERSION_SCRIPT%
Echo Get-ChildItem -Path c:\windows\system32 -Filter *.dll -Recurse -ea 0^| >> %_VERSION_SCRIPT%
Echo    foreach-object { >> %_VERSION_SCRIPT%
Echo        [pscustomobject]@{ >> %_VERSION_SCRIPT%
Echo            Name = $_.FullName; >> %_VERSION_SCRIPT%
Echo            DateModified = $_.LastWriteTime; >> %_VERSION_SCRIPT%
Echo            Version = $_.VersionInfo.FileVersion; >> %_VERSION_SCRIPT%
Echo            Length = $_.length; >> %_VERSION_SCRIPT%
Echo        } >> %_VERSION_SCRIPT%
echo } ^| export-csv -notypeinformation -path %_PREFIX%File_Versions_WinSystem32_DLL.csv>> %_VERSION_SCRIPT%

powershell -ExecutionPolicy Bypass -Command %_VERSION_SCRIPT% 2>> %_Errorfile%
del %_VERSION_SCRIPT% 2>> %_Errorfile%
REM End Windows System32 DLL File Versions--------------------------------


REM Begin Windows System32 EXE File Versions-----------------------------------
Echo Getting EXE File Version Info
set _VERSION_SCRIPT=%TEMP%\system32exefileversion.ps1
echo #generalfileversion.ps1 > %_VERSION_SCRIPT%
Echo Get-ChildItem -Path c:\windows\system32 -Filter *.exe -Recurse -ea 0^| >> %_VERSION_SCRIPT%
Echo    foreach-object { >> %_VERSION_SCRIPT%
Echo        [pscustomobject]@{ >> %_VERSION_SCRIPT%
Echo            Name = $_.FullName; >> %_VERSION_SCRIPT%
Echo            DateModified = $_.LastWriteTime; >> %_VERSION_SCRIPT%
Echo            Version = $_.VersionInfo.FileVersion; >> %_VERSION_SCRIPT%
Echo            Length = $_.length; >> %_VERSION_SCRIPT%
Echo        } >> %_VERSION_SCRIPT%
echo } ^| export-csv -notypeinformation -path %_PREFIX%File_Versions_WinSystem32_EXE.csv>> %_VERSION_SCRIPT%

powershell -ExecutionPolicy Bypass -Command %_VERSION_SCRIPT% 2>> %_Errorfile%
del %_VERSION_SCRIPT% 2>> %_Errorfile%
REM End Windows System32 EXE File Versions--------------------------------

REM Begin Windows System32 SYS File Versions-----------------------------------
Echo Getting SYS File Versions
set _VERSION_SCRIPT=%TEMP%\system32SYSfileversion.ps1
echo #generalfileversion.ps1 > %_VERSION_SCRIPT%
Echo Get-ChildItem -Path c:\windows\system32 -Filter *.sys -Recurse  -ea 0^| >> %_VERSION_SCRIPT%
Echo    foreach-object { >> %_VERSION_SCRIPT%
Echo        [pscustomobject]@{ >> %_VERSION_SCRIPT%
Echo            Name = $_.FullName; >> %_VERSION_SCRIPT%
Echo            DateModified = $_.LastWriteTime; >> %_VERSION_SCRIPT%
Echo            Version = $_.VersionInfo.FileVersion; >> %_VERSION_SCRIPT%
Echo            Length = $_.length; >> %_VERSION_SCRIPT%
Echo        } >> %_VERSION_SCRIPT%
echo } ^| export-csv -notypeinformation -path %_PREFIX%File_Versions_WinSystem32_SYS.csv >> %_VERSION_SCRIPT%

powershell -ExecutionPolicy Bypass -Command %_VERSION_SCRIPT% 2>> %_Errorfile%
del %_VERSION_SCRIPT% 2>> %_Errorfile%
REM End Windows System32 SYS File Versions--------------------------------


REM Now get syswow64 files if on 64bit Windows

If not exist %windir%\syswow64\comctl32.dll goto NOT64BIT

REM Begin Windows Syswow64 DLL File Versions-----------------------------------
Echo Getting Syswow64 DLL Version Info
set _VERSION_SCRIPT=%TEMP%\Syswow64dllfileversion.ps1
echo #generalfileversion.ps1 > %_VERSION_SCRIPT%
Echo Get-ChildItem -Path c:\windows\syswow64 -Filter *.dll -Recurse -ea 0^| >> %_VERSION_SCRIPT%
Echo    foreach-object { >> %_VERSION_SCRIPT%
Echo        [pscustomobject]@{ >> %_VERSION_SCRIPT%
Echo            Name = $_.FullName; >> %_VERSION_SCRIPT%
Echo            DateModified = $_.LastWriteTime; >> %_VERSION_SCRIPT%
Echo            Version = $_.VersionInfo.FileVersion; >> %_VERSION_SCRIPT%
Echo            Length = $_.length; >> %_VERSION_SCRIPT%
Echo        } >> %_VERSION_SCRIPT%
echo } ^| export-csv -notypeinformation -path %_PREFIX%File_Versions_WinSysWOW64_DLL.csv>> %_VERSION_SCRIPT%

powershell -ExecutionPolicy Bypass -Command %_VERSION_SCRIPT% 2>> %_Errorfile%
del %_VERSION_SCRIPT% 2>> %_Errorfile%
REM End Windows Syswow64 DLL File Versions--------------------------------


REM Begin Windows Syswow64 EXE File Versions-----------------------------------
Echo Getting Syswow64 Exe File Version Info
set _VERSION_SCRIPT=%TEMP%\syswow64exefileversion.ps1
echo #generalfileversion.ps1 > %_VERSION_SCRIPT%
Echo Get-ChildItem -Path c:\windows\syswow64 -Filter *.exe -Recurse -ea 0^| >> %_VERSION_SCRIPT%
Echo    foreach-object { >> %_VERSION_SCRIPT%
Echo        [pscustomobject]@{ >> %_VERSION_SCRIPT%
Echo            Name = $_.FullName; >> %_VERSION_SCRIPT%
Echo            DateModified = $_.LastWriteTime; >> %_VERSION_SCRIPT%
Echo            Version = $_.VersionInfo.FileVersion; >> %_VERSION_SCRIPT%
Echo            Length = $_.length; >> %_VERSION_SCRIPT%
Echo        } >> %_VERSION_SCRIPT%
echo } ^| export-csv -notypeinformation -path %_PREFIX%File_Versions_WinSysWOW64_EXE.csv>> %_VERSION_SCRIPT%

powershell -ExecutionPolicy Bypass -Command %_VERSION_SCRIPT% 2>> %_Errorfile%
del %_VERSION_SCRIPT% 2>> %_Errorfile%
REM End Windows Syswow64 EXE File Versions--------------------------------

REM Begin Windows Syswow64 SYS File Versions-----------------------------------
Echo Getting Syswow64 SYS File Versions
set _VERSION_SCRIPT=%TEMP%\syswow64sysfileversion.ps1
echo #generalfileversion.ps1 > %_VERSION_SCRIPT%
Echo Get-ChildItem -Path c:\windows\syswow64 -Filter *.sys -Recurse  -ea 0^| >> %_VERSION_SCRIPT%
Echo    foreach-object { >> %_VERSION_SCRIPT%
Echo        [pscustomobject]@{ >> %_VERSION_SCRIPT%
Echo            Name = $_.FullName; >> %_VERSION_SCRIPT%
Echo            DateModified = $_.LastWriteTime; >> %_VERSION_SCRIPT%
Echo            Version = $_.VersionInfo.FileVersion; >> %_VERSION_SCRIPT%
Echo            Length = $_.length; >> %_VERSION_SCRIPT%
Echo        } >> %_VERSION_SCRIPT%
echo } ^| export-csv -notypeinformation -path %_PREFIX%File_Versions_WinSysWOW64_SYS.csv >> %_VERSION_SCRIPT%

powershell -ExecutionPolicy Bypass -Command %_VERSION_SCRIPT% 2>> %_Errorfile%
del %_VERSION_SCRIPT% 2>> %_Errorfile%
REM End Windows SysWOW64 SYS File Versions--------------------------------

:NOT64BIT
Exit /B


:WINSXSVERSION
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM Begin Winsxs DLL File Versions-----------------------------------
Echo Getting Winsxs File Version Info

Echo Winsxs and .Net file version info ----------------------- %time% >> "%_Errorfile%"
set _VERSION_SCRIPT=%TEMP%\winsxs-dll-fileversion.ps1
echo #generalfileversion.ps1 > %_VERSION_SCRIPT%
Echo Get-ChildItem -Path c:\windows\winsxs -Filter *.dll -Recurse  -ea 0^| >> %_VERSION_SCRIPT%
Echo    foreach-object { >> %_VERSION_SCRIPT%
Echo        [pscustomobject]@{ >> %_VERSION_SCRIPT%
Echo            Name = $_.FullName; >> %_VERSION_SCRIPT%
Echo            DateModified = $_.LastWriteTime; >> %_VERSION_SCRIPT%
Echo            Version = $_.VersionInfo.FileVersion; >> %_VERSION_SCRIPT%
Echo            Length = $_.length; >> %_VERSION_SCRIPT%
Echo        } >> %_VERSION_SCRIPT%
echo } ^| export-csv -notypeinformation -path %_PREFIX%File_Versions_Winsxs_DLL.csv >> %_VERSION_SCRIPT%

powershell -ExecutionPolicy Bypass -Command %_VERSION_SCRIPT% 2>> %_Errorfile%
del %_VERSION_SCRIPT% 2>> %_Errorfile%
REM End Winsxs DLL File Versions--------------------------------


REM Begin Winsxs SYS File Versions-----------------------------------
set _VERSION_SCRIPT=%TEMP%\winsxs-sys-fileversion.ps1
echo #generalfileversion.ps1 > %_VERSION_SCRIPT%
Echo Get-ChildItem -Path c:\windows\winsxs -Filter *.sys -Recurse -ea 0^| >> %_VERSION_SCRIPT%
Echo    foreach-object { >> %_VERSION_SCRIPT%
Echo        [pscustomobject]@{ >> %_VERSION_SCRIPT%
Echo            Name = $_.FullName; >> %_VERSION_SCRIPT%
Echo            DateModified = $_.LastWriteTime; >> %_VERSION_SCRIPT%
Echo            Version = $_.VersionInfo.FileVersion; >> %_VERSION_SCRIPT%
Echo            Length = $_.length; >> %_VERSION_SCRIPT%
Echo        } >> %_VERSION_SCRIPT%
echo } ^| export-csv -notypeinformation -path %_PREFIX%File_Versions_Winsxs_SYS.csv >> %_VERSION_SCRIPT%

powershell -ExecutionPolicy Bypass -Command %_VERSION_SCRIPT% 2>> %_Errorfile%
del %_VERSION_SCRIPT% 2>> %_Errorfile%
REM End Winsxs SYS File Versions--------------------------------


REM Begin Winsxs EXE File Versions-----------------------------------
set _VERSION_SCRIPT=%TEMP%\winsxs-exe-fileversion.ps1
echo #generalfileversion.ps1 > %_VERSION_SCRIPT%
Echo Get-ChildItem -Path c:\windows\winsxs -Filter *.exe -Recurse -ea 0^| >> %_VERSION_SCRIPT%
Echo    foreach-object { >> %_VERSION_SCRIPT%
Echo        [pscustomobject]@{ >> %_VERSION_SCRIPT%
Echo            Name = $_.FullName; >> %_VERSION_SCRIPT%
Echo            DateModified = $_.LastWriteTime; >> %_VERSION_SCRIPT%
Echo            Version = $_.VersionInfo.FileVersion; >> %_VERSION_SCRIPT%
Echo            Length = $_.length; >> %_VERSION_SCRIPT%
Echo        } >> %_VERSION_SCRIPT%
echo } ^| export-csv -notypeinformation -path %_PREFIX%File_Versions_Winsxs_EXE.csv>> %_VERSION_SCRIPT%

powershell -ExecutionPolicy Bypass -Command %_VERSION_SCRIPT% 2>> %_Errorfile%
del %_VERSION_SCRIPT% 2>> %_Errorfile%
REM End Winsxs EXE File Versions--------------------------------


REM Begin Reference Assemblies DLL File Versions-----------------------------------
Echo Getting Reference Assemblies File Version Info
set _VERSION_SCRIPT=%TEMP%\Refassm-dll-fileversion.ps1
echo #generalfileversion.ps1 > %_VERSION_SCRIPT%
Echo Get-ChildItem -Path "%programfiles%\Reference Assemblies" -Filter *.dll -Recurse  -ea 0^| >> %_VERSION_SCRIPT%
Echo    foreach-object { >> %_VERSION_SCRIPT%
Echo        [pscustomobject]@{ >> %_VERSION_SCRIPT%
Echo            Name = $_.FullName; >> %_VERSION_SCRIPT%
Echo            DateModified = $_.LastWriteTime; >> %_VERSION_SCRIPT%
Echo            Version = $_.VersionInfo.FileVersion; >> %_VERSION_SCRIPT%
Echo            Length = $_.length; >> %_VERSION_SCRIPT%
Echo        } >> %_VERSION_SCRIPT%
echo } ^| export-csv -notypeinformation -path %_PREFIX%File_Versions_Reference_Assemblies.csv >> %_VERSION_SCRIPT%

powershell -ExecutionPolicy Bypass -Command %_VERSION_SCRIPT% 2>> %_Errorfile%
del %_VERSION_SCRIPT% 2>> %_Errorfile%
REM End Reference Assemblies DLL File Versions--------------------------------


REM Microsoft.NET DLL File Versions-----------------------------------
Echo Getting Microsoft.NET DLL File Version Info
set _VERSION_SCRIPT=%TEMP%\Microsoft.NET-dll-fileversion.ps1
echo #generalfileversion.ps1 > %_VERSION_SCRIPT%
Echo Get-ChildItem -Path "%windir%\Microsoft.NET" -Filter *.dll -Recurse  -ea 0^| >> %_VERSION_SCRIPT%
Echo    foreach-object { >> %_VERSION_SCRIPT%
Echo        [pscustomobject]@{ >> %_VERSION_SCRIPT%
Echo            Name = $_.FullName; >> %_VERSION_SCRIPT%
Echo            DateModified = $_.LastWriteTime; >> %_VERSION_SCRIPT%
Echo            Version = $_.VersionInfo.FileVersion; >> %_VERSION_SCRIPT%
Echo            Length = $_.length; >> %_VERSION_SCRIPT%
Echo        } >> %_VERSION_SCRIPT%
echo } ^| export-csv -notypeinformation -path %_PREFIX%File_Versions_Microsoft.NET_DLL.csv >> %_VERSION_SCRIPT%

powershell -ExecutionPolicy Bypass -Command %_VERSION_SCRIPT% 2>> %_Errorfile%
del %_VERSION_SCRIPT% 2>> %_Errorfile%
REM End Microsoft.NET DLL File Versions--------------------------------

Exit /B


:CBS
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM SECTION CBS & PNP info, components hive, SideBySide hive, Iemain.log
Echo Windows CBS Section-------------------------------------- %time% >> "%_Errorfile%"
echo Getting CBS and servicing info
REM Copy complete logs folder
robocopy %windir%\logs %_TEMPDIR%\logs /W:1 /R:1 /NP /E /LOG+:%_ROBOCOPY_LOG% > nul
robocopy "%windir%\System32\LogFiles\setupcln" %_TEMPDIR%\System32-Logfiles\setupcln /W:1 /R:1 /NP /E /LOG+:%_ROBOCOPY_LOG% > nul
robocopy "%windir%\System32\LogFiles\wmi" %_TEMPDIR%\System32-Logfiles\wmi /W:1 /R:1 /NP /E /LOG+:%_ROBOCOPY_LOG% > nul
Md  %_TEMPDIR%\logs\cbs\Sessions
xcopy %windir%\servicing\sessions\*.* %_TEMPDIR%\logs\cbs\Sessions /y /h >NUL 2>> %_Errorfile%
copy %windir%\inf\*.log %_TEMPDIR%\logs\cbs /y >NUL 2>> %_Errorfile%
if exist %windir%\winsxs\poqexec.log copy %windir%\winsxs\poqexec.log %_TEMPDIR%\logs\cbs /y >NUL 2>> %_Errorfile%
if exist %windir%\winsxs\pending.xml copy %windir%\winsxs\pending.xml %_TEMPDIR%\logs\cbs /y >NUL 2>> %_Errorfile%
if exist %windir%\servicing\sessions\sessions.xml copy %windir%\servicing\sessions\sessions.xml %_TEMPDIR%\logs\cbs /y >NUL 2>> %_Errorfile%
if exist %windir%\Logs\MoSetup\UpdateAgent.log copy %windir%\Logs\MoSetup\UpdateAgent.log %_TEMPDIR%\logs\cbs /y >NUL 2>> %_Errorfile%
dir %windir%\Winsxs\temp /s /a /r > %_PREFIX%dir_winsxsTEMP.txt 2>> %_Errorfile%
dir %windir%\Winsxs /s /a /r > %_PREFIX%dir_winsxs.txt 2>> %_Errorfile%
dir %windir%\servicing\*.* /s /a /r > %_PREFIX%dir_servicing.txt 2>> %_Errorfile%
dir %windir%\system32\dism\*.* /s /a /r > %_PREFIX%dir_dism.txt 2>> %_Errorfile%
if exist %windir%\iemain.log copy %windir%\iemain.log %_TEMPDIR% /y
Echo Get-Packages in Table > "%_PREFIX%Dism_GetPackages.txt"
Dism /english /online /Get-Packages /Format:Table > "%_PREFIX%Dism_GetPackages.txt" 2>> %_Errorfile%
Echo %_line% >> "%_PREFIX%Dism_GetPackages.txt"
Echo Get-Packages in default format for script >> "%_PREFIX%Dism_GetPackages.txt"
Dism /english /online /Get-Packages >> "%_PREFIX%Dism_GetPackages.txt" 2>> %_Errorfile%

Echo Dism /online /Get-Packages ^| ForEach-Object { if ( $_ -match 'Package Identity') { $DismPackage = $_.substring(19); dism /online /get-packageinfo /packagename:$DismPackage } } > %tempdir%\_DISM_SCRIPT.ps1
powershell -ExecutionPolicy Bypass -Command %tempdir%\_DISM_SCRIPT.ps1 >> %_PREFIX%Dism_GetPackages.txt 2>> %_Errorfile%
del %tempdir%\_DISM_SCRIPT.ps1 2>> %_Errorfile%

Dism /english /online /Cleanup-Image /CheckHealth >> "%_PREFIX%Dism_CheckHealth.txt" 2>> %_Errorfile%
Dism /english /online /Get-Features > "%_PREFIX%Dism_GetFeatures.txt" 2>> %_Errorfile%
REM Powershell way Get-WmiObject Win32_OptionalFeature | Foreach {Write-host( "Name:{0}, InstallState:{1}" -f $_.Name,($_.InstallState -replace 1, "Installed" -replace 2, "Disabled" -replace 3, "Absent"))}
Dism /english /online /Get-Intl > "%_PREFIX%Dism_GetInternationalSettings.txt" 2>> %_Errorfile%
Dism /english /online /Get-Capabilities > "%_PREFIX%Dism_GetCapabilities.txt" 2>> %_Errorfile%
Dism /english /online /Get-CurrentEdition > "%_PREFIX%Dism_EditionInfo.txt" 2>> %_Errorfile%
Echo %_line% >> "%_PREFIX%Dism_EditionInfo.txt"
Dism /english /online /Get-TargetEditions >> "%_PREFIX%Dism_EditionInfo.txt" 2>> %_Errorfile%


REM Dump out any servicing packages not in current state of 80 (superseded) or 112 (Installed)


Rem Build PS script
set _PACKAGESTATE_SCRIPT=%TEMP%\Microsoft_packagestate_script.PS1
Echo $regPATH = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages" >> %_PACKAGESTATE_SCRIPT%
Echo $brokenUpdates = Get-ChildItem -PATH $regPATH -ErrorAction SilentlyContinue ^| Where-Object { $_.Name -like "*Rollup*" } #matches any Cumulative Update or Monthly Rollup >> %_PACKAGESTATE_SCRIPT%
Echo $brokenUpdates ^| Get-ItemProperty ^| Where-Object { $_.CurrentState -ne "80" -and $_.CurrentState -ne "112"} ^| Select-Object @{N='Cumulative/rollup package(s) in broken state'; E={$_.PSChildName};} ^| Format-Table -Wrap -AutoSize >> %_PACKAGESTATE_SCRIPT%
Echo $brokenUpdates = Get-ChildItem -PATH $regPATH -ErrorAction SilentlyContinue ^| Where-Object { $_.Name -match 'Package_for_KB[0-9]{7}~31bf3856ad364e35' } #matches any standalone KBs >> %_PACKAGESTATE_SCRIPT%
Echo $brokenUpdates ^| Get-ItemProperty ^| Where-Object { $_.CurrentState -ne "80" -and $_.CurrentState -ne "112"} ^| Select-Object @{N='Standalone package(s) in broken state'; E={$_.PSChildName};} ^| Format-Table -Wrap -AutoSize >> %_PACKAGESTATE_SCRIPT%
REM Build header for output file
Echo CBS servicing states, as seen on https://docs.microsoft.com/en-us/archive/blogs/tip_of_the_day/tip-of-the-day-cbs-servicing-states-chart-refresher >> "%_PREFIX%Servicing_PackageState.txt"
Echo This will list any packages not in a state of 80 (superseded) or 112 (Installed) >> "%_PREFIX%Servicing_PackageState.txt"
Echo If blank then none were found >> "%_PREFIX%Servicing_PackageState.txt"
Echo %_line% >> "%_PREFIX%Servicing_PackageState.txt"

powershell -ExecutionPolicy Bypass -Command %_PACKAGESTATE_SCRIPT% >> "%_PREFIX%Servicing_PackageState.txt" 2>> %_Errorfile%
del %_PACKAGESTATE_SCRIPT% 2>> %_Errorfile%


REM ----------------------------------------------------------------------
REM Now do a converted poqexec if it exist
If not exist %_TEMPDIR%\logs\cbs\poqexec.log goto NOTPOQ
set _POQEXEC_SCRIPT=%TEMP%\Poqexec.ps1

Echo $OutputFile = $env:_TEMPDIR+'\logs\CBS\poqexec_Converted.log' > %_POQEXEC_SCRIPT%
Echo. >> %_POQEXEC_SCRIPT%
Echo Set-Content -Path $OutputFile -Value "poqexec.log with FileTime converted to Date and Time" >> %_POQEXEC_SCRIPT%
Echo Add-Content -Path $OutputFile -Value "" >> %_POQEXEC_SCRIPT%
Echo. >> %_POQEXEC_SCRIPT%
Echo Add-Content -Path $OutputFile -Value "Date       Time     Entry" >> %_POQEXEC_SCRIPT%
Echo $poqexeclog = $env:_TEMPDIR+'\logs\CBS\poqexec.log' >> %_POQEXEC_SCRIPT%
Echo $ProcessingData = Get-Content $poqexeclog >> %_POQEXEC_SCRIPT%
Echo $ProcessingData ^| ForEach-Object { >> %_POQEXEC_SCRIPT%
Echo     $ProcessingLine = $_ >> %_POQEXEC_SCRIPT%
Echo     [Int64]$DateString = '0x'+$ProcessingLine.substring(0,15) >> %_POQEXEC_SCRIPT%
Echo     $ConvertedDate = [DateTime]::FromFileTime($DateString) >> %_POQEXEC_SCRIPT%
Echo     Add-Content -Path $OutputFile -Value $ConvertedDate`t$ProcessingLine >> %_POQEXEC_SCRIPT%
Echo     } >> %_POQEXEC_SCRIPT%

powershell -ExecutionPolicy Bypass -Command %_POQEXEC_SCRIPT% 2>> %_Errorfile%
del %_POQEXEC_SCRIPT% >NUL 2>> %_Errorfile%

:NOTPOQ

if not "%_WIN8_OR_LATER%"=="1" goto EXITCBS

REM ===============================================================================================================================
REM Section Windows Store info
REM Only run if Appx Server exist
If exist %SystemRoot%\system32\appxdeploymentserver.dll (
echo Getting Windows Store/Appx data
Echo Windows Store Section------------------------------------ %time% >> "%_Errorfile%"
md %_TEMPDIR%\%_WINSTORE%
if exist %temp%\winstore.log copy %temp%\winstore.log %_TEMPDIR%\%_WINSTORE%\winstore-Broker.log /y >NUL 2>> %_Errorfile%
if exist %userprofile%\AppData\Local\Packages\WinStore_cw5n1h2txyewy\AC\Temp\winstore.log copy %userprofile%\AppData\Local\Packages\WinStore_cw5n1h2txyewy\AC\Temp\winstore.log %_TEMPDIR%\%_WINSTORE% /y >NUL 2>> %_Errorfile%
reg query HKLM\Software\Policies\Microsoft\WindowsStore > %_TEMPDIR%\%_WINSTORE%\Store_reg_StorePolicy.txt 2>> %_Errorfile%
reg.exe export HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx %_PREFIX%reg_appx.txt /y >NUL 2>> %_Errorfile%

if "%_WIN8_OR_LATER%"=="1" (
    powershell -command "import-module appx;get-appxpackage -allusers" > %_PREFIX%GetAppxPackage.log 2>> %_Errorfile%
)

if "%_WINBLUE_OR_LATER%"=="1" (
    powershell -command "get-appxpackage -packagetype bundle" > %_PREFIX%GetAppxPackageBundle.log 2>> %_Errorfile%
    dism /english /online /Get-ProvisionedAppxPackages > %_PREFIX%GetAppxProvisioned.log 2>> %_Errorfile%
)
)


REM -------------------------------------------------------------
REM Section Delivery Optimizaton logs and powershell for Win10+

sc query dosvc >NUL 2>&1
IF NOT ERRORLEVEL 1 (  
  
  if "%_FLUSH_LOGS%"=="1" (  
      net stop usosvc >NUL 2>> %_Errorfile%
      net stop wuauserv >NUL 2>> %_Errorfile%
      net stop dosvc >NUL 2>> %_Errorfile%
  )    
  
  echo Getting DeliveryOptimization logs
  mkdir %_TEMPDIR%\logs\dosvc
  if exist C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Logs robocopy C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Logs %_TEMPDIR%\logs\dosvc *.log *.etl %_ROBOCOPY_PARAMS% /S >NUL
  if exist %windir%\SoftwareDistribution\DeliveryOptimization\SavedLogs robocopy %windir%\SoftwareDistribution\DeliveryOptimization\SavedLogs %_TEMPDIR%\logs\dosvc *.log *.etl %_ROBOCOPY_PARAMS% /S >NUL
  reg export HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization %_TEMPDIR%\logs\dosvc\registry_DeliveryOptimization.txt >NUL 2>> %_Errorfile%
  Powershell -ExecutionPolicy Bypass -command "Get-DeliveryOptimizationPerfSnap" > "%_TEMPDIR%\logs\dosvc\DeliveryOptimization_info.txt" 2>> %_Errorfile%
  Powershell -ExecutionPolicy Bypass -command "Get-DeliveryOptimizationStatus" >> "%_TEMPDIR%\logs\dosvc\DeliveryOptimization_info.txt" 2>> %_Errorfile%
)
:EXITCBS

Exit /B

:SETUP
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM Windows Setup/Upgrade logs
if "%_UPGRADE%"=="1" (
  Echo Windows setup section ----------------------------------- %time% >> "%_Errorfile%"
  echo Copying Setup and Upgrade logs
  mkdir %_TEMPDIR%\UpgradeSetup > NUL 2>&1
  mkdir %_TEMPDIR%\UpgradeSetup\win_Panther > NUL 2>&1
  mkdir %_TEMPDIR%\UpgradeSetup\sysprep_Panther > NUL 2>&1
  mkdir %_TEMPDIR%\UpgradeSetup\~bt_Panther > NUL 2>&1
  mkdir %_TEMPDIR%\UpgradeSetup\~bt_Rollback > NUL 2>&1
  mkdir %_TEMPDIR%\UpgradeSetup\win_Setup > NUL 2>&1
  if exist %windir%\logs\mosetup\bluebox.log copy %windir%\logs\mosetup\bluebox.log %_TEMPDIR%\UpgradeSetup\ /y >NUL 2>> %_Errorfile%
  if exist %systemdrive%\windows.old\windows\logs\mosetup\bluebox.log copy %systemdrive%\windows.old\windows\logs\mosetup\bluebox.log %_TEMPDIR%\UpgradeSetup\bluebox_windowsold.log /y >NUL 2>> %_Errorfile%
  if exist %systemdrive%\windows.old\windows\logs\mosetup\UpdateAgent.log copy %systemdrive%\windows.old\windows\logs\mosetup\UpdateAgent.log %_TEMPDIR%\UpgradeSetup\UpdateAgent_windowsold.log /y >NUL 2>> %_Errorfile%
  xcopy %windir%\Panther\*.* %_TEMPDIR%\UpgradeSetup\win_Panther /y /s /e /c >NUL 2>> %_Errorfile%
  if exist %windir%\system32\sysprep\panther xcopy %windir%\system32\sysprep\panther\*.* %_TEMPDIR%\UpgradeSetup\sysprep_Panther /e /y >NUL 2>> %_Errorfile%

IF EXIST %systemdrive%\$Windows.~BT (
    if exist %systemdrive%\$Windows.~BT\Sources\Panther xcopy /s /e /c %systemdrive%\$Windows.~BT\Sources\Panther\*.* %_TEMPDIR%\UpgradeSetup\~bt_Panther /y >NUL 2>> %_Errorfile%
    if exist %systemdrive%\$Windows.~BT\Sources\Rollback xcopy /s /e /c %systemdrive%\$Windows.~BT\Sources\Rollback\*.* %_TEMPDIR%\UpgradeSetup\~bt_Rollback /y >NUL 2>> %_Errorfile%
    dir /a /s /r %systemdrive%\$Windows.~BT > %_TEMPDIR%\UpgradeSetup\Dir_WindowsBT.txt 2>> %_Errorfile%
 ) ELSE ( 
    if exist D:\$Windows.~BT\Sources\Panther xcopy /s /e /c D:\$Windows.~BT\Sources\Panther\*.* %_TEMPDIR%\UpgradeSetup\~bt_Panther /y >NUL 2>> %_Errorfile%
    if exist D:\$Windows.~BT\Sources\Rollback xcopy /s /e /c D:\$Windows.~BT\Sources\Rollback\*.* %_TEMPDIR%\UpgradeSetup\~bt_Rollback /y >NUL 2>> %_Errorfile%
    if exist D:\$Windows.~BT dir /a /s /r D:\$Windows.~BT > %_TEMPDIR%\UpgradeSetup\Dir_WindowsBT.txt 2>> %_Errorfile%
 )

  if exist "%userprofile%\Local Settings\Application Data\Microsoft\WebSetup\Panther" if not exist %_TEMPDIR%\UpgradeSetup\WebSetup-Panther md %_TEMPDIR%\UpgradeSetup\WebSetup-Panther /y >NUL 2>> %_Errorfile%
  if exist "%userprofile%\Local Settings\Application Data\Microsoft\WebSetup\Panther" robocopy "%userprofile%\Local Settings\Application Data"\Microsoft\WebSetup\Panther %_TEMPDIR%\UpgradeSetup\WebSetup-Panther *.* /MIR /XF *.png *.js *.tmp *.exe >NUL 2>> %_Errorfile%
  if exist %localappdata%\microsoft\Microsoft\Windows\PurchaseWindowsLicense if not exist %_TEMPDIR%\UpgradeSetup\PurchaseWindowsLicense md %_TEMPDIR%\UpgradeSetup\PurchaseWindowsLicense 2>> %_Errorfile%
  if exist %localappdata%\Microsoft\Windows\PurchaseWindowsLicense copy %localappdata%\microsoft\Microsoft\Windows\PurchaseWindowsLicense\PurchaseWindowsLicense.log %_TEMPDIR%\UpgradeSetup\PurchaseWindowsLicense /y 2>> %_Errorfile%
  if exist "%localappdata%\microsoft\Microsoft\Windows\Windows Anytime Upgrade" if not exist %_TEMPDIR%\UpgradeSetup\WindowsAnytimeUpgrade md %_TEMPDIR%\UpgradeSetup\WindowsAnytimeUpgrade 2>> %_Errorfile%
  if exist "%localappdata%\Microsoft\Windows\Windows Anytime Upgrade" copy "%localappdata%\microsoft\Microsoft\Windows\Windows Anytime Upgrade\upgrade.log" %_TEMPDIR%\UpgradeSetup\WindowsAnytimeUpgrade 2>> %_Errorfile%
  xcopy %windir%\setup\*.* "%_TEMPDIR%\UpgradeSetup\win_Setup\" /E >NUL 2>> %_Errorfile%
  if exist %windir%\setupact.log copy %windir%\setupact.log "%_TEMPDIR%\UpgradeSetup\setupact-windows.log" /y >NUL 2>> %_Errorfile%
  If exist %windir%\System32\LogFiles\setupcln\setupact.log copy %windir%\System32\LogFiles\setupcln\setupact.log "%_TEMPDIR%\UpgradeSetup\setupact-setupcln.log" /y >NUL 2>> %_Errorfile%
)


REM - Get Sysrest logs for PBR issues
If exist C:\$SysReset\Logs (
   md %_TEMPDIR%\UpgradeSetup\Sysreset
   xcopy /s /e /c c:\$SysReset\Logs\*.* %_TEMPDIR%\UpgradeSetup\Sysreset >NUL 2>> %_Errorfile%
)

REM MDT logs
if exist "%systemroot%\temp\deploymentlogs" (
mkdir %_TEMPDIR%\UpgradeSetup\deployment_logs
xcopy /s /e /c "%systemroot%\temp\deploymentlogs\*.*"  %_TEMPDIR%\UpgradeSetup\deployment_logs\ /y >NUL 2>> %_Errorfile%
)
If exist %systemdrive%\minint (
mkdir %_TEMPDIR%\UpgradeSetup\minint
xcopy /s /e /c %systemdrive%\minint\*.* %_TEMPDIR%\UpgradeSetup\minint /y >NUL 2>> %_Errorfile%
)
If exist %temp%\smstslog\smsts.log copy %temp%\smstslog\smsts.log %_TEMPDIR%\UpgradeSetup\curentusertemp-smsts.log >NUL 2>> %_Errorfile%
If exist %systemdrive%\users\administrator\appdata\local\temp\smstslog\smsts.log copy %systemdrive%\users\administrator\appdata\local\temp\smstslog\smsts.log %_TEMPDIR%\UpgradeSetup\admintemp-smsts.log >NUL 2>> %_Errorfile%

reagentc.exe /info > %_PREFIX%reagentc.txt 2>> %_Errorfile%

REM ========================================================================================================================
REM Section WDS
If exist %windir%\system32\wdsutil.exe (
Echo Getting WDS info
Echo WDS section --------------------------------------------- %time% >> "%_Errorfile%"
md %_TEMPDIR%\WDS
xcopy %windir%\System32\winevt\Logs\*deployment-services*.* %_TEMPDIR%\WDS /Y /H >NUL 2>> %_Errorfile%
WDSUTIL /get-server /show:all /detailed > %_TEMPDIR%\WDS\WDS-Get-Server.txt 2>> %_Errorfile%
WDSUTIL /get-transportserver /show:config > %_TEMPDIR%\WDS\WDS-Get-Transportserver.txt 2>> %_Errorfile%
)


REM -----------------------------------------------------------------------------
REM Get some SCCM logs and other data if they exist
If not exist "%windir%\ccm\logs\ccmexec.log" goto EXITSETUP
md %_TEMPDIR%\SCCM
xcopy %windir%\ccm\logs\*.* %_TEMPDIR%\sccm /y /s /e /c >NUL 2>> %_Errorfile%

Powershell -ExecutionPolicy Bypass -command "Get-WmiObject -Namespace ROOT\ccm\Policy\Machine\ActualConfig -Class CCM_SoftwareUpdatesClientConfig > %_TEMPDIR%\sccm\SoftwareUpdatesClientConfig.txt" 2>> %_Errorfile%
:EXITSETUP

Exit /B


REM -------------------------------Removed as we should never need---------------------------
REM echo -------------------------------------------
REM echo Copying token cache and license store to temporary folder ...
REM echo -------------------------------------------
REM copy %windir%\ServiceProfiles\LocalService\AppData\Local\Microsoft\WSLicense\tokens.dat %_TEMPDIR% /y
REM copy %windir%\SoftwareDistribution\Plugins\7D5F3CBA-03DB-4BE5-B4B36DBED19A6833\117CAB2D-82B1-4B5A-A08C-4D62DBEE7782.cache %_TEMPDIR% /y
REM ------------------------------Removed--------------------------


:EVENTLOG
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM - Get all event logs and convert some if getevents script is available
echo Getting Event Logs
Echo Windows event logs -------------------------------------- %time% >> "%_Errorfile%"
robocopy %windir%\system32\winevt\logs %_TEMPDIR%\eventlogs /W:1 /R:1 /NP /E /LOG+:%_ROBOCOPY_LOG% > nul 2>> %_Errorfile%

REM - Now output txt and CSV for some
cd /d %_TEMPDIR%
cscript.exe //e:vbs "%_Batchdir%\GetEvents.txt" "System" /channel /TXT /CSV /noextended >NUL 2>> %_Errorfile%
cscript.exe //e:vbs "%_Batchdir%\GetEvents.txt" "Application" /channel /TXT /CSV /noextended >NUL 2>> %_Errorfile%
cscript.exe //e:vbs "%_Batchdir%\GetEvents.txt" "Setup" /channel /TXT /CSV /noextended >NUL 2>> %_Errorfile%
Rem
cscript.exe //e:vbs "%_Batchdir%\GetEvents.txt" "Microsoft-Windows-WMI-Activity/Operational" /channel /TXT /noextended >NUL 2>> %_Errorfile%
cscript.exe //e:vbs "%_Batchdir%\GetEvents.txt" "Microsoft-Windows-Setup/Analytic" /channel /TXT /noextended >NUL 2>> %_Errorfile%
cscript.exe //e:vbs "%_Batchdir%\GetEvents.txt" "General Logging" /channel /TXT /noextended >NUL 2>> %_Errorfile%
cscript.exe //e:vbs "%_Batchdir%\GetEvents.txt" "HardwareEvents" /channel /TXT /noextended >NUL 2>> %_Errorfile%
cscript.exe //e:vbs "%_Batchdir%\GetEvents.txt" "Microsoft-Windows-Crashdump/Operational" /channel /TXT /noextended >NUL 2>> %_Errorfile%
cscript.exe //e:vbs "%_Batchdir%\GetEvents.txt" "Microsoft-Windows-Dism-Api/Analytic" /channel /TXT /noextended >NUL 2>> %_Errorfile%
cscript.exe //e:vbs "%_Batchdir%\GetEvents.txt" "Microsoft-Windows-EventLog-WMIProvider/Debug" /channel /TXT /noextended >NUL 2>> %_Errorfile%
cscript.exe //e:vbs "%_Batchdir%\GetEvents.txt" "Microsoft-Windows-EventLog/Analytic" /channel /TXT /noextended >NUL 2>> %_Errorfile%
cscript.exe //e:vbs "%_Batchdir%\GetEvents.txt" "Microsoft-Windows-EventLog/Debug" /channel /TXT /noextended >NUL 2>> %_Errorfile%
cscript.exe //e:vbs "%_Batchdir%\GetEvents.txt" "Microsoft-Windows-Store/Operational" /channel /TXT /noextended >NUL 2>> %_Errorfile%
cscript.exe //e:vbs "%_Batchdir%\GetEvents.txt" "Microsoft-Windows-Store/Operational" /channel /TXT /CSV /noextended >NUL 2>> %_Errorfile%


cd /d %_Batchdir%

REM wevtutil.exe epl System "SystemLogLast30days.evtx" /q:"*[System[TimeCreated[timediff(@SystemTime) <=2592000000]]]" /ow:true

Exit /B     


:MISCREG
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM Section Misc Registry Info
echo Getting Misc Registry Keys
Echo Misc registry keys section ------------------------------ %time% >> "%_Errorfile%"
reg export HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\MUI\UILanguages %_PREFIX%reg_langpack.txt /y >NUL 2>> %_Errorfile%
reg export HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services %_PREFIX%reg_services.txt /y >NUL 2>> %_Errorfile%
reg.exe save "HKLM\SYSTEM\CurrentControlSet\services" "%_PREFIX%reg_services.hiv" >NUL 2>> %_Errorfile%
reg.exe query "HKLM\Software\Microsoft\Windows NT\CurrentVersion" >> "%_PREFIX%reg_CurrentVersion.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\Software\Microsoft\Windows\CurrentVersion" >> "%_PREFIX%reg_CurrentVersion.TXT" 2>> %_Errorfile%
reg.exe query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v BuildLab > %_PREFIX%reg_BuildInfo.txt 2>> %_Errorfile%
reg.exe query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v BuildLabEx >> %_PREFIX%reg_BuildInfo.txt 2>> %_Errorfile%
reg.exe query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v UBR >> %_PREFIX%reg_BuildInfo.txt 2>> %_Errorfile%
reg.exe query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName >> %_PREFIX%reg_BuildInfo.txt 2>> %_Errorfile%
reg.exe query HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModel /v Version > %_PREFIX%reg_AppModelVersion.txt 2>> %_Errorfile%
reg.exe export HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FirmwareResources %_PREFIX%reg_FirmwareResources.txt /y >NUL 2>> %_Errorfile%
reg.exe export "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Superfetch" %_PREFIX%reg_superfetch.txt /y >NUL 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s >> "%_PREFIX%reg_Uninstall.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s >> "%_PREFIX%reg_Uninstall.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Services\kbdhid" >> "%_PREFIX%reg_Recovery.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Services\i8042prt" >> "%_PREFIX%reg_Recovery.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\System\CurrentControlSet\Control\CrashControl" >> "%_PREFIX%reg_Recovery.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\System\CurrentControlSet\Control\Session Manager" >> "%_PREFIX%reg_Recovery.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\System\CurrentControlSet\Control\Session Manager\Memory Management" >> "%_PREFIX%reg_Recovery.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\Software\Microsoft\Windows NT\CurrentVersion\AeDebug" >> "%_PREFIX%reg_Recovery.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options" /s >> "%_PREFIX%reg_Recovery.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\Software\Microsoft\Windows\Windows Error Reporting" /s >> "%_PREFIX%reg_Recovery.TXT" 2>> %_Errorfile%
reg.exe query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" >> "%_PREFIX%reg_Startup.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\Software\Microsoft\Windows\CurrentVersion\Runonce" >> "%_PREFIX%reg_Startup.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ShellServiceObjectDelayLoad" >> "%_PREFIX%reg_Startup.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /s >> "%_PREFIX%reg_TimeZone.txt" 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Time Zones" /s >> "%_PREFIX%reg_TimeZone.txt" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /s >> "%_PREFIX%reg_TermServices.txt" 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SvcHost" /s > "%_PREFIX%reg_SVCHost.txt" 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" /s > "%_PREFIX%reg_ProfileList.txt" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\DriverDatabase" /s > "%_PREFIX%reg_DriverDatabase.txt" 2>> %_Errorfile%
reg.exe save "HKLM\SYSTEM\DriverDatabase" "%_PREFIX%reg_DriverDatabase.hiv" >NUL 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP" /s > "%_PREFIX%reg_.NET-Setup.txt" 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\Windows\currentversion\winevt" /s > "%_PREFIX%reg_Winevt.txt" 2>> %_Errorfile%
reg.exe save "HKLM\SOFTWARE\Microsoft\Windows\currentversion\winevt" "%_PREFIX%reg_Winevt.hiv" >NUL 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\Setup" /s >> "%_PREFIX%reg_Setup.txt" 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\OOBE" >> "%_PREFIX%reg_Setup.txt" 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State" >> "%_PREFIX%reg_Setup.txt" 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\Sysprep" /s >> "%_PREFIX%reg_Setup.txt" 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\SysPrepExternal" /s >> "%_PREFIX%reg_Setup.txt" 2>> %_Errorfile%
reg.exe export "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags" "%_PREFIX%reg_LocalMachine-AppCompatFlags.txt" /y >NUL 2>> %_Errorfile%
reg.exe export "HKEY_CURRENT_USER\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags" "%_PREFIX%reg_CurrentUser-AppCompatFlags.txt" /y >NUL 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\SQMClient" /s > %_PREFIX%reg_SQMClient.txt 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\PolicyManager" /s > %_PREFIX%reg_PolicyManager.txt 2>> %_Errorfile%
copy %windir%\system32\config\drivers "%_PREFIX%drivers.hiv" >NUL 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Control\WMI" /s > "%_PREFIX%reg_WMI.txt" 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" /s > %_PREFIX%reg_SoftwareProctectionPlatform.txt 2>> %_Errorfile%
reg.exe query "HKEY_USERS\S-1-5-20\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" /s >> %_PREFIX%reg_SoftwareProctectionPlatform.txt 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" /s > %_PREFIX%reg_SecurityInfo.txt 2>> %_Errorfile%
Echo %_line% >> %_PREFIX%reg_SecurityInfo.txt
reg.exe query "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" /s >> %_PREFIX%reg_SecurityInfo.txt 2>> %_Errorfile%
Echo %_line% >> %_PREFIX%reg_SecurityInfo.txt
reg.exe query "HKLM\System\CurrentControlSet\Control\SecurityProviders" /s >> %_PREFIX%reg_SecurityInfo.txt 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication" /s > %_PREFIX%reg_Software_Authentication.txt 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Control\Power" /s > %_PREFIX%reg_Power.txt 2>> %_Errorfile%


REM - Get Windows Defender info if running on Windows 10
If %_WIN10%==1 (
reg.exe query "HKLM\SOFTWARE\Microsoft\Windows Defender" /s > %_PREFIX%Reg_Defender.txt 2>> %_Errorfile%
)

Exit /B



:NETWORK
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM Section Network Info
Echo Getting Networking Info
Echo Network info section ------------------------------------ %time% >> "%_Errorfile%"
if exist %windir%\System32\drivers\etc\hosts copy %windir%\System32\drivers\etc\hosts %_PREFIX%NETWORK_hosts.txt /y >NUL 2>> %_Errorfile%
ipconfig /all >> %_PREFIX%NETWORK_TCPIP_info.TXT 2>> %_Errorfile%
route print  >> %_PREFIX%NETWORK_TCPIP_info.TXT 2>> %_Errorfile%
arp -a >> %_PREFIX%NETWORK_TCPIP_info.TXT 2>> %_Errorfile%
netstat -nato >> %_PREFIX%NETWORK_TCPIP_info.TXT 2>> %_Errorfile%
netstat -anob >> %_PREFIX%NETWORK_TCPIP_info.TXT 2>> %_Errorfile%
netstat -es >> %_PREFIX%NETWORK_TCPIP_info.TXT 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\TCPIP" /s >> "%_PREFIX%NETWORK_TCPIP_reg_output.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6" /s >> "%_PREFIX%NETWORK_TCPIP_reg_output.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Services\tcpipreg" /s >> "%_PREFIX%NETWORK_TCPIP_reg_output.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Services\iphlpsvc" /s >> "%_PREFIX%NETWORK_TCPIP_reg_output.TXT" 2>> %_Errorfile%
netsh winhttp show proxy > %_PREFIX%NETWORK_Proxy.TXT 2>> %_Errorfile%
netsh int tcp show global >> %_PREFIX%NETWORK_TCPIP_OFFLOAD.TXT 2>> %_Errorfile%
netsh int ipv4 show offload >> %_PREFIX%NETWORK_TCPIP_OFFLOAD.TXT 2>> %_Errorfile%
netstat -nato -p tcp >> %_PREFIX%NETWORK_TCPIP_OFFLOAD.TXT 2>> %_Errorfile%
netsh int show int >> %_PREFIX%NETWORK_TCPIP_netsh_info.TXT 2>> %_Errorfile%
netsh int ip show int >> %_PREFIX%NETWORK_TCPIP_netsh_info.TXT 2>> %_Errorfile%
netsh int ip show address >> %_PREFIX%NETWORK_TCPIP_netsh_info.TXT 2>> %_Errorfile%
netsh int ip show config >> %_PREFIX%NETWORK_TCPIP_netsh_info.TXT 2>> %_Errorfile%
netsh int ip show dns >> %_PREFIX%NETWORK_TCPIP_netsh_info.TXT 2>> %_Errorfile%
netsh int ip show joins >> %_PREFIX%NETWORK_TCPIP_netsh_info.TXT 2>> %_Errorfile%
netsh int ip show offload >> %_PREFIX%NETWORK_TCPIP_netsh_info.TXT 2>> %_Errorfile%
netsh int ip show wins >> %_PREFIX%NETWORK_TCPIP_netsh_info.TXT 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\Dhcp" /s >> "%_PREFIX%NETWORK_DhcpClient_reg_.TXT" 2>> %_Errorfile%
ipconfig.exe /displaydns >> "%_PREFIX%NETWORK_DnsClient_ipconfig-displaydns.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\Dnscache" /s >> "%_PREFIX%NETWORK_DnsClient_reg_.TXT" 2>> %_Errorfile%
nbtstat.exe -c >> "%_PREFIX%NETWORK_WinsClient_nbtstat-output.TXT" 2>> %_Errorfile%
nbtstat.exe -n >> "%_PREFIX%NETWORK_WinsClient_nbtstat-output.TXT" 2>> %_Errorfile%
net.exe config workstation >> %_PREFIX%NETWORK_SmbClient_info_net.TXT 2>> %_Errorfile%
net.exe statistics workstation >> %_PREFIX%NETWORK_SmbClient_info_net.TXT 2>> %_Errorfile%
net.exe use >> %_PREFIX%NETWORK_SmbClient_info_net.TXT 2>> %_Errorfile%
net.exe accounts >> %_PREFIX%NETWORK_SmbClient_info_net.TXT 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\LanManWorkstation" /s >> "%_PREFIX%NETWORK_SmbClient_reg_output.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\lmhosts" /s >> "%_PREFIX%NETWORK_SmbClient_reg_output.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\MrxSmb" /s >> "%_PREFIX%NETWORK_SmbClient_reg_output.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\MrxSmb10" /s >> "%_PREFIX%NETWORK_SmbClient_reg_output.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\MrxSmb20" /s >> "%_PREFIX%NETWORK_SmbClient_reg_output.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\MUP" /s >> "%_PREFIX%NETWORK_SmbClient_reg_output.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\NetBIOS" /s >> "%_PREFIX%NETWORK_SmbClient_reg_output.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\NetBT" /s >> "%_PREFIX%NETWORK_SmbClient_reg_output.TXT" 2>> %_Errorfile%
reg.exe query "HKCU\Network" /s >> "%_PREFIX%NETWORK_SmbClient_reg_output.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Control\NetworkProvider" /s >> "%_PREFIX%NETWORK_SmbClient_reg_output.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\Rdbss" /s >> "%_PREFIX%NETWORK_SmbClient_reg_output.TXT" 2>> %_Errorfile%
net.exe accounts >> %_PREFIX%NETWORK_SmbServer_info_net.txt 2>> %_Errorfile%
net.exe config server >> %_PREFIX%NETWORK_SmbServer_info_net.txt 2>> %_Errorfile%
net.exe session >> %_PREFIX%NETWORK_SmbServer_info_net.txt 2>> %_Errorfile%
net.exe files >> %_PREFIX%NETWORK_SmbServer_info_net.txt 2>> %_Errorfile%
net.exe share >> %_PREFIX%NETWORK_SmbServer_info_net.txt 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\LanManServer" /s >> "%_PREFIX%NETWORK_SmbServer_reg_output.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\SRV2" /s >> "%_PREFIX%NETWORK_SmbServer_reg_output.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\SRVNET" /s >> "%_PREFIX%NETWORK_SmbServer_reg_output.TXT" 2>> %_Errorfile%
netsh.exe rpc show int >> %_PREFIX%NETWORK_RPC_netsh_output.TXT 2>> %_Errorfile%
netsh.exe rpc show settings >> %_PREFIX%NETWORK_RPC_netsh_output.TXT 2>> %_Errorfile%
netsh.exe rpc filter show filter >> %_PREFIX%NETWORK_RPC_netsh_output.TXT 2>> %_Errorfile%
reg.exe query "HKLM\Software\Microsoft\Rpc" /s >> "%_PREFIX%NETWORK_RPC_reg.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Services\RpcEptMapper" /s >> "%_PREFIX%NETWORK_RPC_reg.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Services\RpcLocator" /s >> "%_PREFIX%NETWORK_RPC_reg.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Services\RpcSs" /s >> "%_PREFIX%NETWORK_RPC_reg.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess" /s >> "%_PREFIX%NETWORK_Firewall_reg_.TXT" 2>> %_Errorfile%
netsh.exe firewall show allowedprogram >> %_PREFIX%NETWORK_Firewall_netsh.TXT 2>> %_Errorfile%
netsh.exe firewall show config >> %_PREFIX%NETWORK_Firewall_netsh.TXT 2>> %_Errorfile%
netsh.exe firewall show currentprofile >> %_PREFIX%NETWORK_Firewall_netsh.TXT 2>> %_Errorfile%
netsh.exe firewall show icmpsetting >> %_PREFIX%NETWORK_Firewall_netsh.TXT 2>> %_Errorfile%
netsh.exe firewall show logging >> %_PREFIX%NETWORK_Firewall_netsh.TXT 2>> %_Errorfile%
netsh.exe firewall show multicastbroadcastresponse >> %_PREFIX%NETWORK_Firewall_netsh.TXT 
netsh.exe firewall show notifications >> %_PREFIX%NETWORK_Firewall_netsh.TXT 2>> %_Errorfile%
netsh.exe firewall show opmode >> %_PREFIX%NETWORK_Firewall_netsh.TXT 2>> %_Errorfile%
netsh.exe firewall show portopening >> %_PREFIX%NETWORK_Firewall_netsh.TXT 2>> %_Errorfile%
netsh.exe firewall show service >> %_PREFIX%NETWORK_Firewall_netsh.TXT 2>> %_Errorfile%
netsh.exe firewall show state >> %_PREFIX%NETWORK_Firewall_netsh.TXT 2>> %_Errorfile%
netsh.exe ipsec dynamic show all >> %_PREFIX%NETWORK_IPsec_netsh_dynamic.TXT 2>> %_Errorfile%
netsh.exe ipsec static show all >> %_PREFIX%NETWORK_IPsec_netsh_static.TXT 2>> %_Errorfile%
netsh ipsec static exportpolicy %_PREFIX%NETWORK_IPsec_netsh_LocalPolicyExport.ipsec.TXT 2>> %_Errorfile%
netsh wlan show all > %_PREFIX%NETWORK_Wireless_netsh.TXT 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Policies\Microsoft\Windows\IPSec" /s >> "%_PREFIX%NETWORK_IPsec_reg_.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Services\IKEEXT" /s >> "%_PREFIX%NETWORK_IPsec_reg_.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Services\PolicyAgent" /s >> "%_PREFIX%NETWORK_IPsec_reg_.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\vmbus" /s >> "%_PREFIX%NETWORK_HyperVNetworking_reg_.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\VMBusHID" /s >> "%_PREFIX%NETWORK_HyperVNetworking_reg_.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\vmicguestinterface" /s >> "%_PREFIX%NETWORK_HyperVNetworking_reg_.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\vmicheartbeat" /s >> "%_PREFIX%NETWORK_HyperVNetworking_reg_.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\vmickvpexchange" /s >> "%_PREFIX%NETWORK_HyperVNetworking_reg_.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\vmicrdv" /s >> "%_PREFIX%NETWORK_HyperVNetworking_reg_.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\vmicshutdown" /s >> "%_PREFIX%NETWORK_HyperVNetworking_reg_.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\vmictimesync" /s >> "%_PREFIX%NETWORK_HyperVNetworking_reg_.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\vmicvss" /s >> "%_PREFIX%NETWORK_HyperVNetworking_reg_.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}" /s >> "%_PREFIX%NETWORK_NetworkAdapters_reg_output.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Control\Network" /s >> "%_PREFIX%NETWORK_NetworkAdapters_reg_output.TXT" 2>> %_Errorfile%

Exit /B

:PERMPOLICY
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM Section Policies and Permissions
Echo Getting Policy and Permissions Info
Echo Policies and Permissions section ----------------------- %time% >> "%_Errorfile%"
reg.exe query "HKCU\Software\Policies" /s >> "%_PREFIX%reg_Policies.txt" 2>> %_Errorfile%
Echo %_line% >> "%_PREFIX%reg_Policies.txt"
reg.exe query "HKLM\Software\Policies" /s >> "%_PREFIX%reg_Policies.txt" 2>> %_Errorfile%
Echo %_line% >> "%_PREFIX%reg_Policies.txt"
reg.exe query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies" /s >> "%_PREFIX%reg_Policies.txt" 2>> %_Errorfile%
Echo %_line% >> "%_PREFIX%reg_Policies.txt"
reg.exe query "HKLM\System\CurrentControlSet\Policies" /s >> "%_PREFIX%reg_Policies.txt" 2>> %_Errorfile%

icacls C:\ >> "%_PREFIX%File_Icacls_Permissions.txt" 2>> %_Errorfile%
Echo %_line% >> "%_PREFIX%File_Icacls_Permissions.txt"
icacls C:\windows >> "%_PREFIX%File_Icacls_Permissions.txt" 2>> %_Errorfile%
Echo %_line% >> "%_PREFIX%File_Icacls_Permissions.txt"
icacls C:\windows\serviceProfiles /t >> "%_PREFIX%File_Icacls_Permissions.txt" 2>> %_Errorfile%
Echo %_line% >> "%_PREFIX%File_Icacls_Permissions.txt"
icacls c:\windows\system32\spp /t >> "%_PREFIX%File_Icacls_Permissions.txt" 2>> %_Errorfile%

secedit /export /cfg "%_PREFIX%User_Rights.txt" >NUL 2>> %_Errorfile%

If exist %windir%\system32\CodeIntegrity xcopy /s /e /c /i "%windir%\system32\CodeIntegrity\*.*" %_TEMPDIR%\CodeIntegrity /y >NUL 2>> %_Errorfile%

Exit /B


:STORAGE
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM Section Storage and Device info
Echo Getting Storage and Device Info
Echo Storage and Device info section ------------------------- %time% >> "%_Errorfile%"
Fltmc.exe Filters >> %_PREFIX%Fltmc.TXT 2>> %_Errorfile%
Fltmc.exe Instances >> %_PREFIX%Fltmc.TXT 2>> %_Errorfile%
Fltmc.exe Volumes >> %_PREFIX%Fltmc.TXT 2>> %_Errorfile%

vssadmin.exe list volumes >> %_PREFIX%VSSAdmin.TXT 2>> %_Errorfile%
vssadmin.exe list writers >> %_PREFIX%VSSAdmin.TXT 2>> %_Errorfile%
vssadmin.exe list providers >> %_PREFIX%VSSAdmin.TXT 2>> %_Errorfile%
vssadmin.exe list shadows >> %_PREFIX%VSSAdmin.TXT 2>> %_Errorfile%
vssadmin.exe list shadowstorage >> %_PREFIX%VSSAdmin.TXT 2>> %_Errorfile%
reg.exe query "HKLM\System\MountedDevices" >> "%_PREFIX%reg_MountedDevices.TXT" 2>> %_Errorfile%
reg.exe save "HKLM\System\MountedDevices" "%_PREFIX%reg_MountedDevices.HIV" /y >NUL 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Services\iScsiPrt" /s >> "%_PREFIX%reg_iSCSI.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Services\iScsiPrt" /s >> "%_PREFIX%reg_Storage.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Enum" /s >> "%_PREFIX%reg_Enum.TXT" 2>> %_Errorfile%


If not "%_PS4ormore%"=="1" goto DISKPART
REM Begin Disk Info script-----------------------------------
Echo %_line% >> "%_PREFIX%Storage_Info.txt"
echo ------Get disk heath using Powershell------- >> "%_PREFIX%Storage_Info.txt"
Echo %_line% >> "%_PREFIX%Storage_Info.txt"
set _DiskInfo=%TEMP%\diskinfo.ps1

echo $Pdisk= Get-PhysicalDisk >> %_DiskInfo%
echo ForEach ( $LDisk in $PDisk ) >> %_DiskInfo%
echo                 { >> %_DiskInfo%
echo                 $LDisk.FriendlyName >> %_DiskInfo%
echo                 $LDisk.HealthStatus >> %_DiskInfo%
echo                 $LDisk ^| Get-StorageReliabilityCounter ^| Select-Object * ^| FL >> %_DiskInfo%
echo                 Write-Host ================== >> %_DiskInfo%
echo                 } >> %_DiskInfo%

powershell -ExecutionPolicy Bypass -Command %_DiskInfo% > "%_PREFIX%Storage_Info.TXT" 2>> %_Errorfile%
del %_DiskInfo%
REM End Disk Info--------------------------------

Echo %_line% >> "%_PREFIX%Storage_Info.txt"
echo ------Get physical disk info using Powershell------- >> "%_PREFIX%Storage_Info.txt"
Echo %_line% >> "%_PREFIX%Storage_Info.txt"
Powershell -ExecutionPolicy Bypass "Get-PhysicalDisk | Select" * >> "%_PREFIX%Storage_Info.txt" 2>> %_Errorfile%


:DISKPart
Rem - Diskpart info
Echo %_line% >> "%_PREFIX%Storage_Info.txt"
echo ------Get disk info using dispart------- >> "%_PREFIX%Storage_Info.txt"
echo ------Note that a failure finding a disk in the command file will end the query so there will be error at the end of the output------- >> "%_PREFIX%Storage_Info.txt"
Echo %_line% >> "%_PREFIX%Storage_Info.txt"

Rem - Build the command file
echo list disk >> "%_PREFIX%pscommand.txt"
echo select disk 0 >> "%_PREFIX%pscommand.txt" 
echo list volume >> "%_PREFIX%pscommand.txt"
echo list partition >> "%_PREFIX%pscommand.txt"
echo select partition 1 >> "%_PREFIX%pscommand.txt"
echo detail partition >> "%_PREFIX%pscommand.txt"
echo select partition 2 >> "%_PREFIX%pscommand.txt"
echo detail partition >> "%_PREFIX%pscommand.txt"
echo select partition 3 >> "%_PREFIX%pscommand.txt"
echo detail partition >> "%_PREFIX%pscommand.txt"
echo list volume >> "%_PREFIX%pscommand.txt"
echo select volume 1 >> "%_PREFIX%pscommand.txt"
echo detail volume >> "%_PREFIX%pscommand.txt"
echo select volume 2 >> "%_PREFIX%pscommand.txt"
echo detail volume >> "%_PREFIX%pscommand.txt"
echo select disk 1 >> "%_PREFIX%pscommand.txt"
echo list partition >> "%_PREFIX%pscommand.txt"
echo select partition 1 >> "%_PREFIX%pscommand.txt"
echo detail partition >> "%_PREFIX%pscommand.txt"
echo select partition 2 >> "%_PREFIX%pscommand.txt"
echo detail partition >> "%_PREFIX%pscommand.txt"
echo select partition 3 >> "%_PREFIX%pscommand.txt"
echo detail partition >> "%_PREFIX%pscommand.txt"
Rem - Done building command file

diskpart /s %_PREFIX%pscommand.txt >> "%_PREFIX%Storage_Info.txt" 2>> %_Errorfile%
echo %_line% >> "%_PREFIX%Storage_Info.txt"
del "%_PREFIX%pscommand.txt"

Exit /B

:PROCESS
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM Section Running process info
Echo Running process info ------------------------------------ %time% >> "%_Errorfile%"
echo Getting Process Info
tasklist /svc /fo list >> %_PREFIX%Process_and_Service_Tasklist.txt
wmic process get * /format:texttable  > %_PREFIX%Process_and_Service_info.txt

Exit /B


:BITLOCKER
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM Section Bitlocker and MBAM
Echo Windows setup section ----------------------------------- %time% >> "%_Errorfile%"
Echo Getting Bitlocker and MBAM info

If exist %windir%\system32\manage-bde.exe (
manage-bde -status > "%_PREFIX%Bitlocker_ManageBDE.txt" 2>> %_Errorfile%
manage-bde -protectors c: -get >> "%_PREFIX%Bitlocker_ManageBDE.txt" 2>> %_Errorfile%
)

reg.exe query "HKLM\SOFTWARE\Policies\Microsoft\FVE" /s > "%_PREFIX%Bitlocker_MBAM-Reg.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Policies\Microsoft\TPM" /s >> "%_PREFIX%Bitlocker_MBAM-Reg.TXT" 2>> %_Errorfile%

reg.exe query "HKLM\SOFTWARE\Microsoft\BitLockerCsp" /s >> "%_PREFIX%Bitlocker_MBAM-Reg.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\MBAM" /s >> "%_PREFIX%Bitlocker_MBAM-Reg.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\MBAMPersistent" /s >> "%_PREFIX%Bitlocker_MBAM-Reg.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\MBAM Server" /s >> "%_PREFIX%Bitlocker_MBAM-Reg.TXT" 2>> %_Errorfile%

If exist "C:\Program Files\Microsoft\MDOP MBAM\mbamagent.exe" powershell -ExecutionPolicy Bypass -command "gwmi -class mbam_volume -namespace root\microsoft\mbam" >> "%_PREFIX%Bitlocker_MBAM-WMINamespace.txt" 2>> %_Errorfile%
If %_PS4ormore%==1 powershell -ExecutionPolicy Bypass -command "get-tpm" >> "%_PREFIX%Bitlocker_Get-TPM.txt" 2>> %_Errorfile%

If exist "%windir%\system32\tpmtool.exe" (
md %_TEMPDIR%\tpmtool /y 2>> %_Errorfile%
tpmtool getdeviceinformation > %_TEMPDIR%\tpmtool\getdeviceinformation.txt
tpmtool gatherlogs %_TEMPDIR%\tpmtool >NUL 2>>NUL
tpmtool parsetcglogs > %_TEMPDIR%\tpmtool\parsetcglogs.txt 2>>NUL
)

Rem - If MBAM server then gather this
If %_MBAM-SYSTEM% == 1 (
Powershell -ExecutionPolicy Bypass -Command "Get-MbamCMIntegration" > "%_PREFIX%Bitlocker-MBAM_Info.TXT" 2>> %_Errorfile%
Echo %_line% >>  "%_PREFIX%Bitlocker-MBAM_Info.TXT"
Powershell -ExecutionPolicy Bypass -Command "Get-MbamReport" >> "%_PREFIX%Bitlocker-MBAM_Info.TXT" 2>> %_Errorfile%
Echo %_line% >> "%_PREFIX%Bitlocker-MBAM_Info.TXT"
Powershell -ExecutionPolicy Bypass -Command "Get-MbamWebApplication -AdministratorPortal" >> "%_PREFIX%Bitlocker-MBAM_Info.TXT" 2>> %_Errorfile%
Echo %_line% >> "%_PREFIX%Bitlocker-MBAM_Info.TXT"
Powershell -ExecutionPolicy Bypass -Command "Get-MbamWebApplication -AgentService" >> "%_PREFIX%Bitlocker-MBAM_Info.TXT" 2>> %_Errorfile%
Echo %_line% >> "%_PREFIX%Bitlocker-MBAM_Info.TXT"
Powershell -ExecutionPolicy Bypass -Command "Get-MbamWebApplication -SelfServicePortal" >> "%_PREFIX%Bitlocker-MBAM_Info.TXT" 2>> %_Errorfile%
)


EXIT /B

:MISC
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM Section Misc Info
Echo Getting Misc Info
Echo Misc info section --------------------------------------- %time% >> "%_Errorfile%"
certutil -store root > %_PREFIX%certs.txt 2>> %_Errorfile%
REM Get mini dumps
if exist %WinDir%\Minidump if not exist %TargetDrive%\Windows\Minidump md %_TEMPDIR%\Minidump /y >NUL 2>> %_Errorfile%
if exist %WinDir%\Minidump xcopy /cherky %WinDir%\Minidump\*.* %_TEMPDIR%\Minidump\ >NUL 2>> %_Errorfile%
if exist %WinDir%\system32\netsetupmig.log copy %WinDir%\system32\netsetupmig.log %_TEMPDIR%\ >NUL 2>> %_Errorfile%
verifier.exe /query > %_PREFIX%verifier.txt 2>> %_Errorfile%

REM Get All Scheduled Task on the system
Echo %_line% >> %_PREFIX%ScheduledTask.txt
Echo This file contains schduled task info first in summary and then in verbose format >> %_PREFIX%ScheduledTask.txt
Echo %_line% >> %_PREFIX%ScheduledTask.txt
SCHTASKS /query >> %_PREFIX%ScheduledTask.txt 2>> %_Errorfile%
Echo. >> %_PREFIX%ScheduledTask.txt
Echo. >> %_PREFIX%ScheduledTask.txt
Echo %_line% >> %_PREFIX%ScheduledTask.txt
Echo Now Verbose Output >> %_PREFIX%ScheduledTask.txt
Echo %_line% >> %_PREFIX%ScheduledTask.txt
Echo. >> %_PREFIX%ScheduledTask.txt
Echo. >> %_PREFIX%ScheduledTask.txt
SCHTASKS /query /v >> %_PREFIX%ScheduledTask.txt 2>> %_Errorfile%

Echo Getting BCDEdit info
Echo. >> %_PREFIX%BCDEdit.TXT
Echo bcdedit.exe /enum >> %_PREFIX%BCDEdit.TXT
Echo ================= >> %_PREFIX%BCDEdit.TXT
bcdedit.exe /enum >> %_PREFIX%BCDEdit.TXT 2>> %_Errorfile%

Echo. >> %_PREFIX%BCDEdit.TXT
Echo ===================== >> %_PREFIX%BCDEdit.TXT
Echo bcdedit.exe /enum all>> %_PREFIX%BCDEdit.TXT
Echo ===================== >> %_PREFIX%BCDEdit.TXT
bcdedit.exe /enum all >> %_PREFIX%BCDEdit.TXT 2>> %_Errorfile%

Echo. >> %_PREFIX%BCDEdit.TXT
Echo ===================== >> %_PREFIX%BCDEdit.TXT
Echo bcdedit.exe /enum all /v>> %_PREFIX%BCDEdit.TXT
Echo ======================== >> %_PREFIX%BCDEdit.TXT
bcdedit.exe /enum all /v >> %_PREFIX%BCDEdit.TXT 2>> %_Errorfile%

Dism /english /online /get-drivers /Format:Table > %_PREFIX%Dism_3rdPartyDrivers.TXT 2>> %_Errorfile%
Powershell -ExecutionPolicy Bypass -Command Get-WmiObject Win32_PnPEntity > "%_PREFIX%Drivers_WMIQuery.txt" 2>> %_Errorfile%

If %_Win10% == 1 pnputil.exe /export-pnpstate %_PREFIX%Drivers_pnpstate.pnp >NUL 2>> %_Errorfile%

cd  /d %_TEMPDIR%
cscript.exe //e:vbs  "%_Batchdir%\SummaryRep.txt" /sdp /SetupSDPManifest >NUL
cd  /d %_Batchdir%


REM Get MDM Info
IF EXIST %windir%\system32\MDMDiagnosticsTool.exe (
    md %_TEMPDIR%\MDMDiag >NUL
    %windir%\system32\MDMDiagnosticsTool.exe -out "%_TEMPDIR%\MDMDiag\MDMDiag" >NUL 2>>NUL
    %windir%\system32\MDMDiagnosticsTool.exe -area Autopilot;DeviceEnrollment;Tpm -cab "%_TEMPDIR%\MDMDiag\AutopilotDeviceEnrollmentTpmDiag.cab" >NUL 2>>NUL
    reg export "HKLM\SOFTWARE\Microsoft\PolicyManager" "%_TEMPDIR%\MDMDiag\REG_PolicyManager.TXT" >NUL 2>> %_Errorfile%
 )


if exist %windir%\dpinst.log copy %windir%\dpinst.log %_PREFIX%dpinst.log >NUL 2>> %_Errorfile%
if exist %windir%\certutil.log copy %windir%\certutil.log %_PREFIX%certutil.log >NUL 2>> %_Errorfile% 
copy %windir%\System32\catroot2\dberr.txt %_PREFIX%dberr.txt >NUL 2>> %_Errorfile%
if exist c:\users\public\documents\sigverif.txt copy c:\users\public\documents\sigverif.txt %_PREFIX%sigverif.txt >NUL 2>> %_Errorfile% 


REM - Power report info

powercfg /L > %_PREFIX%Powercfg_Settings.txt 2>> %_Errorfile%
Echo. >> %_PREFIX%Powercfg_Settings.txt 
Echo %_line% >> %_PREFIX%Powercfg_Settings.txt
Echo. >> %_PREFIX%Powercfg_Settings.txt
powercfg /aliases >> %_PREFIX%Powercfg_Settings.txt 2>> %_Errorfile%
Echo. >> %_PREFIX%Powercfg_Settings.txt 
Echo %_line% >> %_PREFIX%Powercfg_Settings.txt
Echo. >> %_PREFIX%Powercfg_Settings.txt
Powercfg /a >> %_PREFIX%Powercfg_Settings.txt  2>> %_Errorfile%
Echo. >> %_PREFIX%Powercfg_Settings.txt 
Echo %_line% >> %_PREFIX%Powercfg_Settings.txt
Echo. >> %_PREFIX%Powercfg_Settings.txt
powercfg /qh >> %_PREFIX%Powercfg_Settings.txt 2>> %_Errorfile%

Exit /B


:ACTIVATION
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM Get Licensing info
Echo Getting Licensing Info
Echo Nslookup info > %_PREFIX%KMSActivation.TXT
nslookup -type=all _vlmcs._tcp >> %_PREFIX%KMSActivation.TXT 2>> %_Errorfile%
Echo %_line% >> %_PREFIX%KMSActivation.TXT
Echo. >> %_PREFIX%KMSActivation.TXT

If Exist %windir%\system32\dsregcmd.exe ( 
Echo Dsregcmd status >> %_PREFIX%KMSActivation.TXT
Echo %_line% >> %_PREFIX%KMSActivation.TXT
Echo. >> %_PREFIX%KMSActivation.TXT
dsregcmd /status >> %_PREFIX%KMSActivation.TXT 2>> %_Errorfile%
)


Echo slmgr.vbs dlv >> %_PREFIX%KMSActivation.TXT
cscript.exe //Nologo %windir%\system32\slmgr.vbs /dlv >> %_PREFIX%KMSActivation.TXT 2>> %_Errorfile%
Echo. >> %_PREFIX%KMSActivation.TXT
Echo slmgr.vbs dlv all >> %_PREFIX%KMSActivation.TXT
cscript.exe //Nologo %windir%\system32\slmgr.vbs /dlv all >> %_PREFIX%KMSActivation.TXT 2>> %_Errorfile%
Echo %_line% >> %_PREFIX%KMSActivation.TXT
Echo. >> %_PREFIX%KMSActivation.TXT
cscript.exe //Nologo %windir%\System32\slmgr.vbs /ao-list >> %_PREFIX%KMSActivation.TXT 2>> %_Errorfile%
Echo. >> %_PREFIX%KMSActivation.TXT
Echo Software Licensing Service Class >> %_PREFIX%KMSActivation.TXT
Echo %_line% >> %_PREFIX%KMSActivation.TXT
Powershell -ExecutionPolicy Bypass -Command Get-WmiObject -Class SoftwareLicensingService >> "%_PREFIX%KMSActivation.TXT" 2>> %_Errorfile%

If exist %windir%\system32\licensingdiag.exe licensingdiag.exe -report %_PREFIX%lic_diag.txt -log %_PREFIX%lic_logs.cab >NUL 2>>NUL
reg.exe query "HKLM\SYSTEM\WPA" /s >> "%_PREFIX%reg_System-wpa.TXT" 2>> %_Errorfile%
reg.exe query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" /s >> "%_PREFIX%reg_SoftwareProtectionPlatform.TXT" 2>> %_Errorfile%
If exist %WinDir%\temp\lpksetup.log copy %WinDir%\temp\lpksetup.log %_PREFIX%_lpksetup.log >NUL 2>> %_Errorfile%

REM Token Activation

Echo slmgr.vbs /dlv > %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo %_line% >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Cscript.exe //Nologo %windir%\system32\slmgr.vbs /dlv >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo. >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo slmgr.vbs /lil >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo %_line% >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Cscript.exe //Nologo %windir%\system32\slmgr.vbs /lil >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo. >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo slmgr.vbs /ltc >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo %_line% >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Cscript.exe //Nologo %windir%\system32\slmgr.vbs /ltc >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo. >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%

Echo Certutil -store ca >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo %_line% >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Certutil -store ca >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo. >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo Certutil -store my >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo %_line% >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Certutil -store my >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo. >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo Certutil -store root >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo %_line% >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Certutil -store root >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%

REM Office token activation

Echo. >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo. >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo Getting Office Token Info >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%

Echo Checking for Office14 x86>> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo %_line% >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
If exist "C:\program files (x86)\microsoft office\office14\ospp.vbs" (
Cscript.exe "c:\program files (x86)\microsoft office\office14\ospp.vbs" /dtokils >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Cscript.exe "c:\program files (x86)\microsoft office\office14\ospp.vbs" /dtokcerts >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
)

Echo Checking for Office14 x64>> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo %_line% >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
If exist "c:\program files\microsoft office\office14\ospp.vbs" (
Cscript.exe "c:\program files\microsoft office\office14\ospp.vbs" /dtokils >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Cscript.exe "c:\program files\microsoft office\office14\ospp.vbs" /dtokcerts >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
)

Echo Checking for Office15 x86>> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo %_line% >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
If exist "c:\program files (x86)\microsoft office\office15\ospp.vbs" (
Cscript.exe "c:\program files (x86)\microsoft office\office15\ospp.vbs" /dtokils >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Cscript.exe "c:\program files (x86)\microsoft office\office15\ospp.vbs" /dtokcerts >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
)

Echo Checking for Office15 x64>> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo %_line% >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
If exist "c:\program files\microsoft office\office15\ospp.vbs" (
Cscript.exe "c:\program files\microsoft office\office15\ospp.vbs" /dtokils >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Cscript.exe "c:\program files\microsoft office\office15\ospp.vbs" /dtokcerts >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
)

Echo Checking for Office16 x86>> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo %_line% >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
If exist "c:\program files (x86)\microsoft office\office16\ospp.vbs" (
Cscript.exe "c:\program files (x86)\microsoft office\office16\ospp.vbs" /dtokils >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Cscript.exe "c:\program files (x86)\microsoft office\office16\ospp.vbs" /dtokcerts >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
)

Echo Checking for Office16 x64>> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Echo %_line% >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
If exist "c:\program files\microsoft office\office16\ospp.vbs" (
Cscript.exe "c:\program files\microsoft office\office16\ospp.vbs" /dtokils >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
Cscript.exe "c:\program files\microsoft office\office16\ospp.vbs" /dtokcerts >> %_PREFIX%Token_ACT.txt 2>> %_Errorfile%
)

EXIT /B

:DIRECTORY
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Echo Getting Directory Listing of Key Files
Echo Directory list section --------------------------------------- %time% >> "%_Errorfile%"
dir /a /r C:\ > %_PREFIX%dir_driveroot.txt 2>> %_Errorfile%
if exist d:\ dir /a /r D:\ >> %_PREFIX%dir_driveroot.txt 2>> %_Errorfile%
if exist e:\ dir /a /r E:\ >> %_PREFIX%dir_driveroot.txt 2>> %_Errorfile%
If exist %windir%\boot\* dir /a /s /r C:\windows\boot > %_PREFIX%dir_boot.txt 2>> %_Errorfile%
If exist %windir%\LiveKernelReports\* dir /a /s /r C:\Windows\LiveKernelReports > %_PREFIX%dir_LiveKernelReports.txt 2>> %_Errorfile%
dir /a /s /r %windir%\system32\drivers > %_PREFIX%dir_win32-drivers.txt 2>> %_Errorfile%
if exist %windir%\system32\driverstore\filerepository dir /a /s /r %windir%\system32\driverstore\filerepository > %_PREFIX%dir_win32-driverstore.txt 2>> %_Errorfile%
if exist %windir%\systemapps dir /a /s /r %windir%\systemapps > %_PREFIX%dir_systemapps.txt 2>> %_Errorfile%
dir /a /s /r %temp% > %_PREFIX%dir_temp.txt 2>> %_Errorfile%
dir /a /s /r %windir%\temp >> %_PREFIX%dir_temp.txt 2>> %_Errorfile%
dir /a /s /r %windir%\inf > %_PREFIX%dir_INF.txt 2>> %_Errorfile%
dir /a /s /r %windir%\system32\catroot > %_PREFIX%dir_catroot.txt 2>> %_Errorfile%
Echo %_line% >> %_PREFIX%dir_catroot.txt 2>> %_Errorfile%
dir /a /s /r %windir%\system32\catroot2 >> %_PREFIX%dir_catroot.txt 2>> %_Errorfile%

REM Get registry size info including Config and profile info
dir /a /s /r c:\windows\system32\config\*.* > %_PREFIX%dir_registry_list.txt
dir /a /s /r c:\users\ntuser.dat >> %_PREFIX%dir_registry_list.txt


EXIT /B

:POWER
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM - Generate detail battery, sleep and power info.
REM - Only run if flag set
Echo Power Config section ------------------------------------ %time% >> "%_Errorfile%"
Echo Getting Powercfg Config and Sleep Info
powercfg /batteryreport /duration 14 /output "%_PREFIX%Powercfg-batteryreport.html" >NUL 2>>NUL
powercfg /sleepstudy /duration 14 /output "%_PREFIX%Powercfg-sleepstudy.html" >NUL 2>>NUL
powercfg /energy /output "%_PREFIX%Powercfg-energy.html" >NUL 2>>NUL
powercfg /srumutil /output "%_PREFIX%Powercfg-srumdbout.xml" /xml >NUL 2>>NUL
powercfg /SYSTEMSLEEPDIAGNOSTICS /OUTPUT "%_PREFIX%Powercfg-system-sleep-diagnostics.html" >NUL 2>>NUL
powercfg /SYSTEMPOWERREPORT /OUTPUT "%_PREFIX%Powercfg-sleepstudy.html" >NUL 2>>NUL

EXIT /B


:SURFACE
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM - Microsoft Surface Specific info.

REM - Drivers
set _surface_SCRIPT=%TEMP%\surfacedriver.ps1
echo gwmi Win32_PnPSignedDriver ^| select devicename,driverversion,HardwareID ^| where {$_.devicename -like "*intel*" -or $_.devicename -like "*surface*" -or $_.devicename -like "*Nvidia*" -or $_.devicename -like "*microsoft*" -or $_.devicename -like "*marvel*" -or $_.devicename -like "*qualcomm*" -or $_.devicename -like "*realtek*"} ^| Sort-object -property devicename ^| Export-Csv -path %_PREFIX%Surface_drivers.csv > %_surface_SCRIPT%
powershell -ExecutionPolicy Bypass -Command %_surface_SCRIPT% >NUL 2>> %_Errorfile%
del %_surface_SCRIPT% 2>> %_Errorfile%

REM - Registry keys

Echo ---------Surface Registry Keys - If blank then keys not there---------------- > "%_PREFIX%Surface_Registry.TXT"
reg.exe query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WUDF\Services\SurfaceDockFwUpdate" /s >> "%_PREFIX%Surface_Registry.TXT" 2>> %_Errorfile%
Echo. >> "%_PREFIX%Surface_Registry.TXT"
Echo %line% >> "%_PREFIX%Surface_Registry.TXT"
Echo. >> "%_PREFIX%Surface_Registry.TXT"
reg.exe query "HKLM\SOFTWARE\Microsoft\Surface\OSImage" /s >> "%_PREFIX%Surface_Registry.TXT" 2>> %_Errorfile%
Echo %line% >> "%_PREFIX%Surface_Registry.TXT"
Echo. >> "%_PREFIX%Surface_Registry.TXT"
reg.exe query "HKLM\SYSTEM\CurrentControlSet\Control\Power" >> "%_PREFIX%Surface_Registry.TXT" 2>> %_Errorfile%

EXIT /B

:SLOWPROCESSING
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
REM - Move things here that are not as critical, take a long time or are more prone to failure
Echo Slow processing section --------------------------------------- %time% >> "%_Errorfile%"
echo Exporting servicing registry hives...may take several minutes
echo Note if this takes more than 15 minutes please stop the batch and zip and upload all the data that has been captured to this point.
Echo Data will be in folder %_TEMPDIR%
Dism /english /online /Cleanup-Image /CheckHealth > nul 2>> %_Errorfile%
echo Component based servicing hive %time% >> "%_Errorfile%"
reg.exe save "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing" "%_PREFIX%reg_Component_Based_Servicing.HIV" /y >NUL 2>> %_Errorfile%
echo SideBySide Hive                %time% >> "%_Errorfile%"
reg.exe save "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\SideBySide" "%_PREFIX%reg_SideBySide.HIV" >NUL 2>> %_Errorfile%
echo Trusted Installer text         %time% >> "%_Errorfile%"
reg.exe query "HKLM\SYSTEM\CurrentControlSet\services\TrustedInstaller" /s >> "%_PREFIX%reg_TrustedInstaller.TXT" 2>> %_Errorfile%
echo SideBySide text                %time% >> "%_Errorfile%"
reg.exe export "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\SideBySide" "%_PREFIX%reg_SideBySide.txt" >NUL 2>> %_Errorfile%
echo Components text                %time% >> "%_Errorfile%"
reg.exe export "HKLM\COMPONENTS" "%_PREFIX%reg_Components.txt" >NUL 2>> %_Errorfile%

EXIT /B

:ENDSECTION
REM Powershell commands for Win10 Only
REM Skip for now
if "%_WIN10%"=="3" (
	Echo Computer Info >> %_PREFIX%MiscInfo.txt
	Echo %_line% >> %_PREFIX%MiscInfo.txt
	Powershell -ExecutionPolicy Bypass -command "Get-computerinfo -verbose | Format-list >> %_PREFIX%MiscInfo.txt"
	Echo. >> %_PREFIX%MiscInfo.txt
	Echo. >> %_PREFIX%MiscInfo.txt
	Echo Local Groups >> %_PREFIX%MiscInfo.txt
	Echo %_line% >> %_PREFIX%MiscInfo.txt
	Powershell -ExecutionPolicy Bypass -command "Get-localgroup | Format-list >> %_PREFIX%MiscInfo.txt"
	Echo. >> %_PREFIX%MiscInfo.txt
	Echo. >> %_PREFIX%MiscInfo.txt
	Echo Local Users >> %_PREFIX%MiscInfo.txt
	Echo %_line% >> %_PREFIX%MiscInfo.txt
	Powershell -ExecutionPolicy Bypass -command "Get-localuser >> %_PREFIX%MiscInfo.txt"
	Echo. >> %_PREFIX%MiscInfo.txt
	Echo. >> %_PREFIX%MiscInfo.txt
	Echo Windows Update Pending Reboot >> %_PREFIX%MiscInfo.txt
	Echo %_line% >> %_PREFIX%MiscInfo.txt
	Powershell -ExecutionPolicy Bypass -command "Get-WUIsPendingReboot >> %_PREFIX%MiscInfo.txt"
	Echo. >> %_PREFIX%MiscInfo.txt
	Echo. >> %_PREFIX%MiscInfo.txt
	Echo Windows Update Version >> %_PREFIX%MiscInfo.txt
	Echo %_line% >> %_PREFIX%MiscInfo.txt
	Powershell -ExecutionPolicy Bypass -command "Get-WUAVersion >> %_PREFIX%MiscInfo.txt"
	Echo. >> %_PREFIX%MiscInfo.txt
	Echo. >> %_PREFIX%MiscInfo.txt
	Echo Windows Update Last Installation Date >> %_PREFIX%MiscInfo.txt
	Echo %_line% >> %_PREFIX%MiscInfo.txt
	Powershell -ExecutionPolicy Bypass -command "Get-WULastInstallationDate >> %_PREFIX%MiscInfo.txt"
	Echo. >> %_PREFIX%MiscInfo.txt
	Echo  >> %_PREFIX%MiscInfo.txt
	Echo Windows Update Last Scan Success Date >> %_PREFIX%MiscInfo.txt
	Echo %_line% >> %_PREFIX%MiscInfo.txt
	Powershell -ExecutionPolicy Bypass -command "Get-WULastScanSuccessDate >> %_PREFIX%MiscInfo.txt"
)

REM Make RFLcheck happy, create dummy _sym_.txt file, collect hotfix
Echo %_line% > %_PREFIX%sym_.csv
copy %_PREFIX%Hotfix-WMIC.txt %_PREFIX%Hotfixes.csv >NUL 2>> %_Errorfile%

REM - LEAVE THIS HERE AT END OF FILE AND RUN EVEN ON MIN OUTPUT
Echo Getting 15 Second Perfmon
Logman.exe create counter Setup-Short -o "%_PREFIX%PerfLog-Short.blg" -f bincirc -v mmddhhmm -max 300 -c "\LogicalDisk(*)\*" "\Memory\*" "\Cache\*" "\Network Interface(*)\*" "\Paging File(*)\*" "\PhysicalDisk(*)\*" "\Processor(*)\*" "\Processor Information(*)\*" "\Process(*)\*" "\Redirector\*" "\Server\*" "\System\*" "\Server Work Queues(*)\*" "\Terminal Services\*" -si 00:00:01 >NUL 2>> %_Errorfile%
Logman.exe start Setup-Short >NUL 2>> %_Errorfile%
Timeout /T 15 /nobreak >NUL
Logman.exe stop Setup-Short >NUL 2>> %_Errorfile%
Logman.exe delete Setup-short >NUL 2>> %_Errorfile%


REM ---------------------------------------------------------------------------------------------
REM Section Wait for slow things to finish
If exist %_PREFIX%gpresult.htm goto ENDBATCH
Echo Waiting for background processing to complete
Echo Waiting
REM Only wait 30 seconds. If still not complete ignore.
Timeout /T 30 /nobreak

goto ENDBATCH

:DIREXIST
Echo.
Echo The Directory %_TEMPDIR% already exist as this batch as been run before. This script will not overwrite this directory.
Echo Please manually rename or delete this directory and run the batch again.
Echo.
endlocal
REM in case user run the script from explorer, keep the console open
Pause
Exit

:ENDBATCH
Echo Completed at--------------------------------------------- %time% >> "%_Errorfile%"
setlocal ENABLEDELAYEDEXPANSION
echo.
echo.   Files saved in %_TEMPDIR%
echo ** Please zip up the folder and upload to workspace
echo Please manually delete the report directory %_TEMPDIR%
endlocal
REM in case user run the script from explorer, keep the console open
pause
Exit

:Good_Bye
endlocal
Exit

 
