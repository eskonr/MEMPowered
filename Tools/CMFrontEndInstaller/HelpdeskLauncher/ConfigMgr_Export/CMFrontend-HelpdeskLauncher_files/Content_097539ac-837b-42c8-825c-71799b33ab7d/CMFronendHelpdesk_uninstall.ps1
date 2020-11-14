New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
Remove-Item -Path HKCR:\cmfrontend -Recurse -Force | Out-Null
Remove-Item -Path "$($env:programfiles)\CMFrontend" -Recurse -Force | Out-Null
Remove-PSDrive -Name HKCR