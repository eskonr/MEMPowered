
<#
.SYNOPSIS
    Configure Windows 11 taskbar layout and search behavior and
    Configures Windows 11 taskbar search experience to show icon-only view.

.DESCRIPTION
    This script sets registry values to enforce the search box on the taskbar 
    to display as an icon (instead of the full search box) in Windows 11.

    It applies the configuration at both:
        - Machine level (HKLM)
        - Default user profile (HKU\Default)

    It also disables Search Highlights to prevent Windows from overriding 
    the configured search behavior.

    This ensures that all new user profiles receive a consistent taskbar 
    configuration during SCCM / OSD deployment.

.AUTHOR
    Eswar Koneti

.DATE
    19-May-2026

.VERSION
    1.0

.NOTES
    - Intended for use in SCCM / MECM Task Sequences
    - Must be executed after "Setup Windows and ConfigMgr"
    - Requires administrative privileges
    - Applies only to new user profiles (existing users are not modified)

.EXAMPLE
    Run as part of a Task Sequence to standardize Windows 11 taskbar layout
    with search icon only and no search highlights.
#>

# Configure Taskbar Layout (Default User)
$taskbarFile = "$env:SystemDrive\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.xml"
[xml]$taskbarXml = @"
<?xml version="1.0" encoding="utf-8"?>
<LayoutModificationTemplate
    xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification"
    xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout"
    xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout"
    xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout"
    Version="1">
  <CustomTaskbarLayoutCollection PinListPlacement="Replace">
    <defaultlayout:TaskbarLayout>
      <taskbar:TaskbarPinList>
        <taskbar:DesktopApp DesktopApplicationID="Microsoft.Windows.Explorer" />
        <taskbar:DesktopApp DesktopApplicationID="MSEdge"/>
        </taskbar:TaskbarPinList>
    </defaultlayout:TaskbarLayout>
 </CustomTaskbarLayoutCollection>
</LayoutModificationTemplate>
"@
if (-NOT[string]::IsNullOrEmpty($taskbarXml)) {
    $taskbarXml.Save($taskbarFile)
}

# Configure Search (Machine Level)
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v SearchboxTaskbarMode /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v SearchboxTaskbarModeCache /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v EnableDynamicContentInWSB /t REG_DWORD /d 0 /f

#Configure Default User Profile
reg load HKU\Default C:\Users\Default\NTUSER.DAT
reg add "HKU\Default\Software\Microsoft\Windows\CurrentVersion\Search" /v SearchboxTaskbarMode /t REG_DWORD /d 1 /f
reg add "HKU\Default\Software\Microsoft\Windows\CurrentVersion\Search" /v SearchboxTaskbarModeCache /t REG_DWORD /d 1 /f
reg unload HKU\Default

