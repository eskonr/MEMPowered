<#
Filename: UpdateFileModifiedDate.ps1
Description: This script will change/update the last modified date of each file inside the folder and do recursive.
This is useful incase you have retention policy applied with 1 year or 2 years and post that, files older than last modified attritbute delete automatically.
This script can be useful to run before the end of the 2 year period to extend the last modified date of files inside the folder.
#>

$folder = 'C:\Users\username\OneDrive - eskonr'

# Get all files in the folder and subfolders
foreach ($file in Get-ChildItem -Path $folder -Recurse -File -ErrorAction SilentlyContinue) {
	try {
		# Update the LastWriteTime property of each file
        (Get-Item $file.FullName).LastWriteTime = (Get-Date).AddHours(-5)
	} catch {
		# Log the error and continue with the next file
		Write-Host "An error occurred while updating the file: $($file.FullName)" -ForegroundColor Red
		continue
	}
}