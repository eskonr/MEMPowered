New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
New-Item -Path HKCR:\cmfrontend -force | Out-Null
New-ItemProperty -Path HKCR:\cmfrontend -name "(Default)" -Value "URL:CMFrontend Protocol Handler" | Out-Null
New-ItemProperty -path HKCR:\cmfrontend -Name "URL Protocol" -Value "" | Out-Null
New-Item -Path HKCR:\cmfrontend\DefaultIcon -force | Out-Null 
New-ItemProperty -Path HKCR:\cmfrontend\DefaultIcon -name "(Default)" -Value "$($env:programfiles)\CMFrontend\FrontendHelpdeskLauncher.exe" | Out-Null
New-Item -Path HKCR:\cmfrontend\shell -force | Out-Null
New-Item -Path HKCR:\cmfrontend\shell\open -force | Out-Null
New-Item -Path HKCR:\cmfrontend\shell\open\command -force | Out-Null
New-ItemProperty -Path HKCR:\cmfrontend\shell\open\command -name "(Default)" -Value """$($env:programfiles)\CMFrontend\FrontendHelpdeskLauncher.exe"" %1" | Out-Null
New-Item -Path "$($env:programfiles)\CMFrontend" -ItemType directory -Force | Out-Null
Copy-Item "$PSScriptRoot\FrontendHelpdeskLauncher.exe" -Destination "$($env:programfiles)\CMFrontend" -Force | Out-Null
Remove-PSDrive -Name HKCR