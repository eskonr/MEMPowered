###############################
## Create the "About" Window ##
###############################

# Read-in XAML file
[XML]$Xaml = [System.IO.File]::ReadAllLines("$Source\XAML Files\About.xaml") 

# Create a synchronized hash table and add the WPF window and its named elements to it
$AboutUI = [System.Collections.Hashtable]::Synchronized(@{})
$AboutUI.Window = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml))
$xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") | ForEach-Object -Process {
    $AboutUI.$($_.Name) = $AboutUI.Window.FindName($_.Name)
    }

# Add an observable collection as a datasource
$AboutUI.Window.DataContext = $UI.VersionHistory

# Set icon
$AboutUI.Window.Icon = "$Source\bin\audit.ico"

# Event: Cancel closure and hide
$AboutUI.Window.Add_Closing({
    $_.Cancel = $True
    $This.Hide()
})

# Event: hyperlink clicks
$AboutUI.BlogLink,$AboutUI.MDLink, $AboutUI.GitLink, $AboutUI.PayPalLink | foreach {

    $_.Add_Click({
        Start-Process $This.NavigateUri
    })

}