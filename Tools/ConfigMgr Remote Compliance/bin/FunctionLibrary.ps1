# Function to retrieve the configurations info from the remote computer
function script:Get-Configurations {
    Param($UI,$ComputerName)

    # Start progress ring
    $UI.Window.Dispatcher.Invoke({
        $UI.Progress.IsIndeterminate = $True
        })

    # Write to logging window
    Write-UILog -Severity Information -Message "Retrieving configurations from $ComputerName" -UI $UI

    # Get CIM instances
    Try
    {
        $Instances = Get-CimInstance -ComputerName $ComputerName -Namespace ROOT\ccm\dcm -ClassName SMS_DesiredConfiguration -OperationTimeoutSec 5 -ErrorAction Stop | Select DisplayName,Version,LastEvalTime,LastComplianceStatus,Status,ComplianceDetails,IsMachineTarget,Name
    }
    Catch
    {
        $Errored = $true
        # Open the expander to show the error
        $UI.Window.Dispatcher.Invoke({
            $UI.expander.IsExpanded = "True"
            $UI.Progress.IsIndeterminate = $false
        })
        Write-UILog -Severity Error -Message "Could not retrieve configurations from $ComputerName`: $_" -UI $UI
        Return
    }

    # Find logged-on user SID
    Try
    {
        $CurrentUserSID = (Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\SMS\CurrentUser -Name UserSID -ErrorAction Stop
        }).UserSID
        $UI.User.Add($CurrentUserSID)
        If ($CurrentUserSID)
        {
            Write-UILog -Severity Information -Message "Found SID for logged-on user: $CurrentUserSID" -UI $UI
        }
        Else
        {
            Write-UILog -Severity Information -Message "No SID found for logged-on user. Perhaps no-one is currently logged on." -UI $UI
        }
    }
    Catch
    {
        Write-UILog -Severity Warning -Message "Could not find SID for logged on user: $_" -UI $UI
    }

    # Translate user SID
    If ($CurrentUserSID)
    {
        Try
        {
            $SID = New-Object System.Security.Principal.SecurityIdentifier ($CurrentUserSID)
            $User = ($SID.Translate( [System.Security.Principal.NTAccount])).Value
            $UI.User.Add($User)
            Write-UILog -Severity Information -Message "Translated SID to $User" -UI $UI
        }
        Catch
        {
            Write-UILog -Severity Warning -Message "Could not translate SID for logged-on user: $_" -UI $UI
        }
    }

    # If instances were found
    If ($Instances)
    {
        # Create an arraylist to hold the baseline info from WMI
        $Baselines = New-Object System.Collections.ArrayList

        # Create a datatable for displaying the data in the datagrid
        $Table = New-Object -TypeName 'System.Data.DataTable'
        [void]$Table.Columns.Add('Name')
        [void]$Table.Columns.Add('Version')
        [void]$Table.Columns.Add('Last Evaluation')
        [void]$Table.Columns.Add('Compliance State')
        [void]$Table.Columns.Add('Evaluation Status')
        [void]$Table.Columns.Add('Is Machine Target?')
        [void]$Table.Columns.Add('User Context')

        # Loop through the instances
        $Instances | foreach {
            $Instance = $_

            # Process Machine-targeted configuration
            If ($Instance.IsMachineTarget -eq $True)
            {
                $Baseline = '' | Select Name, Revision, 'Last Evaluation', 'Compliance State', 'Evaluation Status', ComplianceDetails, IsMachineTarget, 'User Context', 'ScopeName'
                switch($Instance.LastComplianceStatus)
                {
                    0 {$Cstate = "NonCompliant"}
                    1 {$Cstate = "Compliant"}
                    2 {$Cstate = "NotApplicable"}
                    3 {$Cstate = "Unknown"}
                    4 {$Cstate = "Error"}
                    5 {$Cstate = "NotEvaluated"}
                }
    
                switch($Instance.Status)
                {
                    0 {$Estate = "Idle"}
                    1 {$Estate = "Evaluation Started"}
                    2 {$Estate = "Downloading Documents"}
                    3 {$Estate = "In Progress"}
                    4 {$Estate = "Failure"}
                    5 {$Estate = "Reporting"}
                }
    
                # Create the baseline object
                $Baseline.Name = $Instance.DisplayName
                $Baseline.Revision = $Instance.Version
                $Baseline.'Last Evaluation' = $Instance.LastEvalTime
                $Baseline.'Compliance State' = $Cstate
                $Baseline.'Evaluation Status' = $Estate
                $Baseline.ComplianceDetails = $Instance.ComplianceDetails
                $Baseline.IsMachineTarget = $Instance.IsMachineTarget
                $Baseline.'User Context' = "N/A"
                $Baseline.ScopeName = $Instance.Name
    
                # Add the baseline object to the arraylist
                [void]$Baselines.Add($Baseline)
    
                # Add a row to the datatable
                $Table.Rows.Add($Baseline.Name,$Baseline.Revision, $Baseline.'Last Evaluation',$Baseline.'Compliance State', $Baseline.'Evaluation Status', $Baseline.IsMachineTarget, $Baseline.'User Context')
            }
            # Process user-targeted configuration
            Else
            {
                $Baseline = '' | Select Name, Revision, 'Last Evaluation', 'Compliance State', 'Evaluation Status', ComplianceDetails, IsMachineTarget, 'User Context', 'ScopeName'
    
                # Find compliance state of configuration in the logged-on user context
                If ($CurrentUserSID)
                {
                    Try
                    {
                        $PolicyCompliance = (Invoke-CimMethod -ComputerName $ComputerName -Namespace ROOT\ccm\dcm -ClassName SMS_DesiredConfiguration -MethodName "GetComplianceForPolicyType" -Arguments @{ 
                            UserSID = $CurrentUserSID; 
                            PolicyType = $Instance.Name 
                            }).ComplianceState
                    }
                    Catch
                    {
                        Write-UILog -Severity Error -Message "Could not determine compliance state for user-targeted configuration ($($Instance.DisplayName)): $_" -UI $UI
                    }
                }
                Else 
                {
                    $PolicyCompliance = "Unknown"
                }
    
                # Create the baseline object
                $Baseline.Name = $Instance.DisplayName
                $Baseline.Revision = $Instance.Version
                $Baseline.'Last Evaluation' = "Unknown"
                $Baseline.'Compliance State' = $PolicyCompliance
                $Baseline.'Evaluation Status' = "Unknown"
                $Baseline.ComplianceDetails = $Instance.ComplianceDetails
                $Baseline.IsMachineTarget = $Instance.IsMachineTarget
                If ($User)
                {
                    $Baseline.'User Context' = $User
                }
                Else
                {
                    $Baseline.'User Context' = "Unknown"
                }
                $Baseline.ScopeName = $Instance.Name

                # Add the baseline object to the arraylist
                [void]$Baselines.Add($Baseline)
    
                # Add a row to the datatable
                $Table.Rows.Add($Baseline.Name,$Baseline.Revision, $Baseline.'Last Evaluation',$Baseline.'Compliance State', $Baseline.'Evaluation Status', $Baseline.IsMachineTarget, $Baseline.'User Context')
            }
        }
    }
    Else
    {
        If (!$Errored)
        {
            Write-UILog -Severity Warning -Message "No configurations found." -UI $UI
        }
    }

    # Stop the progress ring and enable the refresh button
    $UI.Window.Dispatcher.Invoke({
       $UI.Progress.IsIndeterminate = $False
       $UI.BT_Refresh.IsEnabled = $true
    })

    # If data was found, add to OCs
    If ($Baselines)
    {
        $UI.Baselines.Add($Baselines) 
        $UI.DataContext.Add($Table) 
    }
}

# Function to write to the UI logging window
function script:Write-UILog {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Information","Warning","Error")]
        $Severity,
        [Parameter(Mandatory=$true)]
        [String]
        $Message,
        [Parameter(Mandatory=$true)]
        $UI
    )

    # Set some values based on severity
    Switch($Severity)
    {
        "Information" {$Prefix = "[Information]"; $Colour = "Black"}
        "Warning" {$Prefix = "[Warning]"; $Colour = "Orange"}
        "Error" {$Prefix = "[Error]"; $Colour = "Red"}
    }

    # Get the time
    $Time = "[$((Get-date).ToLongTimeString())]"

    # Call the dispatcher to update the UI
    $UI.Window.Dispatcher.Invoke({
        # Create the textblock
        $TextBlock = New-Object System.Windows.Controls.TextBlock
        $TextBlock.Text = "$Time $Prefix $Message"
        $TextBlock.Foreground = $Colour
        $TextBlock.TextWrapping = [System.Windows.TextWrapping]::Wrap

        # Add the textblock to the UI, move to the next line and scroll to end
        $NewLine = New-Object System.Windows.Documents.LineBreak
        $ui.FlowDocument.Blocks.FirstBlock.AddChild($TextBlock)
        $ui.FlowDocument.Blocks.FirstBlock.AddChild($NewLine)
        $UI.richTextBox.ScrollToEnd()
    })
}

# Function to generate the compliance report
function Generate-Report {
    Param($ComplianceDetails)

    # Set report filename
    $Report = "$env:USERPROFILE\AppData\Local\Temp\Compliance_Report_$(Get-Random).htm"

    # Set path to transform file, either local client or site server client
    $LocalClientPath = "$env:windir\CCM"
    if ($env:SMS_LOG_PATH)
    {
        $SiteServerPath = ($env:SMS_LOG_PATH).Replace("\Microsoft Configuration Manager\logs","")
        $SiteServerPath = $SiteServerPath + "\SMS_CCM"
    }
    If (Test-Path $LocalClientPath)
    {
        $TransformFile = "$LocalClientPath\DCMReportTransform.xsl"
    }
    ElseIf (Test-Path $SiteServerPath)
    {
        $TransformFile = "$SiteServerPath\DCMReportTransform.xsl"
    }
    Else
    {
        Write-UILog -Severity Error -Message "Could not locate DCMReportTransform.xsl in the expected locations." -UI $UI
        Return
    }

    # Load transform file and update the dcm resource and style paths
    $SourceXSL = Get-Content $TransformFile -Raw
    If ($SiteServerPath)
    {
        $SourceXSL = $SourceXSL.Replace("SMS_CCM","Program Files\SMS_CCM")      
    }
    Else
    {
        $SourceXSL = $SourceXSL.Replace("SMS_CCM","Windows\CCM")
    }
    
    # Create stylesheet as xmlreader
    $StyleSheet = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($SourceXSL))
    [void]$StyleSheet.Read()
    
    # Load the compliance details xml string from the wmi data as xmlreader
    $XMLReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($ComplianceDetails))
    [void]$XMLReader.Read()
    
    # Create the output object as xmlwriter
    $XMLWriter = [System.Xml.XmlWriter]::Create($Report)
    
    # Thunderbirds are go...
    $XSLTransform = New-Object System.Xml.Xsl.XslCompiledTransform
    $XSLSettings = New-Object System.Xml.Xsl.XsltSettings
    $XSLSettings.EnableDocumentFunction = $true
    $XMLResolver = New-Object System.Xml.XmlUrlResolver
    $XSLTransform.Load($StyleSheet,$XSLSettings,$XMLResolver)
    $XSLTransform.Transform($XMLReader,$XMLWriter)
    
    # Open the report
    Invoke-Item $Report
    
    # Add to array for cleanup
    $UI.Reports += $Report

    # Cleanup
    $XMLWriter.Dispose()
    $XMLReader.Dispose()
    $StyleSheet.Dispose()
}

# Function to trigger a baseline evaluation
Function script:Evaluate-Baseline {
    Param($UI,$DisplayName,$ComputerName)

    # Start the progress ring
    $UI.Window.Dispatcher.Invoke({
        $UI.Progress.IsIndeterminate = $true
    })

    # Get the instance from WMI
    Try
    {
        $Baseline = Get-CimInstance -ComputerName $ComputerName -Namespace root\ccm\dcm -ClassName SMS_DesiredConfiguration -ErrorAction Stop | Where {$_.DisplayName -eq $DisplayName} | Select IsMachineTarget, Version, Name
    }
    Catch
    {
        Write-UILog -Severity Error -Message "Problem getting CIM Instance: $_" -UI $UI
        $UI.Window.Dispatcher.Invoke({
            $UI.Progress.IsIndeterminate = $false
            $UI.expander.IsExpanded = $true
        })
        Return
    }

    # Define the arguments in hash for the Invoke-CimMethod cmdlet
    $Arguments = @{
        Name = $baseline.Name
        Version = $baseline.Version
        IsMachineTarget = [bool]$Baseline.IsMachineTarget
        IsEnforced = $True
    
    }
    
    # Invoke the method. Operation timeout will wait for 10 minutes. Consider the ScriptExecutionTimeout value in WMI.
    Try
    {
        $UI.Result = Invoke-CimMethod -ComputerName $ComputerName -Namespace ROOT\ccm\dcm -ClassName SMS_DesiredConfiguration -MethodName "TriggerEvaluation" -Arguments $Arguments -ErrorAction Stop -OperationTimeoutSec 601
    }
    Catch
    {
        Write-UILog -Severity Error -Message "Problem trigerring evaluation: $_" -UI $UI
        $UI.Window.Dispatcher.Invoke({
            $UI.Progress.IsIndeterminate = $false
            $UI.expander.IsExpanded = $true
        })
    }

    # Wait until the status of the baseline is Idle (0), Failure (4) or Reporting (5), or timeout of 600 seconds reached
    $Stopwatch = New-Object System.Diagnostics.Stopwatch
    $Stopwatch.Start()
    Do {
       # Wait a couple of seconds for the status to update in WMI
       Start-Sleep -Seconds 2
    }
    Until ((Get-CimInstance -ComputerName $ComputerName -Namespace root\ccm\dcm -ClassName SMS_DesiredConfiguration -ErrorAction Stop | Where {$_.DisplayName -eq $DisplayName}).Status -in (0,4,5) -or $Stopwatch.Elapsed.TotalSeconds -gt 600)
    $Stopwatch.Stop()

    # Wait a couple of seconds for the data to update in WMI
    Start-Sleep -Seconds 2

    # Clear the OCs before refreshing the configurations data again
    If ($UI.DataContext[0])
    {
        $UI.DataContext.Clear()      
    }

    If ($UI.Baselines[0])
    {
        $UI.Baselines.Clear()      
    }

    # Enable the Eval and Refresh buttons
    $UI.Window.Dispatcher.Invoke({
        $UI.BT_Eval.IsEnabled = $false
        $UI.BT_Refresh.IsEnabled = $false
    })
    
    # Refresh the configurations data in the UI
    Get-Configurations -UI $UI -ComputerName $ComputerName

}

# Function to check if a new version has been released
Function Check-CurrentVersion {
    Param($UI,$ThisVersion)

    # Download XML from internet
    Try
    {
        # Use the raw.gihubusercontent.com/... URL
        $URL = "https://raw.githubusercontent.com/SMSAgentSoftware/ConfigMgr-Remote-Compliance/master/Versions/Remote_Compliance_Current.xml"
        $WebClient = New-Object System.Net.WebClient
        $webClient.UseDefaultCredentials = $True
        $ByteArray = $WebClient.DownloadData($Url)
        $WebClient.DownloadFile($url, "$env:USERPROFILE\AppData\Local\Temp\Remote_Compliance_Current.xml")
        $Stream = New-Object System.IO.MemoryStream($ByteArray, 0, $ByteArray.Length)
        $XMLReader = New-Object System.Xml.XmlTextReader -ArgumentList $Stream
        $XMLDocument = New-Object System.Xml.XmlDocument
        [void]$XMLDocument.Load($XMLReader)
        $Stream.Dispose()
    }
    Catch
    {
        Return
    }

    # Add version history to OC
    $UI.VersionHistory.Add($XMLDocument)

    # Create a datatable for the version history
    $Table = New-Object -TypeName 'System.Data.DataTable'
    [void]$Table.Columns.Add('Version')
    [void]$Table.Columns.Add('Release Date')
    [void]$Table.Columns.Add('Changes')

    # Add a row for each version
    $UI.VersionHistory.Remote_Compliance.Versions.Version | sort Value -Descending | foreach {
    
        # The changes are put into an array, then converted to a string with each change on a new line for correct display
        [array]$Changes = $_.Changes.Change
        $ofs = "`r`n"
        $Table.Rows.Add($_.Value, $_.ReleaseDate, [string]$Changes)
    
    }

    # Set the source of the datagrid
    $UI.VersionHistory.Add($Table)

    # Get Current version number
    [double]$CurrentVersion = $XMLDocument.Remote_Compliance.Versions.Version.Value | Sort -Descending | Select -First 1

    # Enable the "Update" menut item to notify user
    If ($CurrentVersion -gt $ThisVersion)
    {
        $UI.Window.Dispatcher.Invoke({
            $UI.Update.Visibility = [System.Windows.Visibility]::Visible
        })
    }

    # Cleanup temp file
    If (Test-Path -Path "$env:USERPROFILE\AppData\Local\Temp\Remote_Compliance_Current.xml")
    {
        Remove-Item -Path "$env:USERPROFILE\AppData\Local\Temp\Remote_Compliance_Current.xml" -Force -Confirm:$false
    }

}

# Popup message function
function New-PopupMessage {
# Return values for reference (https://msdn.microsoft.com/en-us/library/x83z1d9f(v=vs.84).aspx)

# Decimal value    Description  
# -----------------------------
# -1               The user did not click a button before nSecondsToWait seconds elapsed.
# 1                OK button
# 2                Cancel button
# 3                Abort button
# 4                Retry button
# 5                Ignore button
# 6                Yes button
# 7                No button
# 10               Try Again button
# 11               Continue button

# Define Parameters
[CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # The popup message
        [Parameter(Mandatory=$true,Position=0)]
        [string]$Message,

        # The number of seconds to wait before closing the popup.  Default is 0, which leaves the popup open until a button is clicked.
        [Parameter(Mandatory=$false,Position=1)]
        [int]$SecondsToWait = 0,

        # The window title
        [Parameter(Mandatory=$true,Position=2)]
        [string]$Title,

        # The buttons to add
        [Parameter(Mandatory=$true,Position=3)]
        [ValidateSet('Ok','Ok-Cancel','Abort-Retry-Ignore','Yes-No-Cancel','Yes-No','Retry-Cancel','Cancel-TryAgain-Continue')]
        [array]$ButtonType,

        # The icon type
        [Parameter(Mandatory=$true,Position=4)]
        [ValidateSet('Stop','Question','Exclamation','Information')]
        $IconType
    )

# Convert button types
switch($ButtonType)
    {
        "Ok" { $Button = 0 }
        "Ok-Cancel" { $Button = 1 }
        "Abort-Retry-Ignore" { $Button = 2 }
        "Yes-No-Cancel" { $Button = 3 }
        "Yes-No" { $Button = 4 }
        "Retry-Cancel" { $Button = 5 }
        "Cancel-TryAgain-Continue" { $Button = 6 }
    }

# Convert Icon types
Switch($IconType)
    {
        "Stop" { $Icon = 16 }
        "Question" { $Icon = 32 }
        "Exclamation" { $Icon = 48 }
        "Information" { $Icon = 64 }
    }

# Create the popup
(New-Object -ComObject Wscript.Shell).popup($Message,$SecondsToWait,$Title,$Button + $Icon)
}
