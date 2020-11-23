#SCCM TFTP boot changer 1.0
# Jorgen Nilsson CCMExec.com


$inputXML = @"
<Window x:Name="SCCM_TFTP_Changer" x:Class="WpfApplication1.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:WpfApplication1"
        mc:Ignorable="d"
        Title="SCCM TFTP Changer" Height="267.52" Width="346.414">
    <Grid Margin="0,0,2,-3">
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="48*"/>
            <ColumnDefinition Width="7*"/>
            <ColumnDefinition Width="36*"/>
            <ColumnDefinition Width="246*"/>
        </Grid.ColumnDefinitions>
        <Button x:Name="Save" Content="Save" HorizontalAlignment="Left" Margin="42.8,139,0,0" VerticalAlignment="Top" Width="75" Grid.Column="3"/>
        <Label x:Name="label" Content="TFTP Blocksize value" HorizontalAlignment="Left" Margin="38,35,0,0" VerticalAlignment="Top" Width="177" Grid.ColumnSpan="4"/>
        <Button x:Name="Exit" Content="Exit" HorizontalAlignment="Left" Margin="137.8,139,0,0" VerticalAlignment="Top" Width="75" Grid.Column="3"/>
        <Button x:Name="Restart" Content="Restart WDS" HorizontalAlignment="Left" Margin="38,139,0,0" VerticalAlignment="Top" Width="75" Grid.ColumnSpan="4"/>
        <Label x:Name="label1" Content="TFTP WindowsSize value" HorizontalAlignment="Left" Margin="38,76,0,0" VerticalAlignment="Top" Width="142" Grid.ColumnSpan="4"/>
        <ComboBox x:Name="TFTPBlockSize" Grid.Column="3" HorizontalAlignment="Left" Margin="105.8,39,0,0" VerticalAlignment="Top" Width="120" SelectedIndex="0">
            <ComboBoxItem Content="1024"/>
            <ComboBoxItem Content="1456"/>
            <ComboBoxItem Content="2048"/>
            <ComboBoxItem Content="4096"/>
            <ComboBoxItem Content="8192"/>
            <ComboBoxItem Content="16384"/>
        </ComboBox>
        <ComboBox x:Name="TFTPWindowsSize" Grid.Column="3" HorizontalAlignment="Left" Margin="105.8,76,0,0" VerticalAlignment="Top" Width="120" SelectedIndex="0">
            <ComboBoxItem Content="1"/>
            <ComboBoxItem Content="2"/>
            <ComboBoxItem Content="4"/>
            <ComboBoxItem Content="8"/>
            <ComboBoxItem Content="16"/>
        </ComboBox>
        <TextBox x:Name="textBox" Grid.ColumnSpan="4" HorizontalAlignment="Left" Height="23" Margin="38,182,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="266" IsReadOnly="True"/>
    </Grid>
</Window>
"@       
 
$inputXML = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N'  -replace '^<Win.*', '<Window'
 
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$XAML = $inputXML
#Read XAML
 
    $reader=(New-Object System.Xml.XmlNodeReader $xaml)
  try{$Form=[Windows.Markup.XamlReader]::Load( $reader )}
catch{Write-Host "Unable to load Windows.Markup.XamlReader. Double-check syntax and ensure .net is installed."}
 
#===========================================================================
# Load XAML Objects In PowerShell
#===========================================================================
 
$xaml.SelectNodes("//*[@Name]") | %{Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name)}
 
Function Get-FormVariables{
if ($global:ReadmeDisplay -ne $true){Write-host "If you need to reference this display again, run Get-FormVariables" -ForegroundColor Yellow;$global:ReadmeDisplay=$true}
write-host "Found the following interactable elements from our form" -ForegroundColor Cyan
get-variable WPF*
}
 
#$vmpicklistView.items.Add([pscustomobject]@{'VMName'=($_).Name;Status=$_.Status;Other="Yes"})
$WPFExit.Add_Click({$form.Close()})

$WPFRestart.Add_Click({
$WPFTextbox.Text=("Service is restarting")
start-job -scriptblock {Restart-Service WDSServer}
Start-Sleep -s 3
WaitUntilServices "WDSServer" "Running"
$WPFTextbox.Text=("WDS Service Restarted")})

$WPFSave.Add_Click({
$WPFTextbox.Text=("Write to registry completed")
Try
{
    new-itemproperty "HKLM:\SOFTWARE\Microsoft\SMS\DP" -Name "RamDiskTFTPWindowSize" -Value $WPFTFTPWindowsSize.text -PropertyType Dword -Force -ErrorAction Stop
    new-itemproperty "HKLM:\SOFTWARE\Microsoft\SMS\DP" -Name "RamdiskTFTPBlockSize" -Value $WPFTFTPBlocksize.text -PropertyType Dword -Force -ErrorAction Stop

}
Catch
{
    $WPFTextbox.Text=("Write to registry Failed! Check your permissions")
} 
})

function WaitUntilServices($searchString, $status)
{
    # Get all services where Name matches $searchString and loop through each of them.
    foreach($service in (Get-Service -Name $searchString))
    {
        # Wait for the service to reach the $status or a maximum of 30 seconds
        $service.WaitForStatus($status, '00:01:00')
    }
}
#===========================================================================
# Shows the form
#===========================================================================
# write-host "To show the form, run the following" -ForegroundColor Cyan
$Form.ShowDialog() | out-null
