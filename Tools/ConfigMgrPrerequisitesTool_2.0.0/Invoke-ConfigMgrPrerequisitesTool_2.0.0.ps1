<#
.SYNOPSIS
    Prepare your infrastructure for System Center Configuration Manager (ConfigMgr).

.DESCRIPTION
    With this tool you can prepare your infrastructure before installing System Center Configuration Manager. Below is a list of capabilities:

    - Install Windows Features for a Site type:
        - Central Administration Site
        - Primary Site
        - Secondary Site
    - Download the required prerequisites files for the installation of ConfigMgr
    - Install Windows Features for the following Site System Roles:
        - Management Point
        - Distribution Point
        - Application Catalog
        - Enrollment Point
        - Enrollment Proxy Point
        - State Migration Point
    - Extend Active Directory for ConfigMgr support
    - Add a group to the System Management container in Active Directory with proper permissions for Site publishing
    - Install Windows ADK in either online or offline mode
    - Install Windows Features for WSUS including post-installation configuration

.NOTES
    FileName:    Invoke-ConfigMgrPrerequisitesTool_2.0.0.ps1
    Author:      Nickolaj Andersen
    Contact:     @NickolajA
    Created:     2016-08-19
    Updated:     2016-08-19
    Version:     2.0.0
#>
Begin {
    # Create a global sync hash table
    $Global:SyncHash = [System.Collections.Hashtable]::Synchronized(@{})
    $SyncHash.Host = $Host
    $SyncHash.OnClose = $false
    $SyncHash.ScriptRoot = $PSScriptRoot
    
    # Site Configuration - Add custom properties to the sync hash table
    $SyncHash.SCXAMLControls = [System.String]::Empty
    $SyncHash.SCPercentComplete = 0
    $SyncHash.SCProgressMaximum = 100
    $SyncHash.SCFeatureSelection = [System.String]::Empty
    $SyncHash.SCFeatureLabel = [System.String]::Empty
    $SyncHash.SCCountLabel = [System.String]::Empty
    $SyncHash.SCLogText = [System.String]::Empty
    $SyncHash.SCPrereqLocation = [System.String]::Empty

    # Site System Roles - Add custom properties to the sync hash table
    $SyncHash.SSRXAMLControls = [System.String]::Empty
    $SyncHash.SSRPercentComplete = 0
    $SyncHash.SSRProgressMaximum = 100
    $SyncHash.SSRFeatureSelection = [System.String]::Empty
    $SyncHash.SSRFeatureLabel = [System.String]::Empty
    $SyncHash.SSRCountLabel = [System.String]::Empty
    $SyncHash.SSRLogText = [System.String]::Empty
    $SyncHash.SSRRemoteComputer = [System.String]::Empty
    $SyncHash.SSRCredential = [System.Management.Automation.PSCredential]::Empty
    $SyncHash.SSRCredentialSelected = [System.String]::Empty

    # Active Directory - Add custom properties to the sync hash table
    $SyncHash.ADXAMLControls = [System.String]::Empty
    $SyncHash.ADLogText = [System.String]::Empty
    $SyncHash.ADExtendPath = [System.String]::Empty
    $SyncHash.ADGroupFilter = [System.String]::Empty
    $SyncHash.ADObservableCollection = New-Object -TypeName System.Collections.ObjectModel.ObservableCollection[Object]
    $SyncHash.ADCreateContainer = $false
    $SyncHash.ADGroupSelection = [System.String]::Empty

    # Windows ADK - Add custom properties to the sync hash table
    $SyncHash.ADKXAMLControls = [System.String]::Empty
    $SyncHash.ADKLogText = [System.String]::Empty
    $SyncHash.ADKSelectedVersion = [System.String]::Empty
    $SyncHash.ADKPath = [System.String]::Empty
    $SyncHash.ADKRadioButtonOfflineChecked = [System.String]::Empty
    $SyncHash.ADKRadioButtonOnlineChecked = [System.String]::Empty

    # WSUS - Add custom properties to the sync hash table
    $SyncHash.WSUSXAMLControls = [System.String]::Empty
    $SyncHash.WSUSLogText = [System.String]::Empty
    $SyncHash.WSUSRadioButtonWIDChecked = [System.String]::Empty
    $SyncHash.WSUSRadioButtonSQLChecked = [System.String]::Empty
    $SyncHash.WSUSPercentComplete = 0
    $SyncHash.WSUSProgressMaximum = 100
    $SyncHash.WSUSCountLabel = [System.String]::Empty
    $SyncHash.WSUSInstallLocation = [System.String]::Empty
    $SyncHash.WSUSSelection = [System.String]::Empty
    $SyncHash.WSUSSQLServer = [System.String]::Empty
    $SyncHash.WSUSSQLInstance = [System.String]::Empty
    $SyncHash.WSUSProgressBarMode = $false

    # Create runspace
    $Runspace = [RunspaceFactory]::CreateRunspace()
    $Runspace.ApartmentState = "STA" 
    $Runspace.ThreadOptions = "ReuseThread"           
    $Runspace.Open()
    $Runspace.SessionStateProxy.SetVariable("SyncHash", $SyncHash)

    # Show GUI
    $PowerShellCommand = [PowerShell]::Create().AddScript({
        # Functions
        function Load-XAMLCode {
            param(
                [parameter(Mandatory=$true)]
                [ValidateNotNullOrEmpty()]
                [string]$FilePath
            )
            # Construct new XML document
            $XAMLLoader = New-Object -TypeName System.Xml.XmlDocument

            # Load file from parameter input
            $XAMLLoader.Load($FilePath)

            # Return XAML document
            return $XAMLLoader
        }

        function Get-DirectoryLocationForTextBoxControl {
            param(
                [parameter(Mandatory=$true)]
                [ValidateNotNullOrEmpty()]
                [string]$Message,

                [parameter(Mandatory=$true)]
                [ValidateNotNullOrEmpty()]
                [ValidateSet("TextBox_SiteConfigurationPrereq", "TextBox_ADKPath", "TextBox_ADExtend")]
                [string]$Control
            )
            $ShellApplication = New-Object -ComObject Shell.Application
            $FolderBrowserDialog = $ShellApplication.BrowseForFolder(0, "$($Message)", 0, 17)
   	        if ($FolderBrowserDialog) {
		        $SyncHash.$Control.Text = $FolderBrowserDialog.Self.Path
	        }
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($ShellApplication) | Out-Null
        }

        function Invoke-XAMLControls {
            param(
                [parameter(Mandatory=$true)]
                [ValidateSet("Enable", "Disable")]
                [string]$Mode,

                [parameter(Mandatory=$true)]
                [ValidateSet("SiteConfiguration", "SiteSystemRoles", "ActiveDirectory", "ADK", "WSUS")]
                [string]$Tab
            )
            # Construct mode table
            $ModeTable = @{
                "Enable" = $true
                "Disable" = $false
            }

            switch ($Tab) {
                "SiteConfiguration" {
                    $SyncHash.Button_SiteConfigurationInstall.IsEnabled = $ModeTable[$Mode]
                    $SyncHash.Button_SiteConfigurationBrowse.IsEnabled = $ModeTable[$Mode]
                    $SyncHash.ComboBox_SiteSelection.IsEnabled = $ModeTable[$Mode]
                    $SyncHash.TextBox_SiteConfigurationPrereq.IsEnabled = $ModeTable[$Mode]
                }
                "SiteSystemRoles" {
                    $SyncHash.Button_SiteSystemInstall.IsEnabled = $ModeTable[$Mode]
                    $SyncHash.ComboBox_SiteSystemSelection.IsEnabled = $ModeTable[$Mode]
                    $SyncHash.RadioButton_SiteSystemLocal.IsEnabled = $ModeTable[$Mode]
                    $SyncHash.RadioButton_SiteSystemRemote.IsEnabled = $ModeTable[$Mode]
                    if ($SyncHash.RadioButton_SiteSystemRemote.IsChecked -eq $true) {
                        $SyncHash.CheckBox_SiteSystemCredentials.IsEnabled = $ModeTable[$Mode]
                    }
                }
                "ActiveDirectory" {
                    $SyncHash.Button_ADExtendBrowse.IsEnabled = $ModeTable[$Mode]
                    $SyncHash.Button_ADExtend.IsEnabled = $ModeTable[$Mode]
                    $SyncHash.Button_ADContainerSearch.IsEnabled = $ModeTable[$Mode]
                    $SyncHash.CheckBox_ADContainer.IsEnabled = $ModeTable[$Mode]
                    $SyncHash.Button_ADContainerConfigure.IsEnabled = $ModeTable[$Mode]
                }
                "ADK" {
                    $SyncHash.Button_ADKInstall.IsEnabled = $ModeTable[$Mode]
                    $SyncHash.ComboBox_ADKVersion.IsEnabled = $ModeTable[$Mode]
                    $SyncHash.RadioButton_ADKOnline.IsEnabled = $ModeTable[$Mode]
                    $SyncHash.RadioButton_ADKOffline.IsEnabled = $ModeTable[$Mode]
                    if ($SyncHash.RadioButton_ADKOffline.IsChecked -eq $true) {
                        $SyncHash.Button_ADKBrowse.IsEnabled = $ModeTable[$Mode]
                        $SyncHash.TextBox_ADKPath.IsEnabled = $ModeTable[$Mode]
                    }
                }
                "WSUS" {
                    $SyncHash.RadioButton_WSUSWID.IsEnabled = $ModeTable[$Mode]
                    $SyncHash.RadioButton_WSUSSQL.IsEnabled = $ModeTable[$Mode]
                    if ($SyncHash.RadioButton_WSUSSQL.IsChecked -eq $true) {
                        $SyncHash.TextBox_WSUSSQLServer.IsEnabled = $ModeTable[$Mode]
                        $SyncHash.TextBox_WSUSSQLInstance.IsEnabled = $ModeTable[$Mode]
                    }
                    $SyncHash.TextBox_WSUSLocation.IsEnabled = $ModeTable[$Mode]
                    $SyncHash.Button_WSUSInstall.IsEnabled = $ModeTable[$Mode]
                }
            }
        }

        function Remove-LogText {
            param(
                [parameter(Mandatory=$true)]
                [ValidateSet("SCLogText","SSRLogText","WSUSLogText","ADKLogText")]
                [string]$Control
            )
            # Cleanup specified log text control
            $SyncHash.$Control = [System.String]::Empty
        }

        # Add assemblies
        Add-Type -AssemblyName "PresentationFramework", "PresentationCore", "WindowsBase", "System.DirectoryServices"

        # Load XAML code
        $XAMLCode = Load-XAMLCode -FilePath (Join-Path -Path $SyncHash.ScriptRoot -ChildPath "MainWindow.xaml")

        # Instantiate XAML window
        $XAMLReader = (New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $XAMLCode) 
        $SyncHash.Window = [Windows.Markup.XamlReader]::Load($XAMLReader)
	    $SyncHash.Window.Add_Closed({$SyncHash.OnClose = $true})

        # Convert Base64 image string to bitmap for XAML Window Icon property
        $Base64Image = "AAABAAEAKCgQJgAAAACoBgAAFgAAACgAAAAoAAAAUAAAAAEABAAAAAAAYAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAACAAAAAgIAAgAAAAIAAgACAgAAAgICAAMDAwAAAAP8AAP8AAAD//wD/AAAA/wD/AP//AAD///8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAREREREREREREREREREREREQAAAZ3d3d3d3d3d3d3d3d3d3d3d3QAB3d3d3d3d3d3d3d3d3d3d3d3d0AHd2d3Z3d3d2d3ZmZmd3dmZmZ3QAd2d2Z2Z3ZndmZmZmZnd3ZmZmdAB3ZnZmZmZmREREREREZndkREZ0AHdmZkRkRERERERERERGZmZERHQAZmdEaP+IiIiHRERERERmRkREdAB3RmZId3d3d3j/////h2RkZER0AGdmREh3d3d3j///////dGRkRHQAd0RESHd3d3f///////+HRkZEdAB3RERId3d3d////////4ZGZ2Z0AHdEREh3d3d4////////hHZndnQAd2ZmSHd3d3j///////+EdndndAB3ZmZId3d3eP///////4R3d2d0AHdmZkh3+I93////////hnd3d3QAd3d3aHeHeHf///iP//92d3d3dAB3d3dod3d3d4//hEj/+Hd3d3d0AHd3d2h3+I9/d4h2R4h3d3d3d3QAd3d3aHf4j3+Hd4/4dnd3d3d3dAB3d3dod3d3d3d4//+Hd3d3d3d0AHd3d2h3h4h4do////h3d3d3d3QAd3d3aHf4j3+Gj///+Hd3d3h4dAB3d3dod3d3d3eP///4d3d3h4h0AHd3d2h3d3d3d4////h3d3eIiHQAd3d3aHf4j3+HeP//h3d3iIiIdAB3d3d4d4eIeIf3eIh3eIiIiIh0AHd3d3h3d3d3d/d3d3iIiIiIiHQAd3d3eHd3d3d393iIiIiIiIiIdAB4d3d4d3d3d3f3iIiIiIiIiIh0AHh3d3iI+IiIiPeIiIiIiIiIiHQAeHd3d3d3iIiIh4iIiIiIiIiIdAB4d3d3d3d3d3d3iIiIiIiIiIh0AHh3d3eIiIiIiIiIiIiIiIiIiHQAd4iIiIiIiIiIiIiIiIiIiIiIdAB3eIiIiIiIiIiIiIiIiIiIiIdgAAZmZmZmZmZmZmZmZmZmZmZmZgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAAAAAAwAAAIAAAAABAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAADAAAAgAAAAA8AAAD//////wAAAA=="
        $BitmapImage = New-Object -TypeName System.Windows.Media.Imaging.BitmapImage
        $BitmapImage.BeginInit()
        $BitmapImage.StreamSource = [System.IO.MemoryStream][System.Convert]::FromBase64String($Base64Image)
        $BitmapImage.EndInit()
        $BitmapImage.Freeze()
        $SyncHash.Window.Icon = $BitmapImage

        # Locate and dynamically create the XAML controls
        $XAMLCode.SelectNodes("//*[@Name]") | ForEach-Object { $SyncHash.$($_.Name) = $SyncHash.Window.FindName("$($_.Name)") }

        # Site Configuration - Events
        $SyncHash.Button_SiteConfigurationBrowse.Add_Click({
            Get-DirectoryLocationForTextBoxControl -Message "Browse the Configuration Manager installation media and select the SMSSETUP\BIN\X64 folder:" -Control TextBox_SiteConfigurationPrereq
        })
        $SyncHash.Button_SiteConfigurationInstall.Add_Click({
            $SyncHash.SCFeatureSelection = $SyncHash.ComboBox_SiteSelection.SelectedValue
            Remove-LogText -Control SCLogText
            $SyncHash.Host.Runspace.Events.GenerateEvent("Button_SiteConfigurationInstall_Click", $SyncHash.Button_SiteConfigurationInstall, $null, "")
        })

        # Site System Roles - Events
        $SyncHash.Button_SiteSystemInstall.Add_Click({
            $SyncHash.SSRFeatureSelection = $SyncHash.ComboBox_SiteSystemSelection.SelectedValue
            Remove-LogText -Control SSRLogText
            $SyncHash.Host.Runspace.Events.GenerateEvent("Button_SiteSystemInstall_Click", $SyncHash.Button_SiteSystemInstall, $null, "")
        })

        # Active Directory - Events
        $SyncHash.Button_ADExtendBrowse.Add_Click({
            Get-DirectoryLocationForTextBoxControl -Message "Browse the Configuration Manager installation media and select the SMSSETUP\BIN\X64 folder:" -Control TextBox_ADExtend
        })
        $SyncHash.Button_ADExtend.Add_Click({
            $SyncHash.Host.Runspace.Events.GenerateEvent("Button_ADExtend_Click", $SyncHash.Button_ADExtend, $null, "")
        })
        $SyncHash.Button_ADContainerSearch.Add_Click({
            $SyncHash.ADObservableCollection.Clear()
            $SyncHash.Button_ADContainerConfigure.IsEnabled = $false
            $SyncHash.Host.Runspace.Events.GenerateEvent("Button_ADContainerSearch_Click", $SyncHash.Button_ADContainerSearch, $null, "")
        })
        $SyncHash.Button_ADContainerConfigure.Add_Click({
            $SyncHash.Host.Runspace.Events.GenerateEvent("Button_ADContainerConfigure_Click", $SyncHash.Button_ADContainerConfigure, $null, "")
        })
        $SyncHash.DataGrid_ADContainer.Add_SelectionChanged({
            $SyncHash.Button_ADContainerConfigure.IsEnabled = $true
            $SelectedIndex = $SyncHash.DataGrid_ADContainer.SelectedIndex
            $SyncHash.ADGroupSelection = $SyncHash.DataGrid_ADContainer.Items.GetItemAt($SelectedIndex) | Select-Object -ExpandProperty samAccountName
        })

        # Windows ADK - Events
        $SyncHash.Button_ADKBrowse.Add_Click({
            Get-DirectoryLocationForTextBoxControl -Message "Select a folder containing the adksetup.exe file including the redistributable files:" -Control TextBox_ADKPath
        })
        $SyncHash.Button_ADKInstall.Add_Click({
            Remove-LogText -Control ADKLogText
            $SyncHash.Host.Runspace.Events.GenerateEvent("Button_ADKInstall_Click", $SyncHash.Button_ADKInstall, $null, "")
        })

        # WSUS - Events
        $SyncHash.Button_WSUSInstall.Add_Click({
            Remove-LogText -Control WSUSLogText
            $SyncHash.Host.Runspace.Events.GenerateEvent("Button_WSUSInstall_Click", $SyncHash.Button_WSUSInstall, $null, "")
        })

        # GUI update script block (this code will run for each tick in the timer below)
        $GUIUpdateBlock = {
            # Site Configuration
            if ($SyncHash.TabItem_SiteConfiguration.IsSelected -eq $true) {
                # TextBox_SiteConfigurationLog
                $CurrentLogText = $SyncHash.TextBox_SiteConfigurationLog.Text
                if ($CurrentLogText -ne $SyncHash.SCLogText) {
                    $SyncHash.TextBox_SiteConfigurationLog.Text = $SyncHash.SCLogText
                    $SyncHash.TextBox_SiteConfigurationLog.ScrollToEnd()
                }

                # ProgressBar_SiteConfiguration
                $SyncHash.ProgressBar_SiteConfiguration.Value = $SyncHash.SCPercentComplete
                $SyncHash.ProgressBar_SiteConfiguration.Maximum = $SyncHash.SCProgressMaximum

                # Label_SiteConfigurationProgress
                $SyncHash.Label_SiteConfigurationProgress.Content = $SyncHash.SCFeatureLabel
                
                # Label_SiteConfigurationProgressCount
                $SyncHash.Label_SiteConfigurationProgressCount.Content = $SyncHash.SCCountLabel

                # TextBox_SiteConfigurationPrereq
                $SyncHash.SCPrereqLocation = $SyncHash.TextBox_SiteConfigurationPrereq.Text

                # Enable or Disable controls
                switch ($SyncHash.SCXAMLControls) {
                    "InvokeEnable" {
                        Invoke-XAMLControls -Mode Enable -Tab SiteConfiguration
                    }
                    "InvokeDisable" {
                        Invoke-XAMLControls -Mode Disable -Tab SiteConfiguration
                    }
                }
            }

            # Site System Roles
            if ($SyncHash.TabItem_SiteSystemRoles.IsSelected -eq $true) {
                # TextBox_SiteSystemRemote
                if ($SyncHash.TextBox_SiteSystemRemote.Text -notlike [System.String]::Empty) {
                    $SyncHash.SSRRemoteComputer = $SyncHash.TextBox_SiteSystemRemote.Text
                }

                # RadioButton_SiteSystemRemote
                switch ($SyncHash.RadioButton_SiteSystemRemote.IsChecked) {
                    $true {
                        $SyncHash.TextBox_SiteSystemRemote.IsEnabled = $true
                        $SyncHash.CheckBox_SiteSystemCredentials.IsEnabled = $true
                        $SyncHash.SSRRadioButtonRemoteComputerChecked = $true
                    }
                    $false {
                        $SyncHash.TextBox_SiteSystemRemote.IsEnabled = $false
                        $SyncHash.CheckBox_SiteSystemCredentials.IsEnabled = $false
                        $SyncHash.SSRRadioButtonRemoteComputerChecked = $false
                    }
                }

                # RadioButton_SiteSystemLocal
                switch ($SyncHash.RadioButton_SiteSystemLocal.IsChecked) {
                    $true {
                        $SyncHash.SSRRadioButtonLocalComputerChecked = $true
                    }
                    $false {
                        $SyncHash.SSRRadioButtonLocalComputerChecked = $false
                    }
                }

                # CheckBox_SiteSystemCredentials
                if ($SyncHash.CheckBox_SiteSystemCredentials.IsChecked -eq $true) {
                    $SyncHash.SSRCredentialSelected = $true
                }
                else {
                    $SyncHash.SSRCredentialSelected = $false
                }

                # TextBox_SiteSystemLog
                $CurrentLogText = $SyncHash.TextBox_SiteSystemLog.Text
                if ($CurrentLogText -ne $SyncHash.SSRLogText) {
                    $SyncHash.TextBox_SiteSystemLog.Text = $SyncHash.SSRLogText
                    $SyncHash.TextBox_SiteSystemLog.ScrollToEnd()
                }

                # ProgressBar_SiteSystem
                $SyncHash.ProgressBar_SiteSystem.Value = $SyncHash.SSRPercentComplete
                $SyncHash.ProgressBar_SiteSystem.Maximum = $SyncHash.SSRProgressMaximum

                # Label_SiteSystemProgress
                $SyncHash.Label_SiteSystemProgress.Content = $SyncHash.SSRFeatureLabel

                # Label_SiteSystemProgressCount
                $SyncHash.Label_SiteSystemProgressCount.Content = $SyncHash.SSRCountLabel

                # Enable or Disable controls
                switch ($SyncHash.SSRXAMLControls) {
                    "InvokeEnable" {
                        Invoke-XAMLControls -Mode Enable -Tab SiteSystemRoles
                    }
                    "InvokeDisable" {
                        Invoke-XAMLControls -Mode Disable -Tab SiteSystemRoles
                    }
                }
            }

            # Active Directory
            if ($SyncHash.TabItem_ActiveDirectory.IsSelected -eq $true) {
                # TextBox_ADContainerSearch
                if ($SyncHash.TextBox_ADContainerSearch -notlike [System.String]::Empty) {
                    $SyncHash.ADGroupFilter = $SyncHash.TextBox_ADContainerSearch.Text
                }

                # TextBox_ADExtend
                if ($SyncHash.TextBox_ADExtend -notlike [System.String]::Empty) {
                    $SyncHash.ADExtendPath = $SyncHash.TextBox_ADExtend.Text
                }

                # CheckBox_ADContainer
                if ($SyncHash.CheckBox_ADContainer.IsChecked -eq $true) {
                    $SyncHash.ADCreateContainer = $true
                }
                else {
                    $SyncHash.ADCreateContainer = $false
                }

                # TextBox_ADLog
                $CurrentLogText = $SyncHash.TextBox_ADLog.Text
                if ($CurrentLogText -ne $SyncHash.ADLogText) {
                    $SyncHash.TextBox_ADLog.Text = $SyncHash.ADLogText
                    $SyncHash.TextBox_ADLog.ScrollToEnd()
                }

                # DataGrid_ADContainer
                if ($SyncHash.ADObservableCollection.Count -ge 1) {
                    $SyncHash.DataGrid_ADContainer.ItemsSource = $SyncHash.ADObservableCollection
                    if ($SyncHash.DataGrid_ADContainer.Items.NeedsRefresh) {
                        $SyncHash.DataGrid_ADContainer.Items.Refresh()
                    }
                }

                # Enable or Disable controls
                switch ($SyncHash.ADXAMLControls) {
                    "InvokeEnable" {
                        Invoke-XAMLControls -Mode Enable -Tab ActiveDirectory
                    }
                    "InvokeDisable" {
                        Invoke-XAMLControls -Mode Disable -Tab ActiveDirectory
                    }
                }
            }

            # Windows ADK
            if ($SyncHash.TabItem_ADK.IsSelected -eq $true) {
                # ComboBox_ADKVersion
                $SyncHash.ADKSelectedVersion = $SyncHash.ComboBox_ADKVersion.SelectedItem

                # TextBox_ADKLog
                $CurrentLogText = $SyncHash.TextBox_ADKLog.Text
                if ($CurrentLogText -ne $SyncHash.ADKLogText) {
                    $SyncHash.TextBox_ADKLog.Text = $SyncHash.ADKLogText
                    $SyncHash.TextBox_ADKLog.ScrollToEnd()
                }

                # RadioButton_ADKOnline
                switch ($SyncHash.RadioButton_ADKOnline.IsChecked) {
                    $true {
                        $SyncHash.ComboBox_ADKVersion.IsEnabled = $true
                        $SyncHash.Button_ADKBrowse.IsEnabled = $false
                        $SyncHash.TextBox_ADKPath.IsEnabled = $false
                        $SyncHash.ADKRadioButtonOnlineChecked = $true
                    }
                    $false {
                        $SyncHash.ADKRadioButtonOnlineChecked = $false
                    }
                }

                # RadioButton_ADKOffline
                switch ($SyncHash.RadioButton_ADKOffline.IsChecked) {
                    $true {
                        $SyncHash.ComboBox_ADKVersion.IsEnabled = $false
                        $SyncHash.Button_ADKBrowse.IsEnabled = $true
                        $SyncHash.TextBox_ADKPath.IsEnabled = $true
                        $SyncHash.ADKRadioButtonOfflineChecked = $true
                    }
                    $false {
                        $SyncHash.ADKRadioButtonOfflineChecked = $false
                    }
                }

                # TextBox_ADKPath
                if ($SyncHash.RadioButton_ADKOffline.IsChecked -eq $true) {
                    $SyncHash.ADKPath = $SyncHash.TextBox_ADKPath.Text
                }

                # Enable or Disable controls
                switch ($SyncHash.ADKXAMLControls) {
                    "InvokeEnable" {
                        Invoke-XAMLControls -Mode Enable -Tab ADK
                    }
                    "InvokeDisable" {
                        Invoke-XAMLControls -Mode Disable -Tab ADK
                    }
                }
            }

            # WSUS
            if ($SyncHash.TabItem_WSUS.IsSelected -eq $true) {
                # TextBox_WSUSLog
                $CurrentLogText = $SyncHash.TextBox_WSUSLog.Text
                if ($CurrentLogText -ne $SyncHash.WSUSLogText) {
                    $SyncHash.TextBox_WSUSLog.Text = $SyncHash.WSUSLogText
                    $SyncHash.TextBox_WSUSLog.ScrollToEnd()
                }

                # TextBox_WSUSLocation
                if ($SyncHash.TextBox_WSUSLocation.Text -notlike [System.String]::Empty) {
                    $SyncHash.WSUSInstallLocation = $SyncHash.TextBox_WSUSLocation.Text
                }

                # TextBox_WSUSSQLServer
                if ($SyncHash.TextBox_WSUSSQLServer.Text -notlike [System.String]::Empty) {
                    $SyncHash.WSUSSQLServer = $SyncHash.TextBox_WSUSSQLServer.Text
                }

                # TextBox_WSUSSQLInstance
                if ($SyncHash.TextBox_WSUSSQLInstance.Text -notlike [System.String]::Empty) {
                    $SyncHash.WSUSSQLInstance = $SyncHash.TextBox_WSUSSQLInstance.Text
                }

                # ProgressBar_WSUS
                $SyncHash.ProgressBar_WSUS.Value = $SyncHash.WSUSPercentComplete
                $SyncHash.ProgressBar_WSUS.Maximum = $SyncHash.WSUSProgressMaximum
                switch ($SyncHash.WSUSProgressBarMode) {
                    $true {
                        $SyncHash.ProgressBar_WSUS.IsIndeterminate = $true
                    }
                    $false {
                        $SyncHash.ProgressBar_WSUS.IsIndeterminate = $false
                    }
                }
              
                # Label_WSUSProgressCount
                $SyncHash.Label_WSUSProgressCount.Content = $SyncHash.WSUSCountLabel

                # RadioButton_WSUSWID
                switch ($SyncHash.RadioButton_WSUSWID.IsChecked -eq $true) {
                    $true {
                        $SyncHash.TextBox_WSUSSQLServer.IsEnabled = $false
                        $SyncHash.TextBox_WSUSSQLInstance.IsEnabled = $false
                        $SyncHash.WSUSRadioButtonWIDChecked = $true
                        $SyncHash.WSUSSelection = "WID"
                    }
                    $false {
                        $SyncHash.WSUSRadioButtonWIDChecked = $false
                        $SyncHash.WSUSSelection = "SQL"
                    }
                }

                # RadioButton_WSUSSQL
                switch ($SyncHash.RadioButton_WSUSSQL.IsChecked) {
                    $true {
                        $SyncHash.TextBox_WSUSSQLServer.IsEnabled = $true
                        $SyncHash.TextBox_WSUSSQLInstance.IsEnabled = $true
                        $SyncHash.WSUSRadioButtonSQLChecked = $true
                        $SyncHash.WSUSSelection = "SQL"
                    }
                    $false {
                        $SyncHash.WSUSRadioButtonSQLChecked = $false
                        $SyncHash.WSUSSelection = "WID"
                    }
                }

                # Enable or Disable controls
                switch ($SyncHash.WSUSXAMLControls) {
                    "InvokeEnable" {
                        Invoke-XAMLControls -Mode Enable -Tab WSUS
                    }
                    "InvokeDisable" {
                        Invoke-XAMLControls -Mode Disable -Tab WSUS
                    }
                }
            }
        }

        # Before displaying the GUI, create a DispatcherTimer running the GUI update block
        $Global:DispatcherTimer = New-Object -TypeName System.Windows.Threading.DispatcherTimer

        # Run 4 times every second
        $DispatcherTimer.Interval = [TimeSpan]"0:0:0.01"

        # Invoke the GUIUpdateBlock script block
        $DispatcherTimer.Add_Tick($GUIUpdateBlock)

        # Start the DispatcherTimer
        $DispatcherTimer.Start()

        # Show GUI
        $SyncHash.Window.ShowDialog() | Out-Null
    })

    # Invoke code in PowerShellCommand variable assigning it to a runspace
    $PowerShellCommand.Runspace = $Runspace
    $Data = $PowerShellCommand.BeginInvoke()
}
Process {
    # Functions
    function Invoke-Executable {
        param(
            [parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [string]$Path,

            [parameter(Mandatory=$false)]
            [ValidateNotNull()]
            [string]$Arguments,

            [parameter(Mandatory=$false)]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("ADKLogText", "SCLogText", "SSRLogText", "WSUSLogText")]
            [string]$Control
        )
        # Invoke Start-Process cmdlet depending on if Arguments parameter input contains a object
        if ([System.String]::IsNullOrEmpty($Arguments)) {
            try {
                $ReturnValue = Start-Process -FilePath $Path -NoNewWindow -Passthru -Wait -ErrorAction Stop
            }
            catch [System.Exception] {
                Write-LogText -Control $Control -Value $_.Exception.Message
            }
        }
        else {
            try {
                $ReturnValue = Start-Process -FilePath $Path -ArgumentList $Arguments -NoNewWindow -Passthru -Wait -ErrorAction Stop
            }
            catch [System.Exception] {
                Write-LogText -Control $Control -Value $_.Exception.Message
            }
        }

        # Return exit code from executable
        return $ReturnValue.ExitCode
    }

    function Install-WindowsFeatures {
        param(
            [parameter(Mandatory=$true, ParameterSetName="Install")]
            [parameter(Mandatory=$true, ParameterSetName="Validate")]
            [ValidateNotNullOrEmpty()]
            [string]$Feature,

            [parameter(Mandatory=$false, ParameterSetName="Install")]
            [parameter(Mandatory=$true, ParameterSetName="Validate")]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("ADKLogText", "SCLogText", "SSRLogText", "WSUSLogText")]
            [string]$Control,

            [parameter(Mandatory=$true, ParameterSetName="Install")]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("SCPercentComplete", "SSRPercentComplete", "WSUSPercentComplete")]
            [string]$PercentCompleteControl,

            [parameter(Mandatory=$false, ParameterSetName="Install")]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("SCFeatureLabel", "SSRFeatureLabel")]
            [string]$FeatureLabelControl,

            [parameter(Mandatory=$true, ParameterSetName="Install")]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("SCCountLabel", "SSRCountLabel", "WSUSCountLabel")]
            [string]$CountLabelControl,

            [parameter(Mandatory=$true, ParameterSetName="Install")]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("SCProgressMaximum", "SSRProgressMaximum", "WSUSProgressMaximum")]
            [string]$ProgressMaximumControl,

            [parameter(Mandatory=$true, ParameterSetName="Install")]
            [ValidateNotNullOrEmpty()]
            [int]$TotalFeaturesCount,

            [parameter(Mandatory=$true, ParameterSetName="Install")]
            [ValidateNotNullOrEmpty()]
            [int]$CurrentFeatureCount,

            [parameter(Mandatory=$false, ParameterSetName="Install")]
            [ValidateNotNullOrEmpty()]
            [System.Management.Automation.Runspaces.PSSession]$Session,

            [parameter(Mandatory=$true, ParameterSetName="Validate")]
            [ValidateNotNullOrEmpty()]
            [switch]$Validate
        )
        switch ($PSCmdlet.ParameterSetName) {
            "Install" {
                # Handle counts for progressbars
                $SyncHash.$ProgressMaximumControl = $TotalFeaturesCount

                # Populate data to controls being updated in the dispatcher timer
                $SyncHash.$PercentCompleteControl = $CurrentFeatureCount
                if ($PSBoundParameters.ContainsKey("FeatureLabelControl")) {
                    $SyncHash.$FeatureLabelControl = "Installing: " + $Feature
                }
                $SyncHash.$CountLabelControl = $CurrentFeatureCount.ToString() + " / " + $TotalFeaturesCount.ToString()

                # Check if Session parameter have been specified
                if ($PSBoundParameters["Session"]) {
                    # Invoke is session state is opened
                    if ($Session.State -like "Opened") {
                        # Construct the script block that will be executed in the session
                        $SessionBlock = {
                            param(
                                [parameter(Mandatory=$true)]
                                [string]$Feature
                            )
                            Add-WindowsFeature -Name $Feature -ErrorAction Stop
                        }

                        # Invoke script block in session
                        try {
                            Write-LogText -Control $Control -Value ("($($Session.ComputerName)) Installing Windows Feature: " + $Feature)
                            $InstallWindowsFeature = Invoke-Command -Session $Session -ScriptBlock $SessionBlock -ErrorAction Stop -ArgumentList $Feature
                            switch ($InstallWindowsFeature.Success) {
                                $true {
                                    switch ($InstallWindowsFeature.ExitCode) {
                                        "NoChangeNeeded" {
                                            Write-LogText -Control $Control -Value "($($Session.ComputerName)) No change needed for: $($Feature)"
                                        }
                                        "Success" {
                                            Write-LogText -Control $Control -Value "($($Session.ComputerName)) Successfully installed: $($Feature)"
                                        }
                                        "SuccessRestartRequired" {
                                            Write-LogText -Control $Control -Value "($($Session.ComputerName)) Successfully installed, but requires a restart: $($Feature)"
                                        }
                                    }
                                }
                                $false {
                                    Write-LogText -Control $Control -Value "($($Session.ComputerName)) Installation failed for: $($Feature)"
                                }
                            }
                        }
                        catch [System.Exception] {
                            Write-LogText -Control $Control -Value "($($Session.ComputerName)) $($_.Exception.Message)"
                        }
                    }
                }
                else {
                    try {
                        Write-LogText -Control $Control -Value ("($($env:COMPUTERNAME)) Installing Windows Feature: " + $Feature)
                        $InstallWindowsFeature = Add-WindowsFeature -Name $Feature -ErrorAction Stop
                        switch ($InstallWindowsFeature.Success) {
                            $true {
                                switch ($InstallWindowsFeature.ExitCode) {
                                    "NoChangeNeeded" {
                                        Write-LogText -Control $Control -Value "($($env:COMPUTERNAME)) No change needed for: $($Feature)"
                                    }
                                    "Success" {
                                        Write-LogText -Control $Control -Value "($($env:COMPUTERNAME)) Successfully installed: $($Feature)"
                                    }
                                    "SuccessRestartRequired" {
                                        Write-LogText -Control $Control -Value "($($env:COMPUTERNAME)) Successfully installed, but requires a restart: $($Feature)"
                                    }
                                }
                            }
                            $false {
                                Write-LogText -Control $Control -Value "($($env:COMPUTERNAME)) Installation failed for: $($Feature)"
                            }
                        }
                    }
                    catch [System.Exception] {
                        Write-LogText -Control $Control -Value "($($env:COMPUTERNAME)) $($_.Exception.Message)"
                    }
                }
            }
            "Validate" {
                # Perform validation for Windows Feature
                Write-LogText -Control $Control -Value "Validating Windows Feature installation: $($Feature)"

                try {
                    return (Get-WindowsFeature -Name $Feature -ErrorAction Stop).Installed
                }
                catch [System.Exception] {
                    Write-LogText -Control $Control -Value $_.Exception.Message
                }
            }
        }
    }

    function Install-SiteConfigurationWindowsFeatures {
        # Disable XAML controls
        $SyncHash.SCXAMLControls = "InvokeDisable"

        # Determine features to be installed by combobox selection
        switch ($SyncHash.SCFeatureSelection) {
            "System.Windows.Controls.ComboBoxItem: Central Administration Site" { $Features = @("NET-Framework-Core","BITS","BITS-IIS-Ext","BITS-Compact-Server","RDC","WAS-Process-Model","WAS-Config-APIs","WAS-Net-Environment","Web-Server","Web-ISAPI-Ext","Web-ISAPI-Filter","Web-Net-Ext","Web-Net-Ext45","Web-ASP-Net","Web-ASP-Net45","Web-ASP","Web-Windows-Auth","Web-Basic-Auth","Web-URL-Auth","Web-IP-Security","Web-Scripting-Tools","Web-Mgmt-Service","Web-Stat-Compression","Web-Dyn-Compression","Web-Metabase","Web-WMI","Web-HTTP-Redirect","Web-Log-Libraries","Web-HTTP-Tracing","UpdateServices-RSAT","UpdateServices-API","UpdateServices-UI") }
            "System.Windows.Controls.ComboBoxItem: Primary Site" { $Features = @("NET-Framework-Core","BITS","BITS-IIS-Ext","BITS-Compact-Server","RDC","WAS-Process-Model","WAS-Config-APIs","WAS-Net-Environment","Web-Server","Web-ISAPI-Ext","Web-ISAPI-Filter","Web-Net-Ext","Web-Net-Ext45","Web-ASP-Net","Web-ASP-Net45","Web-ASP","Web-Windows-Auth","Web-Basic-Auth","Web-URL-Auth","Web-IP-Security","Web-Scripting-Tools","Web-Mgmt-Service","Web-Stat-Compression","Web-Dyn-Compression","Web-Metabase","Web-WMI","Web-HTTP-Redirect","Web-Log-Libraries","Web-HTTP-Tracing","UpdateServices-RSAT","UpdateServices-API","UpdateServices-UI") }
            "System.Windows.Controls.ComboBoxItem: Secondary Site" { $Features = @("NET-Framework-Core","BITS","BITS-IIS-Ext","BITS-Compact-Server","RDC","WAS-Process-Model","WAS-Config-APIs","WAS-Net-Environment","Web-Server","Web-ISAPI-Ext","Web-Windows-Auth","Web-Basic-Auth","Web-URL-Auth","Web-IP-Security","Web-Scripting-Tools","Web-Mgmt-Service","Web-Metabase","Web-WMI") }
        }

        # Handle download of prerequisite files
        if (($SyncHash.SCPrereqLocation.Length -ge 4) -and ($SyncHash.SCFeatureSelection -notlike "System.Windows.Controls.ComboBoxItem: Secondary Site")) {
            # Output that prerequisites files will be attempted to be downloaded
            Write-LogText -Control SCLogText -Value "Detected that prerequisites files should be downloaded, constructing path for setupdl.exe"

            # Construct SETUPDL.EXE path
            $SetupDLPath = Join-Path -Path $SyncHash.SCPrereqLocation -ChildPath "setupdl.exe"

            # Validate that constructed SETUPDL.EXE path exists
            if (Test-Path -Path $SetupDLPath -PathType Leaf) {
                # Output that SETUPDL.EXE was successfully detected
                Write-LogText -Control SCLogText "Successfully determined location for setupdl.exe"

                # Construct prerequisites files download location
                $PrereqFilesPath = (Join-Path -Path $env:SystemDrive -ChildPath "CMPrereqs")

                # Invoke SETUPDL.EXE with arguments
                Write-LogText -Control SCLogText -Value "Starting download of prerequisites files to $($PrereqFilesPath)"
                do {
                    $SetupDLExecution = Invoke-Executable -Path $SetupDLPath -Arguments $PrereqFilesPath
                }
                until ((Get-ChildItem -Path $PrereqFilesPath | Measure-Object).Count -ge 59)
            }
            else {
                Write-LogText -Control SCLogText "Unable to determined location for setupdl.exe, please specify the proper location on the Configuration Manager installation media"
            }
        }
        else {
            # Output that download of prerequisites files will be skipped
            Write-LogText -Control SCLogText "Download of prerequisites files will be skipped"
        }

        # Handle counts for progressbar
        $CurrentFeatureCount = 0

        # Write start log text
        Write-LogText -Control SCLogText "Starting Windows Features installation locally on '$($env:COMPUTERNAME)'"

        # Process each feature for installation
        foreach ($Feature in $Features) {
            # Increase feature count
            $CurrentFeatureCount++

            # Install current Windows Feature
            Install-WindowsFeatures -Feature $Feature -Control SCLogText -PercentCompleteControl SCPercentComplete -FeatureLabelControl SCFeatureLabel -CountLabelControl SCCountLabel -ProgressMaximumControl SCProgressMaximum -TotalFeaturesCount ($Features | Measure-Object).Count -CurrentFeatureCount $CurrentFeatureCount
        }

        # Write completion results
        Write-LogText -Control SCLogText "Successfully installed Windows Features locally on '$($env:COMPUTERNAME)'"

        # Update UI with completed results
        $SyncHash.SCFeatureLabel = "Finished"
        $SyncHash.SCCountLabel = [System.String]::Empty

        # Enable XAML controls
        $SyncHash.SCXAMLControls = "InvokeEnable"
    }

    function Install-SiteSystemRolesWindowsFeatures {
        # Disable XAML controls
        $SyncHash.SSRXAMLControls = "InvokeDisable"

        # Determine features to be installed by combobox selection
        switch ($SyncHash.SSRFeatureSelection) {
            "System.Windows.Controls.ComboBoxItem: Management Point" { $Features = @("NET-Framework-Core","NET-Framework-45-Features","NET-Framework-45-Core","NET-WCF-TCP-PortSharing45","NET-WCF-Services45","BITS","BITS-IIS-Ext","BITS-Compact-Server","RSAT-Bits-Server","Web-Server","Web-WebServer","Web-ISAPI-Ext","Web-WMI","Web-Metabase","Web-Windows-Auth","Web-ISAPI-Ext","Web-ASP","Web-Asp-Net","Web-Asp-Net45") }
            "System.Windows.Controls.ComboBoxItem: Distribution Point" { $Features = @("FS-FileServer","RDC","Web-WebServer","Web-Common-Http","Web-Default-Doc","Web-Dir-Browsing","Web-Http-Errors","Web-Static-Content","Web-Http-Redirect","Web-Health","Web-Http-Logging","Web-Performance","Web-Stat-Compression","Web-Security","Web-Filtering","Web-Windows-Auth","Web-App-Dev","Web-ISAPI-Ext","Web-Mgmt-Tools","Web-Mgmt-Console","Web-Mgmt-Compat","Web-Metabase","Web-WMI","Web-Scripting-Tools") }
            "System.Windows.Controls.ComboBoxItem: Application Catalog" { $Features = @("NET-Framework-Features","NET-Framework-Core","NET-HTTP-Activation","NET-Non-HTTP-Activ","NET-WCF-Services45","NET-WCF-HTTP-Activation45","RDC","WAS","WAS-Process-Model","WAS-NET-Environment","WAS-Config-APIs","Web-Server","Web-WebServer","Web-Common-Http","Web-Static-Content","Web-Default-Doc","Web-App-Dev","Web-ASP-Net","Web-ASP-Net45","Web-Net-Ext","Web-Net-Ext45","Web-ISAPI-Ext","Web-ISAPI-Filter","Web-Security","Web-Windows-Auth","Web-Filtering","Web-Mgmt-Tools","Web-Mgmt-Console","Web-Scripting-Tools","Web-Mgmt-Compat","Web-Metabase","Web-Lgcy-Mgmt-Console","Web-Lgcy-Scripting","Web-WMI") }
            "System.Windows.Controls.ComboBoxItem: State Migration Point" { $Features = @("Web-Server","Web-Common-Http","Web-Default-Doc","Web-Dir-Browsing","Web-Http-Errors","Web-Static-Content","Web-Http-Logging","Web-Dyn-Compression","Web-Filtering","Web-Windows-Auth","Web-Mgmt-Tools","Web-Mgmt-Console") }
            "System.Windows.Controls.ComboBoxItem: Enrollment Point" { $Features = @("Web-Server","Web-WebServer","Web-Default-Doc","Web-Dir-Browsing","Web-Http-Errors","Web-Static-Content","Web-Http-Logging","Web-Stat-Compression","Web-Filtering","Web-Net-Ext","Web-Asp-Net","Web-ISAPI-Ext","Web-ISAPI-Filter","Web-Mgmt-Console","Web-Metabase","NET-Framework-Core","NET-Framework-Features","NET-HTTP-Activation","NET-Framework-45-Features","NET-Framework-45-Core","NET-Framework-45-ASPNET","NET-WCF-Services45","NET-WCF-TCP-PortSharing45") }
            "System.Windows.Controls.ComboBoxItem: Enrollment Proxy Point" { $Features = @("Web-Server","Web-WebServer","Web-Default-Doc","Web-Dir-Browsing","Web-Http-Errors","Web-Static-Content","Web-Http-Logging","Web-Stat-Compression","Web-Filtering","Web-Windows-Auth","Web-Net-Ext","Web-Net-Ext45","Web-Asp-Net","Web-Asp-Net45","Web-ISAPI-Ext","Web-ISAPI-Filter","Web-Mgmt-Console","Web-Metabase","NET-Framework-Core","NET-Framework-Features","NET-Framework-45-Features","NET-Framework-45-Core","NET-Framework-45-ASPNET","NET-WCF-Services45","NET-WCF-TCP-PortSharing45") }
        }

        # Handle counts for progressbar
        $CurrentFeatureCount = 0

        # Install Windows Features locally
        if ($SyncHash.SSRRadioButtonLocalComputerChecked -eq $true) {
            # Write start log text
            Write-LogText -Control SSRLogText "Starting Windows Features installation locally on '$($env:COMPUTERNAME)'"
            
            # Process each feature for installation
            foreach ($Feature in $Features) {
                # Increase feature count
                $CurrentFeatureCount++

                # Install current Windows Feature
                Install-WindowsFeatures -Feature $Feature -Control SSRLogText -PercentCompleteControl SSRPercentComplete -FeatureLabelControl SSRFeatureLabel -CountLabelControl SSRCountLabel -ProgressMaximumControl SSRProgressMaximum -TotalFeaturesCount ($Features | Measure-Object).Count -CurrentFeatureCount $CurrentFeatureCount
            }

            # Write completion results
            Write-LogText -Control SSRLogText "Successfully installed Windows Features locally on '$($env:COMPUTERNAME)'"
        }

        # Install Windows Features remotely
        if ($SyncHash.SSRRadioButtonRemoteComputerChecked -eq $true) {
            if ($SyncHash.SSRRemoteComputer -notlike [System.String]::Empty) {
                # Build remote computer variable
                $RemoteComputers = $SyncHash.SSRRemoteComputer

                # Determine a single or multiple remote computers have been specified
                if ($RemoteComputers -match ",") {
                    # Log that multiple remote computers where detected
                    Write-LogText -Control SSRLogText -Value "Multiple remote computers where detected, constructing array of sessions to establish"

                    # Clean string containing remote computers from spaces, tabs and other unwanted characters
                    $RemoteComputers = $RemoteComputers -replace '(^\s+|\s+$)','' -replace '\s+',''

                    # Construct remote computers array list
                    $RemoteComputersList = New-Object -TypeName System.Collections.ArrayList

                    # Split remote computers and add to array list
                    foreach ($RemoteComputer in ($RemoteComputers -split ",")) {
                        $RemoteComputersList.Add($RemoteComputer)
                    }

                    # Update remote computers variable
                    $RemoteComputers = $RemoteComputersList
                }

                # Construct PSSession arguments hash table
                $PSSessionArguments = New-Object -TypeName System.Collections.Hashtable

                # Amend arguments with alternate credentials if selected
                if ($SyncHash.SSRCredentialSelected -eq $true) {
                    # Output asking for credential
                    Write-LogText -Control SSRLogText -Value "Alternate credentials was selected, prompting for credentials"

                    # Prompt for credential
                    $PSCredential = Get-Credential
                    while ($PSCredential -eq [System.Management.Automation.PSCredential]::Empty) {
                        $PSCredential = Get-Credential
                    }

                    # Add credential to arguments
                    $PSSessionArguments.Add("Credential", $PSCredential)
                }
                
                foreach ($RemoteComputer in $RemoteComputers) {
                    # Establish remote sessions
                    try {
                        # Add default parameters to PSSession arguments
                        if (-not($PSSessionArguments.ContainsKey("ComputerName"))) {
                            $PSSessionArguments.Add("ComputerName", $RemoteComputer)
                        }
                        if (-not($PSSessionArguments.ContainsKey("ErrorAction"))) {
                            $PSSessionArguments.Add("ErrorAction", "Stop")
                        }

                        $PSSession = New-PSSession @PSSessionArguments
                        if ($PSSession.State -like "Opened") {
                            # Log that remote session was opened and feature installation will begin
                            Write-LogText -Control SSRLogText -Value "Successfully established session to $($RemoteComputer)"
                            Write-LogText -Control SSRLogText -Value "Starting Windows Features installation remotely on $($RemoteComputer)"

                            # Process each feature for installation
                            foreach ($Feature in $Features) {
                                # Increase feature count
                                $CurrentFeatureCount++

                                # Install current Windows Feature
                                Install-WindowsFeatures -Feature $Feature -Control SSRLogText -PercentCompleteControl SSRPercentComplete -FeatureLabelControl SSRFeatureLabel -CountLabelControl SSRCountLabel -ProgressMaximumControl SSRProgressMaximum -TotalFeaturesCount ($Features | Measure-Object).Count -CurrentFeatureCount $CurrentFeatureCount -Session $PSSession
                            }

                            # Dispose of PSSession
                            Disconnect-PSSession -Session $PSSession
                            Write-LogText -Control SSRLogText -Value "Disconnected established session to $($RemoteComputer)"

                            # Write completion results
                            Write-LogText -Control SSRLogText "Successfully installed Windows Features remotely on $($RemoteComputer)"

                            # Reset current feature count
                            $CurrentFeatureCount = 0
                        }
                        else {
                            Write-LogText -Control SSRLogText -Value $PSSession.State
                        }
                    }
                    catch [System.Exception] {
                        Write-LogText -Control SSRLogText -Value $_.Exception.Message
                    }
                }
            }
            else {
                Write-LogText -Control SSRLogText -Value "Empty value for remote computers field detected"
            }
        }

        # Update UI with completed results
        $SyncHash.SSRFeatureLabel = "Finished"
        $SyncHash.SSRCountLabel = [System.String]::Empty

        # Enable XAML controls
        $SyncHash.SSRXAMLControls = "InvokeEnable"
    }

    function Invoke-ADExtend {
        # Disable XAML controls
        $SyncHash.ADXAMLControls = "InvokeDisable"

        # Check whether path for EXTADSCH.EXE path is provided
        if ($SyncHash.ADExtendPath -notlike [System.String]::Empty) {
            
            $ADExtendPath = Join-Path -Path $SyncHash.ADExtendPath -ChildPath "extadsch.exe"

            # Validate EXTADSCH.EXE exists in provided path
            if (Test-Path -Path $ADExtendPath) {
                # Output what path will be used for EXTADSCH.EXE
                Write-LogText -Control ADLogText -Value "Detected extadsch.exe in the following location $($SyncHash.ADExtendPath)"

                # Determine Schema Master FSMO role owner domain controller in current forest
                $CurrentADForest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
                $SchemaMasterOwner = $CurrentADForest.SchemaRoleOwner | Select-Object -ExpandProperty Name

                # Establish a PSSession to Schema Master
                if ($SchemaMasterOwner -ne $null) {
                    # Output that Schema Master role owner domain controller was successfully located
                    Write-LogText -Control ADLogText -Value "Successfully located Schema Master FSMO role owner: $($SchemaMasterOwner)"

                    # Copy EXTADSCH.EXE to Schema Master role owner
                    try {
                        Copy-Item -Path $ADExtendPath -Destination "\\$($SchemaMasterOwner)\C$" -Force -ErrorAction Stop
                        Write-LogText -Control ADLogText -Value "Successfully copied extadsch.exe to \\$($SchemaMasterOwner)\C$"
                        $ExtendADCopyOperation = $true
                    }
                    catch [System.Exception] {
                        Write-LogText -Control ADLogText -Value "Unable to copy EXTADSCH.EXE to Schema Master role owner domain controller" ; $ExtendADCopyOperation = $false
                    }

                    # Continue if copy operation was successfull
                    if ($ExtendADCopyOperation -eq $true) {
                        try {
                            # Create a new PSSession towards the Schema Master role owner
                            $ADPSSession = New-PSSession -ComputerName $SchemaMasterOwner -ErrorAction Stop

                            # Script block that will be executed on the Schema Master domain controller
                            $ADExtendBlock = {
                                # Create a new process
                                try {
                                    $ExtendADProcess = Invoke-WmiMethod -Class "Win32_Process" -Name "Create" -ArgumentList "C:\EXTADSCH.EXE"
                                }
                                catch [System.Exception] {
                                    Write-LogText -Control ADLogText -Value "Unable to create process for executing extadsch.exe, error message was: $($_.Exception.Message)"
                                }

                                # Wait for extadsch.exe to complete
                                do {
                                    Start-Sleep -Milliseconds 500
                                }
                                until ((Get-Process -Id $ExtendADProcess.ProcessId -ErrorAction SilentlyContinue) -eq $null)

                                # Remove extadsch.exe file
                                try {
                                    Remove-Item -Path "C:\EXTADSCH.EXE" -Force
                                }
                                catch [System.Exception] {
                                    Write-LogText -Control ADLogText -Value "Unable to remove extadsch.exe, error message was: $($_.Exception.Message)"
                                }
                            }

                            if ($ADPSSession.State -like "Opened") {
                                # Output that PSSession was sucessfully established
                                Write-LogText -Control ADLogText -Value "Successfully established session to $($SchemaMasterOwner)"

                                # Invoke script block on Schema Master domain controller
                                try {
                                    Invoke-Command -Session $ADPSSession -ScriptBlock $ADExtendBlock -ErrorAction Stop

                                    # Output that execution of extadsch.exe was successfull
                                    Write-LogText -Control ADLogText -Value "Successfully executed extadsch.exe on $($SchemaMasterOwner)"
                                    Write-LogText -Control ADLogText -Value "Schema has successfully been extended for Configuration Manager"
                                    Write-LogText -Control ADLogText -Value "Refer to ExtADSch.log in the root of the C: volume on $($SchemaMasterOwner) for more details"
                                }
                                catch [System.Exception] {
                                    Write-LogText -Control ADLogText -Value "An error occured while executing extadsch.exe, error message was: $($_.Exception.Message)"
                                }

                                # Disconnect established PSSession
                                Disconnect-PSSession -Session $ADPSSession

                                # Output that PSSession was disconnected
                                Write-LogText -Control ADLogText -Value "Disconnected established session to $($SchemaMasterOwner)"
                            }
                        }
                        catch [System.Exception] {
                            Write-LogText -Control ADLogText -Value $_.Exception.Message
                        }
                    }
                }
                else {
                    Write-LogText -Control ADLogText -Value "Unable to determine Schema Master FSMO role owner domain controller"
                }
            }
            else {
                Write-LogText -Control ADLogText -Value "Could not locate extadsch.exe in the specified path"
            }
        }
        else {
            Write-LogText -Control ADLogText -Value "Empty path detected, please specify a valid path"
        }

        # Enable XAML controls
        $SyncHash.ADXAMLControls = "InvokeEnable"
    }

    function Invoke-ADContainerSearch {
        # Define Active Directory group filter and construct a DirectorySearcher object
        $ADGroupsLDAPFilter = "(&(ObjectCategory=group)(samAccountName=*$($SyncHash.ADGroupFilter)*))"
        $ADGroupDirectorySearcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher -ArgumentList $ADGroupsLDAPFilter

        # An ObservableCollection requires an object type of Object[], therefor create a regular array list
        $ADGroupResults = @()

        # Search through Active Directory for groups matching specified filter and add each results to array list object
        foreach ($ADGroup in ($ADGroupDirectorySearcher.FindAll())) {
            $PSObject = [PSCustomObject]@{
                Name = ([string]$ADGroup.Properties.Item("name"))
                samAccountName = ([string]$ADGroup.Properties.Item("samaccountname"))
            }
            $ADGroupResults += $PSObject
        }
        
        # Construct new ObservableCollection object to hold the Active Directory group search results
        $ObservableCollection = New-Object -TypeName System.Collections.ObjectModel.ObservableCollection[Object] -ArgumentList @(,$ADGroupResults)

        # Set shared SyncHash property
        $SyncHash.ADObservableCollection = $ObservableCollection
    }

    function Invoke-ADConfigure {
        # Disable XAML controls
        $SyncHash.ADXAMLControls = "InvokeDisable"

        # Determine whether the System Management container should be created or not
        if ($SyncHash.ADCreateContainer -eq $true) {
            # Validate existence of System Management container
            $ADFilter = "(&(objectClass=container)(cn=*System Management*))"
            $ADDirectorySearcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher -ArgumentList $ADFilter
            if ($ADDirectorySearcher.FindOne() -ne $null) {
                # Output that System Management container was found
                Write-LogText -Control ADLogText -Value "System Management container already exist, will not attempt to create it"
            }
            else {
                # Output that System Management container was not found
                Write-LogText -Control ADLogText -Value "System Management container was not detected, attempting to create it"

                # Create System Management container
                try {
                    $ADDirectoryEntry = New-Object -TypeName System.DirectoryServices.DirectoryEntry
                    $ADSystemManagementContainer = $ADDirectoryEntry.Create("container", "CN=System Management,CN=System")
                    $ADSystemManagementContainer.SetInfo()
                }
                catch [System.Exception] {
                    Write-LogText -Control ADLogText -Value "Unable to create the System Management container. Error message: $($_.Exception.Message)"
                }

                # Validate that container was created successfully
                if ($ADDirectorySearcher.FindOne() -ne $null) {
                    Write-LogText -Control ADLogText -Value "Successfully created the System Management container"
                }
                else {
                    Write-LogText -Control ADLogText -Value "Unable to locate the System Management container after an attempt for creating it was made"
                }
            }
        }
        
        # Add AD group to System Management container
        if ($SyncHash.ADGroupSelection -notlike [System.String]::Empty) {           
            # Determine the domain distinguished name
            $ADDomain = New-Object -TypeName System.DirectoryServices.DirectoryEntry | Select-Object -ExpandProperty distinguishedName
            if ($ADDomain -ne $null) {
                # Output attempting to detect domain distinguished name
                Write-LogText -Control ADLogText -Value "Attempting to determine distinguished name for domain"

                # Construct directory searcher to locate selected Active Directory group from the datagrid
                $ADDirectorySearcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher("(&(ObjectCategory=group)(samAccountName=$($SyncHash.ADGroupSelection)))")
                $ADGroupResult = $ADDirectorySearcher.FindOne()
                if ($ADGroupResult -ne $null) {
                    # Determine the selected Active Directory group SID
                    [System.Security.Principal.SecurityIdentifier]$ADGroupSID = (New-Object -TypeName System.Security.Principal.SecurityIdentifier($ADGroupResult.Properties["objectSID"][0],0)).Value

                    # Construct ADSI object for System Management container
                    $SystemManagementContainer = [ADSI]("LDAP://CN=System Management,CN=System,$($ADDomain)")

                    # Output enumeration for AccessRules
                    Write-LogText -Control ADLogText -Value "Enumerating AccessRules for System Management container"

                    # Loop through all the access rules for the System Management container and add them to an array list
                    $AccessRulesList = New-Object -TypeName System.Collections.ArrayList
                    foreach ($AccessRule in $SystemManagementContainer.ObjectSecurity.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])) {
                        $AccessRulesList.Add($AccessRule.IdentityReference.Value)
                    }

                    # Check whether selected Active Directory group SID is in the array list, if not then add group to System Management container 
                    if ($ADGroupSID.Value -notin $AccessRulesList) {
                        # Output that the selected Active Directory group will be added to the System Management container
                        Write-LogText -Control ADLogText -Value "Adding new AccessRule for group $($SyncHash.ADGroupSelection) to the System Management container"

                        # Add new AccessRule and commit changes
                        try {
                            $ADAccessRule = New-Object -TypeName System.DirectoryServices.ActiveDirectoryAccessRule($ADGroupSID, "GenericAll", "Allow", "All", ([System.Guid]::Empty))
                            $SystemManagementContainer.ObjectSecurity.AddAccessRule($ADAccessRule)
                            $SystemManagementContainer.CommitChanges()

                            # Validate that the Active Directory group was added to the AccessRules
                            $AccessRulesList.Clear()
                            foreach ($AccessRule in $SystemManagementContainer.ObjectSecurity.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])) {
                                $AccessRulesList.Add($AccessRule.IdentityReference.Value)
                            }
                            if ($ADGroupSID.Value -in $AccessRulesList) {
                                Write-LogText -Control ADLogText -Value "Successfully added $($SyncHash.ADGroupSelection) to the System Management container"
                            }
                            else {
                                Write-LogText -Control ADLogText -Value "Unable to find $($SyncHash.ADGroupSelection) in the AccessRules list for the System Management container"
                            }
                        }
                        catch [System.Exception] {
                            Write-LogText -Control ADLogText -Value "Unable to amend AccessRules. Error message: $($_.Exception.Message)"
                        }
                    }
                    else {
                        Write-LogText -Control ADLogText -Value "Active Directory group $($SyncHash.ADGroupSelection) is already present in the AccessRules list for System Management container"
                    }
                }
                else {
                    Write-LogText -Control ADLogText -Value "Unable to determine the Active Directory group object from selected group"
                }
            }
            else {
                Write-LogText -Control ADLogText -Value "Unable to determine domain distinguished name"
            }
        }
        else {
            Write-LogText -Control ADLogText -Value "An Active Directory group has not been selected"
        }

        # Enable XAML controls
        $SyncHash.ADXAMLControls = "InvokeEnable"
    }

    function Install-WindowsADK {
        # Disable XAML controls
        $SyncHash.ADKXAMLControls = "InvokeDisable"

        # Define installation arguments
        $ADKSetupArguments = "/norestart /q /ceip off /features OptionId.WindowsPreinstallationEnvironment OptionId.DeploymentTools OptionId.UserStateMigrationTool"

        # Validate that Windows ADK is not present on the target system
        $ADKFeaturesList = New-Object -TypeName System.Collections.ArrayList
        $HKLMUninstallKeys = Get-ChildItem -Path HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall
        foreach ($HKLMUninstallKey in $HKLMUninstallKeys) {
            $UninstallKeyDisplayName = (Get-ItemProperty -Path $HKLMUninstallKey.PSPath).DisplayName
            if ($UninstallKeyDisplayName -match "Windows PE x86 x64|User State Migration Tool|Windows Deployment Tools") {
                $ADKFeaturesList.Add($UninstallKeyDisplayName) | Out-Null
            }
        }

        try {
            # Determine whether Windows ADK installation process should be executed based upon presence detection
            if ($ADKFeaturesList.Count -eq 0) {
                # Check for running Windows ADK processes
                $ADKProcesses = Get-Process -Name "adksetup" -ErrorAction SilentlyContinue
                if ($ADKProcesses -eq $null) {
                    # Execute if Online mode is selected
                    if ($SyncHash.ADKRadioButtonOnlineChecked -eq $true) {
                        # Determine ADK version to be downloaded and installed
                        switch ($SyncHash.ADKSelectedVersion) {
                            "System.Windows.Controls.ComboBoxItem: Windows ADK 10 1607" {
                                $ADKDownloadURL = "https://go.microsoft.com/fwlink/p/?LinkId=526740"
                                $ADKVersion = "Windows ADK 10 1607"
                            }
                            "System.Windows.Controls.ComboBoxItem: Windows ADK 10 1511" {
                                $ADKDownloadURL = "https://go.microsoft.com/fwlink/p/?LinkId=823089"
                                $ADKVersion = "Windows ADK 10 1511"
                            }
                            "System.Windows.Controls.ComboBoxItem: Windows ADK 10 1507" {
                                $ADKDownloadURL = "http://download.microsoft.com/download/8/1/9/8197FEB9-FABE-48FD-A537-7D8709586715/adk/adksetup.exe"
                                $ADKVersion = "Windows ADK 10 1507"
                            }
                            "System.Windows.Controls.ComboBoxItem: Windows ADK 8.1" {
                                $ADKDownloadURL = "http://download.microsoft.com/download/6/A/E/6AEA92B0-A412-4622-983E-5B305D2EBE56/adk/adksetup.exe"
                                $ADKVersion = "Windows ADK 8.1"
                            }
                        }

                        # Output to log textbox that Online mode is executed
                        Write-LogText -Control ADKLogText -Value "Starting download and installation of $($ADKVersion)"

                        # Define Windows ADK download location
                        $ADKDownloadPath = Join-Path -Path $env:WinDir -ChildPath "Temp"

                        # Output to log textbox with selected ADK version
                        Write-LogText -Control ADKLogText -Value "Initiating download for $($ADKVersion) to $($ADKDownloadPath)"

                        # Download the selected version of Windows ADK
                        Start-DownloadFile -URL $ADKDownloadURL -Path $ADKDownloadPath -Name "adksetup.exe" -Control ADKLogText

                        # Validate that the downloaded ADK setup file exists
                        $ADKSetupPath = Join-Path -Path $ADKDownloadPath -ChildPath "adksetup.exe"
                        if (Test-Path -Path $ADKSetupPath -PathType Leaf) {
                            # Output to textbox that the installation of Windows ADK is about to be executed
                            Write-LogText -Control ADKLogText -Value "Starting installation of $($ADKVersion). This process may take some time depending on the performance of the system and available bandwidth. Once the installation has completed, it will be shown below"

                            # Install Windows ADK
                            $ADKSetupReturnValue = Invoke-Executable -Path $ADKSetupPath -Arguments $ADKSetupArguments -Control ADKLogText

                            # Determine installation results based upon exit code returned by Invoke-Executable function
                            switch ($ADKSetupReturnValue) {
                                0 {
                                    Write-LogText -Control ADKLogText -Value "Successfully installed $($ADKVersion) with a exit code of $($ADKSetupReturnValue)"
                                }
                                3010 {
                                    Write-LogText -Control ADKLogText -Value "Successfully installed $($ADKVersion), however the installation returned with exit code of $($ADKSetupReturnValue) that indicates that the system needs to restarted"
                                }
                            }
                        }

                        # Remove downloaded ADK setup file
                        try {
                            Remove-Item -Path $ADKSetupPath -Force -ErrorAction Stop
                            Write-LogText -Control ADKLogText -Value "Successfully removed ADK setup file from download location"
                        }
                        catch [System.Exception] {
                            Write-LogText -Control ADKLogText -Value "Unable to remove ADK setup file from download location. Error message: $($_.Exception.Message)"
                        }

                    }

                    # Execute if the Offline mode is selected
                    if ($SyncHash.ADKRadioButtonOfflineChecked -eq $true) {
                        # Validate if a local path to where the ADK redistributable files are located has been specified
                        if ($SyncHash.ADKPath -notlike [System.String]::Empty) {
                            # Validate that the local path exists
                            if (Test-Path -Path $SyncHash.ADKPath) {
                                # Validate that the adksetup.exe exists in the verified location
                                $ValidateADKSetupPresence = Get-ChildItem -Path $SyncHash.ADKPath -Filter "adksetup.exe"
                                if ($ValidateADKSetupPresence -ne $null) {
                                    # Construct path for adksetup.exe
                                    $ADKSetupPath = Join-Path -Path $SyncHash.ADKPath -ChildPath "adksetup.exe"

                                    # Output to textbox that the installation of Windows ADK is about to be executed
                                    Write-LogText -Control ADKLogText -Value "Starting installation of Windows ADK. This process may take some time depending on the performance of the system and available bandwidth. Once the installation has completed, it will be shown below"

                                    # Install Windows ADK
                                    $ADKSetupReturnValue = Invoke-Executable -Path $ADKSetupPath -Arguments $ADKSetupArguments -Control ADKLogText

                                    # Determine installation results based upon exit code returned by Invoke-Executable function
                                    switch ($ADKSetupReturnValue) {
                                        0 {
                                            Write-LogText -Control ADKLogText -Value "Successfully installed Windows ADK with exit code $($ADKSetupReturnValue)"
                                        }
                                        3010 {
                                            Write-LogText -Control ADKLogText -Value "Successfully installed Windows ADK, however the installation returned with exit code $($ADKSetupReturnValue) that indicates that the system needs to restarted"
                                        }
                                    }
                                }
                                else {
                                    Write-LogText -Control ADKLogText -Value "Unable to detect the presence of adksetup.exe in the specified location"
                                }
                            }
                            else {
                                Write-LogText -Control ADKLogText -Value "Specified path could not be validated, please specify an existing path by using the browse button"
                            }
                        }
                        else {
                            Write-LogText -Control ADKLogText -Value "Please specify a local path to where the ADK redistributable files reside"
                        }
                    }

                    # Output to log textbox that the system should be restarted
                    Write-LogText -Control ADKLogText -Value "In order to complete the installation of Windows ADK, it's recommended that you restart the system"
                }
                else {
                    Write-LogText -Control ADKLogText -Value "Detected running installation of Windows ADK. Abort current installation or terminate all instances of adksetup.exe in order to proceed"
                }
            }
            else {
                Write-LogText -Control ADKLogText -Value "Detected that one or more features of Windows ADK is already installed on this system. Please uninstall any installation of Windows ADK in order to proceed"
            }
        }
        catch [System.Exception] {
            Write-LogText -Control ADKLogText -Value $_.Exception.Message
        }

        # Enable XAML controls
        $SyncHash.ADKXAMLControls = "InvokeEnable"
    }

    function Install-WSUS {
        # Disable XAML controls
        $SyncHash.WSUSXAMLControls = "InvokeDisable"

        # Output validation for WSUS location path is being invoked
        Write-LogText -Control WSUSLogText -Value "Validating path type for WSUS content data: $($SyncHash.WSUSInstallLocation)"

        # Validate that WSUSLocation property contains a valid path
        if (Test-Path -Path $SyncHash.WSUSInstallLocation -PathType Container -IsValid) {
            # Output that WSUS content data location was validated successfully
            Write-LogText -Control WSUSLogText -Value "Successfully validated WSUS content data location"

            # Create WSUS content data location
            if (-not(Test-Path -Path $SyncHash.WSUSInstallLocation)) {
                try {
                    Write-LogText -Control WSUSLogText -Value "Creating WSUS content data location directory: $($SyncHash.WSUSInstallLocation)"
                    New-Item -Path $SyncHash.WSUSInstallLocation -ItemType Directory -Force -ErrorAction Stop
                }
                catch [System.Exception] {
                    Write-LogText -Control WSUSLogText -Value "Unable to create WSUS content data directory. $($_.Exception.Message)"
                }
            }

            # Continue if the WSUS content data location exists
            if (Test-Path -Path $SyncHash.WSUSInstallLocation) {
                # Determine Windows Features to be installed, based upon WID or SQL selection
                switch ($SyncHash.WSUSSelection) {
                    "WID" {
                        $Features = @("UpdateServices","UpdateServices-WidDB","UpdateServices-Services","UpdateServices-RSAT","UpdateServices-API","UpdateServices-UI")
                    }
                    "SQL" {
                        $Features = @("UpdateServices-Services","UpdateServices-RSAT","UpdateServices-API","UpdateServices-UI","UpdateServices-DB")
                    }
                }

                # Handle counts for progressbar
                $CurrentFeatureCount = 0

                # Write start log text
                Write-LogText -Control WSUSLogText "Starting Windows Features installation locally on $($env:COMPUTERNAME)"

                # Process each feature for installation
                foreach ($Feature in $Features) {
                    # Increase feature count
                    $CurrentFeatureCount++

                    # Install current Windows Feature
                    Install-WindowsFeatures -Feature $Feature -Control WSUSLogText -PercentCompleteControl WSUSPercentComplete -CountLabelControl WSUSCountLabel -ProgressMaximumControl WSUSProgressMaximum -TotalFeaturesCount ($Features | Measure-Object).Count -CurrentFeatureCount $CurrentFeatureCount
                }

                # Write completion results
                Write-LogText -Control WSUSLogText "Successfully installed Windows Features locally on '$($env:COMPUTERNAME)'"

                # Enable marquee progressbar style
                $SyncHash.WSUSCountLabel = [System.String]::Empty
                $SyncHash.WSUSProgressBarMode = $true

                # Handle WSUS post installation
                Write-LogText -Control WSUSLogText -Value "Initiating Windows Feature validation for WSUS post installation configuration"
                $InstalledState = New-Object -TypeName System.Collections.Hashtable
                foreach ($Feature in $Features) {
                    # Validate current Windows Feature
                    $InstalledState.Add($Feature, (Install-WindowsFeatures -Feature $Feature -Control WSUSLogText -Validate))
                }
                if (-not($InstalledState.ContainsValue($false))) {
                    # Output that all required Windows Feature were installed
                    Write-LogText -Control WSUSLogText -Value "Successfully detected required Windows Features for WSUS, proceeding with WSUS post installation configuration"

                    # Validate path to wsusutil.exe
                    $WSUSUtilPath = (Join-Path -Path "$($env:ProgramFiles)\Update Services\Tools" -ChildPath "wsusutil.exe")
                    if (Test-Path -Path $WSUSUtilPath) {
                        # Output that wsusutil.exe was detected
                        Write-LogText -Control WSUSLogText -Value "Detected wsusutil.exe at $(Split-Path -Path $WSUSUtilPath -Parent)"

                        # Invoke WSUS post installation configuration depending on selection for SQL or WID
                        switch ($SyncHash.WSUSSelection) {
                            "WID" {
                                $WSUSUtilArgs = "POSTINSTALL CONTENT_DIR=$($SyncHash.WSUSInstallLocation)"
                            }
                            "SQL" {
                                if (($SyncHash.WSUSSQLServer -notlike [System.String]::Empty) -and ($SyncHash.WSUSSQLServer.Length -ge 2)) {
                                    # Determine whether to configure for an SQL instance or not
                                    if (($SyncHash.WSUSSQLInstance -notlike [System.String]::Empty) -and ($SyncHash.WSUSSQLInstance.Length -ge 1)) {
                                        $WSUSUtilArgs = "POSTINSTALL SQL_INSTANCE_NAME=$($SyncHash.WSUSSQLServer)\$($SyncHash.WSUSSQLInstance) CONTENT_DIR=$($SyncHash.WSUSInstallLocation)"
                                    }
                                    else {
                                        $WSUSUtilArgs = "POSTINSTALL SQL_INSTANCE_NAME=$($SyncHash.WSUSSQLServer) CONTENT_DIR=$($SyncHash.WSUSInstallLocation)"
                                    }
                                }
                                else {
                                    Write-LogText -Control WSUSLogText -Value "Please specify a SQL server name"
                                }
                            }
                        }

                        # Invoke WSUS post installation
                        if ($WSUSUtilArgs -ne $null) {
                            # Output WSUS post installation configuration is invoked
                            Write-LogText -Control WSUSLogText -Value "Starting WSUS post installation configuration, this might take a while"

                            # Invoke executable and store return value in variable
                            $WSUSPostInstallationReturnValue = Invoke-Executable -Path $WSUSUtilPath -Arguments $WSUSUtilArgs -Control WSUSLogText

                            # Determine installation results based upon exit code returned by Invoke-Executable function
                            switch ($WSUSPostInstallationReturnValue) {
                                0 {
                                    Write-LogText -Control WSUSLogText -Value "Successfully completed WSUS post installation configuration with exit code $($WSUSPostInstallationReturnValue)"
                                }
                                Default {
                                    Write-LogText -Control WSUSLogText -Value "Unhandled error occurred after WSUS post installation configuration completed. Exit code: $($WSUSPostInstallationReturnValue)"
                                }
                            }
                        }
                    }
                }
                else {
                    Write-LogText -Control WSUSLogText -Value "One or more required Windows Features for WSUS were not installed, aborting WSUS post installation operation"
                }

                # Update UI with completed results
                $SyncHash.WSUSProgressBarMode = $false
                $SyncHash.WSUSPercentComplete = 100
            }
        }
        else {
            Write-LogText -Control WSUSLogText -Value "Unsupported path detected for WSUS installation location, please specify a proper path"
        }

        # Enable XAML controls
        $SyncHash.WSUSXAMLControls = "InvokeEnable"
    }

    function Start-DownloadFile {
	    param(
	        [parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
	        [string]$URL,

	        [parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
	        [string]$Path,

	        [parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
	        [string]$Name,

	        [parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("ADKLogText", "SCLogText", "SSRLogText", "WSUSLogText")]
	        [string]$Control
	    )
        Begin {
    	    # Construct WebClient object
            $WebClient = New-Object -TypeName System.Net.WebClient
        }
	    Process {
            # Create path if it doesn't exist
		    if (-not(Test-Path -Path $Path)) {
			    Write-LogText -Control $Control -Value "Creating download folder: $($Path)"
                try {
                    New-Item -Path $Path -ItemType Directory -Force -ErrorAction Stop
                }
                catch [System.Exception] {
                    Write-LogText -Control $Control -Value "Unable to create download folder. Error message: $($_.Exception.Message)"
                }
            }

            # Output download of specified file has started
            Write-LogText -Control $Control -Value "Downloading $($Name) to $($Path)"

            # Start download of file
    	    $WebClient.DownloadFile($URL, (Join-Path -Path $Path -ChildPath $Name))

            # Validate file was successfully downloaded
            if (Test-Path -Path (Join-Path -Path $Path -ChildPath $Name)) {
                Write-LogText -Control $Control -Value "Successfully downloaded $($Name) to $($Path)"
                return $true
            }
            else {
                return $false
            }
	    }
        End {
            # Dispose of the WebClient object
    	    $WebClient.Dispose()
        }
    }

    function Write-LogText {
        param(
            [parameter(Mandatory=$true)]
            [ValidateSet("SCLogText", "SSRLogText", "ADLogText", "WSUSLogText", "ADKLogText")]
            [string]$Control,

            [parameter(Mandatory=$true)]
            [string]$Value
        )
        # Check if the control contains any content, append if content exists
        if ($SyncHash.$Control.Length -eq 0) {
            $SyncHash.$Control = ("{0:T} - " -f (Get-Date)) + $Value
        }
        else {
            $SyncHash.$Control = $SyncHash.$Control + ("`n{0:T} - " -f (Get-Date)) + $Value
        }
    }

    function Stop-ScriptExecution {
	    # Keep the window open until it has manually been closed
	    do {
		    Start-Sleep -Seconds 1
		    if ($SyncHash.Window.IsVisible -eq $false) {
			    Start-Sleep -Seconds 2
		    }
	    }
	    while ($SyncHash.OnClose -ne $true)
    }

    # Site Configuration - Register events for functions
    Register-EngineEvent -SourceIdentifier "Button_SiteConfigurationInstall_Click" -Action {
        Install-SiteConfigurationWindowsFeatures
    }

    # Site System Roles - Register events for functions
    Register-EngineEvent -SourceIdentifier "Button_SiteSystemInstall_Click" -Action {
        Install-SiteSystemRolesWindowsFeatures
    }

    # Active Directory - Register events for functions
    Register-EngineEvent -SourceIdentifier "Button_ADContainerSearch_Click" -Action {
        Invoke-ADContainerSearch
    }
    Register-EngineEvent -SourceIdentifier "Button_ADContainerConfigure_Click" -Action {
        Invoke-ADConfigure
    }
    Register-EngineEvent -SourceIdentifier "Button_ADExtend_Click" -Action {
        Invoke-ADExtend
    }

    # Windows ADK - Register events for functions
    Register-EngineEvent -SourceIdentifier "Button_ADKInstall_Click" -Action {
        Install-WindowsADK
    }

    # WSUS - Register events for functions
    Register-EngineEvent -SourceIdentifier "Button_WSUSInstall_Click" -Action {
        Install-WSUS
    }

    # Stop script execution in order to prevent script exiting
    Stop-ScriptExecution

    # Unregister events
    $RegisteredEvents = Get-EventSubscriber -SourceIdentifier "Button_*"
    if ($RegisteredEvents -ne $null) {
        foreach ($RegisteredEvent in $RegisteredEvents) {
            Unregister-Event -SourceIdentifier $RegisteredEvent.SourceIdentifier
        }
    }
}