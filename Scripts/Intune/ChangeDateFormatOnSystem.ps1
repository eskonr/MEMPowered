
# Add the System.Windows.Forms assembly
Add-Type -AssemblyName System.Windows.Forms

# Get the current username
$username = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split('\')[-1]

# Define log file path
$logFolderPath = 'C:\ProgramData\eskonr\InstallLogs\ChangeDateFormat'
$logFilePath = "$logFolderPath\ChangeDateFormat-$username.log"

# Ensure the logging directory exists
if (-not (Test-Path -Path $logFolderPath)) {
    New-Item -Path $logFolderPath -ItemType Directory -Force
}

# Function to log messages
function Log-Message {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "$timestamp - $message"
    Add-Content -Path $logFilePath -Value $logEntry
}

# Create a new form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'eskonr - Change Date Format'  # Set the title of the window
$form.Size = New-Object System.Drawing.Size(400, 250)
$form.StartPosition = 'CenterScreen'

# Create a ComboBox for date format selection
$comboBox = New-Object System.Windows.Forms.ComboBox
$comboBox.Location = New-Object System.Drawing.Point(50, 50)
$comboBox.Size = New-Object System.Drawing.Size(200, 20)
$comboBox.Items.AddRange(@('dd-MM-yyyy', 'MM-dd-yyyy', 'yyyy-MM-dd', 'dd-MMMM-yy'))
$form.Controls.Add($comboBox)

# Create a Button to apply the selected date format
$setButton = New-Object System.Windows.Forms.Button
$setButton.Location = New-Object System.Drawing.Point(50, 100)
$setButton.Size = New-Object System.Drawing.Size(100, 30)
$setButton.Text = 'Set Format'
$setButton.Add_Click({
        $selectedFormat = $comboBox.SelectedItem
        if ($selectedFormat) {
            try {
                $registryPath = 'HKCU:\Control Panel\International'
                Set-ItemProperty -Path $registryPath -Name 'sShortDate' -Value $selectedFormat
                [System.Windows.Forms.MessageBox]::Show("Date format set to $selectedFormat")
                Log-Message "Date format set to $selectedFormat by user $username."
            } catch {
                Log-Message "Failed to set date format to $selectedFormat for user $username. Error: $_"
                [System.Windows.Forms.MessageBox]::Show("Failed to set date format: $_")
            }
            $form.Close() # Close the form after setting
        } else {
            [System.Windows.Forms.MessageBox]::Show('Please select a date format.')
        }
    })
$form.Controls.Add($setButton)

# Create a Cancel Button to close the form without changes
$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(160, 100)
$cancelButton.Size = New-Object System.Drawing.Size(100, 30)
$cancelButton.Text = 'Cancel'
$cancelButton.Add_Click({
        Log-Message "User $username cancelled the operation."
        $form.Close() # Close the form when cancel is clicked
    })
$form.Controls.Add($cancelButton)

# Log the start of the application
Log-Message "User $username opened the Change Date Format application."

# Show the form
$form.ShowDialog()