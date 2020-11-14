
# Event: On closure of the window
$UI.Window.Add_Closing({
    
    # Remove any existing jobs
    If ($UI.Job)
    {
        $UI.Job.Stop()
        $UI.Job.Remove()
    }
    If ($UI.EvalJob)
    {
        $UI.EvalJob.Stop()
        $UI.EvalJob.Remove()
    }
    If ($UI.VersionCheckJob)
    {
        $UI.VersionCheckJob.Stop()
        $UI.VersionCheckJob.Remove()
    }

    # Cleanup Reports
    $UI.Reports | foreach {
        Remove-Item $_
    }

})

# Event: When expander expanded
$UI.expander.Add_Expanded{
    
    # Increase the height
    $UI.expander.Height = 150

}

# Event: When expander collapsed
$UI.expander.Add_Collapsed{
    
    # Return to previous height
    $UI.expander.Height = 50

}

# Define code to run when "Get-Configurations" button is clicked or hit enter in textbox
$Code = {

    $ComputerName = $UI.ComputerName.Text

    # Clear the OCs before repopulating
    If ($UI.DataContext[0])
    {
        $UI.DataContext.Clear()      
    }

    If ($UI.Baselines[0])
    {
        $UI.Baselines.Clear()      
    }

    If ($UI.User[0])
    {
        $UI.User.Clear()      
    }

    # Disable the Eval and Refresh buttons
    $UI.BT_Eval.IsEnabled = $false
    $UI.BT_Refresh.IsEnabled = $false

    # Define the code to run in the background job
    $Code = {
        Param($UI,$ComputerName)
        Get-Configurations -UI $UI -ComputerName $ComputerName
    }

    # Remove any existing jobs
    If ($UI.Job)
    {
        $UI.Job.Stop()
        $UI.Job.Remove()
    }
    If ($UI.EvalJob)
    {
        $UI.EvalJob.Stop()
        $UI.EvalJob.Remove()
    }

    # Create and start a background job
    $UI.Job = [BackgroundJob]::new($Code,@($UI,$ComputerName),@("Function:\Get-Configurations","Function:\Write-UILog"))
    $UI.Job.Start()

}

# Event: When "Get-Configurations" button is clicked
$UI.BT_Config.Add_Click{

    Invoke-Command -ScriptBlock $Code

}

# Event: When hit enter in ComputerName textbox
$UI.ComputerName.Add_KeyDown({
    
    if ($_.Key -eq 'Return')
    {
        Invoke-Command -ScriptBlock $Code
    }

})

# Event: When a row is selected in the datagrid
$UI.dataGrid.Add_SelectionChanged({
    
    # Enable the report button
    $UI.BT_Report.IsEnabled = $true

    # Enable (machine-context) or disable (user-context) the eval button
    If ($This.SelectedItem.'Is Machine Target?' -eq $true)
    {
        $UI.BT_Eval.IsEnabled = $true
    }
    Else
    {
        $UI.BT_Eval.IsEnabled = $false
    }

})

# Event: When refresh button is clicked
$UI.BT_Refresh.Add_Click({

    Invoke-Command -ScriptBlock $Code

})

# Event: When report button is clicked
$UI.BT_Report.Add_Click({

    # Get the compliance details XML string
    # For machine-targeted configuration
    If (($UI.Baselines[0] | where {$_.Name -eq $UI.dataGrid.SelectedItem.Name}).IsMachineTarget -eq "True")
    {
        Write-UILog -Severity Information -Message "Generating report for '$($UI.dataGrid.SelectedItem.Name)' baseline" -UI $UI
        $ComplianceDetails = ($UI.Baselines[0] | where {$_.Name -eq $UI.dataGrid.SelectedItem.Name}).ComplianceDetails
    }
    # For user-targeted configuration
    Else
    {
        # If logged-on user was detected
        If ($UI.User)
        {
            Write-UILog -Severity Information -Message "Generating report for '$($UI.dataGrid.SelectedItem.Name)' baseline in context of user '$($UI.User[1])'" -UI $UI
            $ComputerName = $UI.ComputerName.Text
            $ScopeName = ($UI.Baselines[0] | where {$_.Name -eq $UI.dataGrid.SelectedItem.Name}).ScopeName
            $Version = ($UI.Baselines[0] | where {$_.Name -eq $UI.dataGrid.SelectedItem.Name}).Revision
            Try
            {
                # Generate the compliance details in the logged-on user context
                $Report = Invoke-CimMethod -ComputerName $ComputerName -Namespace ROOT\ccm\dcm -ClassName SMS_DesiredConfiguration -MethodName "GetUserReport" -Arguments @{ 
                    Name = $ScopeName; 
                    UserSID = $UI.User[0]; 
                    Version = $Version } -ErrorAction Stop
                $ComplianceDetails = $Report.ComplianceDetails
            }
            Catch
            {
                Write-UILog -Severity Error -Message "Could not generate user report for baseline '$($UI.dataGrid.SelectedItem.Name)' and user $($UI.User[1])'" -UI $UI
                $UI.expander.IsExpanded = $True
                Return
            }
        }
        Else
        {
            Write-UILog -Severity Error -Message "Could not generate user report for baseline '$($UI.dataGrid.SelectedItem.Name)' as no user context was detected.'" -UI $UI
            $UI.expander.IsExpanded = $True
            Return
        }

        # Error is return value is not 0
        If ($Report.ReturnValue -ne 0)
        {
            Write-UILog -Severity Error -Message "Could not generate report: ReturnValue $($Report.ReturnValue)" -UI $UI
            $UI.expander.IsExpanded = $true
            Return
        }
    }

    # Generate the compliance report
    Try
    {
        Generate-Report -ComplianceDetails $ComplianceDetails
    }
    Catch
    {
        Write-UILog -Severity Error -Message "Problem generating report: $_" -UI $UI
        $UI.expander.IsExpanded = $true
    }

})

# Event: When eval button is clicked
$UI.BT_Eval.Add_Click({
    
    $ComputerName = $UI.ComputerName.Text
    $DisplayName = $UI.dataGrid.SelectedItem.Name

    # Disable the report, refresh and eval buttons
    $UI.BT_Report, $UI.BT_Refresh, $this | foreach {
        $_.IsEnabled = $False
    }

    # Write to logging window
    Write-UILog -Severity Information -Message "Triggering evaluation of '$($UI.dataGrid.SelectedItem.Name)' baseline" -UI $UI

    # Remove any existing eval job
    If ($UI.EvalJob)
    {
        $UI.EvalJob.Stop()
        $UI.EvalJob.Remove()
    }

    # Define code to run in background job
    $Code = {

        Param ($UI,$DisplayName,$ComputerName)
        Evaluate-Baseline -UI $UI -DisplayName $DisplayName -ComputerName $ComputerName
         
    }

    # Create and start a background job
    $UI.EvalJob = [BackgroundJob]::new($Code,@($UI,$DisplayName,$ComputerName),@("Function:\Get-Configurations","Function:\Write-UILog","Function:\Evaluate-Baseline"))
    $UI.EvalJob.Start()

})

# Event: Text changed in computername text box
$UI.ComputerName.Add_TextChanged({
    If ($This.Text -ne "")
    {
        $UI.BT_Config.IsEnabled = $true
        $UI.ViewLogs.IsEnabled = $true
    }
    Else
    {
        $UI.BT_Config.IsEnabled = $false
        $UI.ViewLogs.IsEnabled = $false
    }

})

# Useful logs files for DCM
$Logs = @(
    "DCMAgent"
    "DCMReporting"
    "DCMWMIProvider"
    "StateMessage"
    "CIAgent"
    "CIStateStore"
)

# Event: Open log file from menu items
$Logs | foreach {
    $Log = $_

    Switch($Log)
    {
        DCMAgent {$UI.$Log.Add_Click({
            Try
            {
                Write-UILog -Severity Information -Message "Opening DCMAgent.log on $($UI.ComputerName.Text)" -UI $UI
                Invoke-Item -Path "\\$($UI.ComputerName.Text)\C$\Windows\CCM\Logs\DCMAgent.log" -ErrorAction Stop
            }
            Catch
            {
                Write-UILog -Severity Error -Message "Could not open DCMAgent.log on $($UI.ComputerName.Text): $_" -UI $UI
                $UI.expander.IsExpanded = $true
            }
        })
        }
        DCMReporting {$UI.$Log.Add_Click({
            Try
            {
                Write-UILog -Severity Information -Message "Opening DCMReporting.log on $($UI.ComputerName.Text)" -UI $UI
                Invoke-Item -Path "\\$($UI.ComputerName.Text)\C$\Windows\CCM\Logs\DCMReporting.log" -ErrorAction Stop
            }
            Catch
            {
                Write-UILog -Severity Error -Message "Could not open DCMReporting.log on $($UI.ComputerName.Text): $_" -UI $UI
                $UI.expander.IsExpanded = $true
            }
        })
        }
        DCMWMIProvider {$UI.$Log.Add_Click({
            Try
            {
                Write-UILog -Severity Information -Message "Opening DCMWMIProvider.log on $($UI.ComputerName.Text)" -UI $UI
                Invoke-Item -Path "\\$($UI.ComputerName.Text)\C$\Windows\CCM\Logs\DCMWMIProvider.log" -ErrorAction Stop
            }
            Catch
            {
                Write-UILog -Severity Error -Message "Could not open DCMWMIProvider.log on $($UI.ComputerName.Text): $_" -UI $UI
                $UI.expander.IsExpanded = $true
            }
        })
        }
        StateMessage {$UI.$Log.Add_Click({
            Try
            {
                Write-UILog -Severity Information -Message "Opening StateMessage.log on $($UI.ComputerName.Text)" -UI $UI
                Invoke-Item -Path "\\$($UI.ComputerName.Text)\C$\Windows\CCM\Logs\StateMessage.log" -ErrorAction Stop
            }
            Catch
            {
                Write-UILog -Severity Error -Message "Could not open StateMessage.log on $($UI.ComputerName.Text): $_" -UI $UI
                $UI.expander.IsExpanded = $true
            }
        })
        }
        CIAgent {$UI.$Log.Add_Click({
            Try
            {
                Write-UILog -Severity Information -Message "Opening CIAgent.log on $($UI.ComputerName.Text)" -UI $UI
                Invoke-Item -Path "\\$($UI.ComputerName.Text)\C$\Windows\CCM\Logs\CIAgent.log" -ErrorAction Stop
            }
            Catch
            {
                Write-UILog -Severity Error -Message "Could not open CIAgent.log on $($UI.ComputerName.Text): $_" -UI $UI
                $UI.expander.IsExpanded = $true
            }
        })
        }
        CIStateStore {$UI.$Log.Add_Click({
            Try
            {
                Write-UILog -Severity Information -Message "Opening CIStateStore.log on $($UI.ComputerName.Text)" -UI $UI
                Invoke-Item -Path "\\$($UI.ComputerName.Text)\C$\Windows\CCM\Logs\CIStateStore.log" -ErrorAction Stop
            }
            Catch
            {
                Write-UILog -Severity Error -Message "Could not open CIStateStore.log on $($UI.ComputerName.Text): $_" -UI $UI
                $UI.expander.IsExpanded = $true
            }
        })
        }
    }
}

# Event: About menu click
$UI.About.Add_Click({
    $null = $UI.window.Dispatcher.InvokeAsync{$AboutUI.Window.ShowDialog()}.Wait()
})

# Event: Window Loaded
$UI.Window.Add_Loaded({
    # Check if new version is available
    [double]$ThisVersion = $UI.CurrentVersion
    $Code = {
        Param($UI,$ThisVersion)
        Check-CurrentVersion -UI $UI -ThisVersion $ThisVersion
    }
    $UI.VersionCheckJob = [BackgroundJob]::new($Code,@($UI,$ThisVersion),"Function:\Check-CurrentVersion")
    $UI.VersionCheckJob.Start()

})

# Event: Update menu item clicked
$UI.Update.Add_Click({
    # Open link to download current version
    Start-Process "https://gallery.technet.microsoft.com/ConfigMgr-Remote-Compliance-2a9e55f3"
})

# Event: Help menu item clicked
$UI.Help.Add_Click({
    # Open help document

    # Read the XAML code
    [XML]$Xaml = [System.IO.File]::ReadAllLines("$Source\XAML Files\Help.xaml") 

    # Create a synchronized hash table and add the WPF window and its named elements to it
    $HelpUI = [System.Collections.Hashtable]::Synchronized(@{})
    $HelpUI.Window = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml))
    
    # Set icon
    $HelpUI.Window.Icon = "$Source\bin\audit.ico"

    # Read the FlowDocument content
    [XML]$Xaml = [System.IO.File]::ReadAllLines("$Source\XAML Files\HelpFlowDocument.xaml")
    $Reader = New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml
    $XamlDoc = [System.Windows.Markup.XamlReader]::Load($Reader)

    # Add the FlowDocument to the Window
    $HelpUI.Window.AddChild($XamlDoc)

    # Show the window
    $null = $HelpUI.window.Show()
})