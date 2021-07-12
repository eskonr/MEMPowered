# Script to associate .log and .lo_ files to CMtrace and make it the default app to open them and Copy CMTrace.exe to C:\Windows
# Version 1.0
# Jorgen - CCMexec.com
# Remove CmTrace and registry Keys  

Remove-Item "$($env:windir)\CMTrace.exe" -Force 
Remove-ItemProperty -LiteralPath 'HKLM:\Software\Classes\Log.File\shell\open\command' -Name '(default)' -Value "`"C:\Windows\Notepad`" `"%1`"" -PropertyType String -Force -ea SilentlyContinue;

#Removes the ActiveSetup creeated by the CMTraceInstall skript
Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\CMtrace" -Force