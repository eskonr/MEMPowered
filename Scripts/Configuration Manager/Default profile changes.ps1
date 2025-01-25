<#
The following script helps you to configure the default profile during the Device provision in OSD using SCCM task sequence.
you can add multiple registry keys to make changes to the default user profile.
#>
REG LOAD HKLM\Default C:\Users\Default\NTUSER.DAT
 
# Removes Task View from the Taskbar
New-itemproperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value "0" -PropertyType Dword
 
# Removes Widgets from the Taskbar
New-itemproperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value "0" -PropertyType Dword
 
# Removes Chat from the Taskbar
New-itemproperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value "0" -PropertyType Dword
 
# Default StartMenu alignment 0=Left
New-itemproperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value "0" -PropertyType Dword
 
# Removes search from the Taskbar
reg.exe add "HKLM\Default\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v SearchboxTaskbarMode /t REG_DWORD /d 0 /f
 
REG UNLOAD HKLM\Default

REG LOAD HKLM\Default C:\Users\Default\NTUSER.DAT
 
# Removes Task View from the Taskbar
New-itemproperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value "0" -PropertyType Dword
 
# Removes Widgets from the Taskbar
New-itemproperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value "0" -PropertyType Dword
 
# Removes Chat from the Taskbar
New-itemproperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value "0" -PropertyType Dword
 
# Default StartMenu alignment 0=Left
New-itemproperty "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value "0" -PropertyType Dword
 
# Removes search from the Taskbar
reg.exe add "HKLM\Default\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v SearchboxTaskbarMode /t REG_DWORD /d 0 /f

#Disable new right click context menu
reg.exe add "HKLM\Default\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve

#Disable Explorer command bar:
reg.exe add "HKLM\Default\Software\Classes\CLSID\{d93ed569-3b3e-4bff-8355-3c44f6a52bb5}\InprocServer32" /f /ve
 
REG UNLOAD HKLM\Default