
<#
.SYNOPSIS
Configures a default taskbar layout for new Windows user profiles.

.DESCRIPTION
This script creates a LayoutModification.xml file in the Default user profile directory.
The XML defines a custom taskbar layout that replaces existing pinned applications
with a standardized set.

Specifically, it pins:
- File Explorer (Microsoft.Windows.Explorer)
- Microsoft Edge (MSEdge)

The configuration applies only to newly created user profiles and does not modify
existing users.

.PARAMETER None
This script does not accept parameters.

.NOTES
- Must be run with appropriate permissions to write to the Default profile.
- Typically used in imaging, provisioning, or enterprise deployment scenarios.

Author: Eswar Koneti
Date: 16-May-2026
#>


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