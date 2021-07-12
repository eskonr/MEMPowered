# Script to associate .log and .lo_ files to CMtrace and make it the default app to open them
# Version 1.0
# Jorgen - CCMexec.com

# Create Registry Keys and copy CMTrace.exe file to C:\Windows
Copy-Item "$($PSScriptRoot)\CMTrace.exe" -Destination "$($env:windir)\CMTrace.exe" -Force
New-Item -Path 'HKLM:\Software\Classes\.lo_' -type Directory -Force -ErrorAction SilentlyContinue
New-Item -Path 'HKLM:\Software\Classes\.log' -type Directory -Force -ErrorAction SilentlyContinue
New-Item -Path 'HKLM:\Software\Classes\.log.File' -type Directory -Force -ErrorAction SilentlyContinue
New-Item -Path 'HKLM:\Software\Classes\.Log.File\shell' -type Directory -Force -ErrorAction SilentlyContinue
New-Item -Path 'HKLM:\Software\Classes\Log.File\shell\Open' -type Directory -Force -ErrorAction SilentlyContinue
New-Item -Path 'HKLM:\Software\Classes\Log.File\shell\Open\Command' -type Directory -Force -ErrorAction SilentlyContinue
New-Item -Path 'HKLM:\Software\Microsoft\Trace32' -type Directory -Force -ErrorAction SilentlyContinue

# Create the properties to make CMtrace the default log viewer
New-ItemProperty -LiteralPath 'HKLM:\Software\Classes\.lo_' -Name '(default)' -Value "Log.File" -PropertyType String -Force -ea SilentlyContinue;
New-ItemProperty -LiteralPath 'HKLM:\Software\Classes\.log' -Name '(default)' -Value "Log.File" -PropertyType String -Force -ea SilentlyContinue;
New-ItemProperty -LiteralPath 'HKLM:\Software\Classes\Log.File\shell\open\command' -Name '(default)' -Value "`"C:\Windows\CMTrace.exe`" `"%1`"" -PropertyType String -Force -ea SilentlyContinue;


# Create an ActiveSetup that will remove the initial question in CMtrace if it should be the default reader
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\CMtrace" -type Directory
new-itemproperty "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\CMtrace" -Name "Version" -Value 1 -PropertyType String -Force 
new-itemproperty "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\CMtrace" -Name "StubPath" -Value "reg.exe add HKCU\Software\Microsoft\Trace32 /v ""Register File Types"" /d 0 /f" -PropertyType ExpandString -Force 
