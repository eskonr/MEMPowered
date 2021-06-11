Option Explicit
Dim FS, TS, WI, DB, View, objHOST 
Dim ProductName, ProductCode, UpgradeCode, PackageCode, ProductVersion
Dim Path_MSI_File, strDiscSpace, Path_Result_File, ProductLanguage
Dim Last_Saved_By, Manufacturer, Creation_Date, Last_Saved
Dim strYourName, strYourName2, strYourName3, strYourName4, strPhoneNr, strCompany, strEmail
Dim strC1, strC2, strC3, strC4
Const conmsiOpenDatabaseModeReadOnly = 0
Set WI = CreateObject("WindowsInstaller.Installer")
Set FS = CreateObject("Scripting.FileSystemObject")
Set objHOST = CreateObject("WScript.Shell")

On Error Resume Next

' Use as is, not A LOT OF support on this script. 

'*********** Start EDIT these lines **************************
strYourName = "YourFirstName" : strYourName2 = "LastName"
strPhoneNr  = "023-54XXX"
strCompany  = "Eskonr"
'Comments examples
strC1 = "Tests have been carried out on a WorkIT PC in a workgroup."
strC2 = "Works without modifications when executed by a standard user."
strC3 = "Tweaked permissions on %ProgramFiles%\Xxxxx\Yyyy folder."
strC4 = "Tweaked permissions to HKLM\Software"
'***********  Stop EDIT now ! F.H  **************************

strYourName3 = Replace(LCase (strYourName),"å","a") 
strYourName3 = Replace(LCase (strYourName3),"ä","a") 
strYourName3 = Replace(LCase (strYourName3),"ö","o") 
strYourName4 = Replace(LCase (strYourName2),"å","a") 
strYourName4 = Replace(LCase (strYourName4),"ä","a") 
strYourName4 = Replace(LCase (strYourName4),"ö","o") 

strEmail = LCase (strYourName3) & "." & LCase (strYourName4) & "@eskonr.com"


Path_MSI_File =  WScript.Arguments(0)

If (FS.FileExists(Path_MSI_File) = False) Then 
	MsgBox "Drop an MSI file on script.", 64
	WScript.Quit
End If   

If Path_MSI_File = "" Then WScript.Quit

strDiscSpace = ConvertKB (MsiSourceFileSize(Path_MSI_File))

Path_Result_File = Path_MSI_File & ".txt"

Set DB = WI.OpenDatabase(Path_MSI_File,0)
'Summary information se at top of script
PackageCode   = DB.SummaryInformation.Property(9)
Last_Saved_By = DB.SummaryInformation.Property(8)
Creation_Date = DB.SummaryInformation.Property(12)
Last_Saved    = DB.SummaryInformation.Property(13)

'Table information
Set View = DB.OpenView("Select `Value` From Property WHERE `Property`='ProductName'")
View.Execute
Set ProductName = View.Fetch

Set View = DB.OpenView("Select `Value` From Property WHERE `Property`='UpgradeCode'")
View.Execute
Set UpgradeCode = View.Fetch

Set View = DB.OpenView("Select `Value` From Property WHERE `Property`='ProductCode'")
View.Execute
Set ProductCode = View.Fetch

Set View = DB.OpenView("Select `Value` From Property WHERE `Property`='Manufacturer'")
View.Execute
Set Manufacturer = View.Fetch

Set View = DB.OpenView("Select `Value` From Property WHERE `Property`='ProductVersion'")
View.Execute
Set ProductVersion = View.Fetch

Set View = DB.OpenView("Select `Value` From Property WHERE `Property`='ProductLanguage'")
View.Execute
Set ProductLanguage = View.Fetch

	If Not ProductName Is Nothing Then
	
	    Set TS = FS.CreateTextFile(Path_Result_File)
	    ' Write Product Row Headings and data to txt File
	    TS.Write vbNewLine + "MSI info!" + vbNewLine+ vbNewLine
	    
	    TS.Write "ProductName         :" + vbTab + ProductName.StringData(1) + vbNewLine
	    TS.Write "ProductVersion      :" + vbTab + ProductVersion.StringData(1) + vbNewLine
	    TS.Write "Creation_Date       :" + vbTab + "" & Creation_Date & "" + vbNewLine
	    TS.Write "Last_Saved          :" + vbTab + "" & Last_Saved & "" + vbNewLine
	    TS.Write "Manufacturer        :" + vbTab + Manufacturer.StringData(1) + vbNewLine
		TS.Write "ProductLanguage     :" + vbTab + ProductLanguage.StringData(1) + vbNewLine + vbNewLine

	    TS.Write "Installed size      :" + vbTab + "" & MsiSourceFileSize(Path_MSI_File) & " KB" + vbNewLine + vbNewLine
	    TS.Write "Installed size [xB] :" + vbTab + "" & strDiscSpace & "" + vbNewLine + vbNewLine
   	    
   	    TS.Write vbNewLine + "Info!" + vbNewLine+ vbNewLine
   	    
		TS.Write "Date (Today)        :" + vbTab + "" & Date & "" + vbNewLine
		TS.Write "Performed by        :" + vbTab + strYourName & " " & strYourName2 + vbNewLine
		TS.Write "Company             :" + vbTab + strCompany + vbNewLine
		TS.Write "Telephone           :" + vbTab + strPhoneNr + vbNewLine
		TS.Write "E mail              :" + vbTab + strEmail + vbNewLine + vbNewLine

		TS.Write "Comments  examples  :" + vbNewLine
		TS.Write "Comments            :" + vbTab + strC1 + vbNewLine
		TS.Write "Comments            :" + vbTab + strC2 + vbNewLine
		TS.Write "Comments            :" + vbTab + strC3 + vbNewLine
		TS.Write "Comments            :" + vbTab + strC4 + vbNewLine + vbNewLine

		TS.Write vbNewLine + "EXTRA MSI info!" + vbNewLine + vbNewLine
		TS.Write "Last_Saved_By" + vbTab + Last_Saved_By + vbNewLine
		TS.Write "PackageCode" + vbTab + PackageCode + vbNewLine
	    TS.Write "UpgradeCode" + vbTab + UpgradeCode.StringData(1) + vbNewLine
	    TS.Write "ProductCode" + vbTab + ProductCode.StringData(1) + vbNewLine
		
	End If

	TS.Close

	objHOST.Run "notepad.exe "  & """" & Path_Result_File & """", 1, True
	
	FS.DeleteFile (Path_Result_File)

Set WI = Nothing
Set FS = Nothing
Set objHOST = Nothing
Set ProductName = Nothing
Set UpgradeCode = Nothing
Set ProductCode = Nothing
Set ProductVersion = Nothing

' "Code page: 			" & objProduct.Property(1)
' "Title: 				" & objProduct.Property(2)
' "Subject: 			" & objProduct.Property(3)
' "Author: 				" & objProduct.Property(4)
' "Keywords: 			" & objProduct.Property(5)
' "Comment: 			" & objProduct.Property(6)
' "Template: 			" & objProduct.Property(7)
' "Last Author: 		" & objProduct.Property(8)
' "Revision number: 	" & objProduct.Property(9)
' "Edit Time: 			" & objProduct.Property(10)
' "Last Printed: 		" & objProduct.Property(11)
' "Creation Date: 		" & objProduct.Property(12)
' "Last Saved: 			" & objProduct.Property(13)
' "Page Count: 			" & objProduct.Property(14)
' "Word Count: 			" & objProduct.Property(15)
' "Character Count: 	" & objProduct.Property(16)
' "Application Name: 	" & objProduct.Property(18)
' "Security: 			" & objProduct.Property(19)


'*********************************************************
' Purpose: Reads all files size in file table.
'
' Assumptions: Windows Installe automation object
'			   Constant conmsiOpenDatabaseModeReadOnly
'
' Effects : Nothing
'
' Inputs: String containing the path to a MSI-file
'           
' Return Values : All files size in KB
'*********************************************************
Function MsiSourceFileSize(strMSI)
	On Error Resume Next
	Dim objWI,objDB, objView, objRS
	Dim lngSize : lngSize = 0
	Set objWI = CreateObject("WindowsInstaller.Installer")
	Set objDB = objWI.OpenDatabase(strMSI, conmsiOpenDatabaseModeReadOnly)
	Set objView = objDB.OpenView("Select `FileSize` From File")
	objView.Execute
	Set objRS = objView.Fetch
	If Not objRS Is Nothing Then
		Do 
			lngSize = lngSize + CLng(objRS.StringData(1))
			Set objRS = objView.Fetch
		Loop Until objRS Is Nothing
	End If
	MsiSourceFileSize = Clng(lngSize/1024)
End Function
'*********************************************************
' Purpose: Change a long value in KB to appropriate value in MB or GB
'
' Assumptions: Nothing
'
' Effects : Nothing
'
' Inputs: long value to convert
'           
' Return Values : The new value plus the new unit
'*********************************************************
Function ConvertKB(lngKB)
	On Error Resume Next
	'Insert Your function code here
	If lngKB > 10240 Then               'Check if greater than 10 in next prefix which will produce 2 value digits
      lngKB = CLng(lngKB/1024)
      ConvertKB = CStr(lngKB) & "MB"
      If lngKB > 10240 Then               'Check if greater than 10 in next prefix which will produce 2 value digits
         lngKB = CLng(lngKB/1024)
         ConvertKB = CStr(lngKB) & "GB"
      End If
	Else
		ConvertKB = CStr(lngKB) & "KB"
	End If
End Function


'' SIG '' Begin signature block
'' SIG '' MIITKgYJKoZIhvcNAQcCoIITGzCCExcCAQExCzAJBgUr
'' SIG '' DgMCGgUAMGcGCisGAQQBgjcCAQSgWTBXMDIGCisGAQQB
'' SIG '' gjcCAR4wJAIBAQQQTvApFpkntU2P5azhDxfrqwIBAAIB
'' SIG '' AAIBAAIBAAIBADAhMAkGBSsOAwIaBQAEFOvppn4PiYMH
'' SIG '' oSgkxL1SqzMwVKA7oIIRTzCCBSowggMSoAMCAQICEQCu
'' SIG '' ODMOlntE0d/4Jpu0cwWAMA0GCSqGSIb3DQEBBQUAMDgx
'' SIG '' FDASBgNVBAoMC1RlbGlhU29uZXJhMSAwHgYDVQQDDBdU
'' SIG '' ZWxpYVNvbmVyYSBFbWFpbCBDQSB2MzAeFw0wOTAxMjkx
'' SIG '' MjE5NDBaFw0xMDAxMjkxMjE5MzlaMHQxFDASBgNVBAoM
'' SIG '' C1RlbGlhU29uZXJhMRowGAYDVQQDDBFTdGVmYW4gTWFs
'' SIG '' bXN0csO2bTEPMA0GA1UEBRMGc3RlbWFsMS8wLQYJKoZI
'' SIG '' hvcNAQkBFiBTdGVmYW4uTWFsbXN0cm9tQHRlbGlhc29u
'' SIG '' ZXJhLmNvbTCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkC
'' SIG '' gYEArur2oedEC5+uNFUbmSpNNmNlICOhiF5x4eAwxn3+
'' SIG '' KSPm3cDe9z8hL6XjuFJ1f8TDdfXCr9eglbc+hxW/Dq0E
'' SIG '' S0WvI9wJQMenIWj8U+DQhJeQiXRRWMxfSUUoFxGKTHEW
'' SIG '' w7P3s1Ct13aa69/fDt/ehpDULDwMNFF38xXFx9lTMO0C
'' SIG '' AwEAAaOCAXUwggFxMIHFBgNVHR8Egb0wgbowgbeggbSg
'' SIG '' gbGGcmxkYXA6Ly9jcmwtMS50cnVzdC50ZWxpYXNvbmVy
'' SIG '' YS5jb20vY249VGVsaWFTb25lcmElMjBFbWFpbCUyMENB
'' SIG '' JTIwdjMsbz1UZWxpYVNvbmVyYT9jZXJ0aWZpY2F0ZXJl
'' SIG '' dm9jYXRpb25saXN0O2JpbmFyeYY7aHR0cDovL2NybC0y
'' SIG '' LnRydXN0LnRlbGlhc29uZXJhLmNvbS90ZWxpYXNvbmVy
'' SIG '' YWVtYWlsY2F2My5jcmwwVAYIKwYBBQUHAQEESDBGMEQG
'' SIG '' CCsGAQUFBzAChjhodHRwOi8vY2EudHJ1c3QudGVsaWFz
'' SIG '' b25lcmEuY29tL1RlbGlhU29uZXJhRW1haWxDQXYzLmNl
'' SIG '' cjArBgNVHREEJDAigSBTdGVmYW4uTWFsbXN0cm9tQHRl
'' SIG '' bGlhc29uZXJhLmNvbTAUBgNVHSAEDTALMAkGByqFcCME
'' SIG '' AgowDgYDVR0PAQH/BAQDAgWgMA0GCSqGSIb3DQEBBQUA
'' SIG '' A4ICAQAYdqwJNTAFs6dG6cezzUSUvFT2oK3Rpv6N2h72
'' SIG '' 4MXDKP6rrVQ9eJo24r9LD8Wiqvzm6RDk9pcv8acYQlTR
'' SIG '' u7NoBxB3ND3j6ZzcNIwQhg0pXYVJU1bNptyd7w1LpsNd
'' SIG '' 0c/m58tSuZJ52qyttqhKME8Pu8fInBXA+dQArA7qzvPs
'' SIG '' EH9tGZYmNWSLpwC9Jv2uZ2PJdJ2o+ztxuGCw4JppZsF9
'' SIG '' Quyzk4jxzSudggzJOwG0k1w6SkThbmUO+89k6siAbbhC
'' SIG '' Yc5dvCuBdLv3TRI6PafCaFfs7+PPuQ48JqPaPux/y33j
'' SIG '' x0FwFubPPuo5v7iSRAKedwngQiaoiCGAKFmUaFbCQfaf
'' SIG '' ARLWYP08RA1Q33HtKMYZaLwbRSpDHoDMPdi+FVGRoZzi
'' SIG '' RUqp67xipOgsIP8Nzf7yL59Ql35YOaT9+N0cNGkI/n96
'' SIG '' 1QHdfD8rojDnKS5w2Vu81KyZcg5NtEmtbA2MyR9hFrXl
'' SIG '' 51PmISSkgQ5VnC7wFqzMaS3b/bR7xEbs9CQ/1mcs/kSy
'' SIG '' ts+hql47vDUyOyfXjtcXi0Juz9ELi6HoLF+ScqUSQjUq
'' SIG '' ZTg6tWCVPI72wJUSBcC/y2V7Dn4VzSUfsgaDU+t2rKft
'' SIG '' PVMSgQg7ILUVFYRNgPtmHh2XMI2w+H/Bnzghr6EVoefr
'' SIG '' IQi2mD2q8WiMctS+/+bSG543Ar8p7DCCBX0wggRloAMC
'' SIG '' AQICEQDR4D5bSO3Hngk/QN7hYcOLMA0GCSqGSIb3DQEB
'' SIG '' BQUAMDkxCzAJBgNVBAYTAkZJMQ8wDQYDVQQKEwZTb25l
'' SIG '' cmExGTAXBgNVBAMTEFNvbmVyYSBDbGFzczIgQ0EwHhcN
'' SIG '' MDcxMDE4MTI1MjAxWhcNMTkxMDE3MDUwNDExWjA3MRQw
'' SIG '' EgYDVQQKDAtUZWxpYVNvbmVyYTEfMB0GA1UEAwwWVGVs
'' SIG '' aWFTb25lcmEgUm9vdCBDQSB2MTCCAiIwDQYJKoZIhvcN
'' SIG '' AQEBBQADggIPADCCAgoCggIBAMK+6yfwIaPzaSZVfp3F
'' SIG '' VRaRXP3vIb9TgHot0pGMYzHw7CTww6XScnwQbfQ3t+Xm
'' SIG '' fHnqjLWCi65ItqwA3GV17CpNX8GH9SBlK4GoRz6JI5Uw
'' SIG '' FpB/6FcHSOcZrr9FZ7E3GwYq/t75rH2D+1665I+XZ75L
'' SIG '' jo1kB1c4VWk0Nj0TSO9P4tNmHqTPGrdeNjPUtAa9GAH9
'' SIG '' d4RQAEX1jF3oI7x+/jXh7VB7qTCNGdMJjmhnXb88lxhT
'' SIG '' uylixcpecsHHltTbLaC0H2kD7OriUPEMPPCs81Mt8Bz1
'' SIG '' 7Ww5OXOAFshSsCPN4D7c3TxHoLs1iuKYaIu+5b9y7tL6
'' SIG '' pe0S7fyYGKkmdtwoSxAgHNN/Fnct7W+A90m7UwW7XWjH
'' SIG '' 1Mh1Fj+JWov3F0fUTPHSiXk+TT2YqGHeOh7S+F4D4MHJ
'' SIG '' HIzTjU3TlTazN19jY5szFPAtJmtTfImMMsJu7D0hADnJ
'' SIG '' oWjiUIMusDor8zagrC/kb2HCUQk5PotTubtn2txTuXZZ
'' SIG '' Np1D5SDgPTJghSJRt8czu90VL6R4pgd7gUY2BIbdeTXH
'' SIG '' lSw7sKMXNeVzH7RcWe/a6hBle3rQf5+ztCo3O3CLm1u5
'' SIG '' K7fsslESl1MpWtTwEhDcTwK7EpIvYtQ/aUN8Ddb8WHUB
'' SIG '' iJ1YFkveupD/RwGJBmr2X7KQarMCpgKIv7NHfirZ1fpo
'' SIG '' eDVNAgMBAAGjggGAMIIBfDBOBggrBgEFBQcBAQRCMEAw
'' SIG '' PgYIKwYBBQUHMAKGMmh0dHA6Ly9jYS50cnVzdC50ZWxp
'' SIG '' YXNvbmVyYS5jb20vc29uZXJhY2xhc3MyY2EuY2VyMA8G
'' SIG '' A1UdEwEB/wQFMAMBAf8wGQYDVR0gBBIwEDAOBgwrBgEE
'' SIG '' AYIPAgMBAQIwDgYDVR0PAQH/BAQDAgEGMB0GA1UdDgQW
'' SIG '' BBTwj1k4ALP1j5qWDNXr+nuqF+gTEjCBuQYDVR0fBIGx
'' SIG '' MIGuMG+gbaBrhmlsZGFwOi8vY3JsLTEudHJ1c3QudGVs
'' SIG '' aWFzb25lcmEuY29tL2NuPVNvbmVyYSUyMENsYXNzMiUy
'' SIG '' MENBLG89U29uZXJhLGM9Rkk/Y2VydGlmaWNhdGVyZXZv
'' SIG '' Y2F0aW9ubGlzdDtiaW5hcnkwO6A5oDeGNWh0dHA6Ly9j
'' SIG '' cmwtMi50cnVzdC50ZWxpYXNvbmVyYS5jb20vc29uZXJh
'' SIG '' Y2xhc3MyY2EuY3JsMBMGA1UdIwQMMAqACEqgqliE0148
'' SIG '' MA0GCSqGSIb3DQEBBQUAA4IBAQB7L2bVGhb4q6FZUtsG
'' SIG '' VNbneHh+Q5OmrXeyTfAHxWAg90PVlDgAY0+cBk4oPxOL
'' SIG '' 9ZVGnhec070CdiGWHwrqqKER1uDC2H97BTr3jBzGl9mf
'' SIG '' /43MxbY7NJB9LHMONfDeF+V+8bMKziBdedr0HocKuKtB
'' SIG '' bzbvChOkDOaAKZkqCVXEC4+x1AUwqx4++t6D3aSnC3+1
'' SIG '' CWt2+AXfXrIzjE6pAKqZcnJfrI2mqIatmAtaXvW12I8T
'' SIG '' yZR+ERIMcOVGIa4MYfxxSpz0TSSz94DWfLK3DlKiXaxT
'' SIG '' +Tqok3yH1wZhC+6q/11vPLL52cPWk2HciFDaylK2u3wa
'' SIG '' tcxmk8kaxNEt6K5zMIIGnDCCBISgAwIBAgIQSmlkUbIT
'' SIG '' 6utMhnfdHuUjcTANBgkqhkiG9w0BAQUFADA3MRQwEgYD
'' SIG '' VQQKDAtUZWxpYVNvbmVyYTEfMB0GA1UEAwwWVGVsaWFT
'' SIG '' b25lcmEgUm9vdCBDQSB2MTAeFw0wNzEwMTgxMzA2MzRa
'' SIG '' Fw0xOTEwMTcwNTA1MTlaMDgxFDASBgNVBAoMC1RlbGlh
'' SIG '' U29uZXJhMSAwHgYDVQQDDBdUZWxpYVNvbmVyYSBFbWFp
'' SIG '' bCBDQSB2MzCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCC
'' SIG '' AgoCggIBAIWK1O+BjB4G6RfLRMzlW7SyCAMlMcT9Qqsd
'' SIG '' IY3I906FO0hQSTgFgC7rs5m4ZNU9RRzvKkgzhWUQFpLI
'' SIG '' f4WaFPI0XhtSvZ9Gby/dVinCpX0UYjqkDLurL6XHQksC
'' SIG '' o3zisCWHTdSffVijHa62TP0c8CHj8DFBPH23Z/AACjq/
'' SIG '' 68Ru0SGLKXWT4JO4F3F8RN1PcK8tRtBl5D2SGGnXPlYA
'' SIG '' sKZB+KYn4btOUYY1J3iDwqLArDtGSe+jqjaPplkB6cEc
'' SIG '' sJTsKu8jKJcVIcdTqaY8CbA2SoQjDLaV6wmpxx1dlB0u
'' SIG '' ebzmtX9gTVaWovlY/Ndlputx5MisIp3OQmm7vj/Yfp6X
'' SIG '' FRkDkYSABTCqq2muc/BuuMBFJkNo4F/ik724bbaecA9I
'' SIG '' sOdKbOjJhOsZHiWv50OkeGW9kDFEgd96uLca8+x4GLeX
'' SIG '' Smzju6YQ/zV74I2ctfV7/6S6nRBX3BjzXhxeVrSuYtAw
'' SIG '' S3dF7zge2eMhJa/uBTnjzk/+gDq7eqJqaVM9XQAtarhm
'' SIG '' GkP7QtNTtkZmENhIeJhuypbktZgnlq/tgkLpVEeDUrof
'' SIG '' k0MldxBtryQiWPm+/DESRSctxUZlomCO6PevkTsIYkVk
'' SIG '' ABHoNHwci8JtuXQ7QyarBG2weD3TE9cdavrzKzNQ2LUM
'' SIG '' +y/XOuUg42fdSWI6hsJtML6V9Sk2JRZlAgMBAAGjggGh
'' SIG '' MIIBnTBTBggrBgEFBQcBAQRHMEUwQwYIKwYBBQUHMAKG
'' SIG '' N2h0dHA6Ly9jYS50cnVzdC50ZWxpYXNvbmVyYS5jb20v
'' SIG '' dGVsaWFzb25lcmFyb290Y2F2MS5jZXIwEgYDVR0TAQH/
'' SIG '' BAgwBgEB/wIBADAZBgNVHSAEEjAQMA4GDCsGAQQBgg8C
'' SIG '' AwEBAjAOBgNVHQ8BAf8EBAMCAQYwgcYGA1UdHwSBvjCB
'' SIG '' uzB3oHWgc4ZxbGRhcDovL2NybC0xLnRydXN0LnRlbGlh
'' SIG '' c29uZXJhLmNvbS9jbj1UZWxpYVNvbmVyYSUyMFJvb3Ql
'' SIG '' MjBDQSUyMHYxLG89VGVsaWFTb25lcmE/Y2VydGlmaWNh
'' SIG '' dGVyZXZvY2F0aW9ubGlzdDtiaW5hcnkwQKA+oDyGOmh0
'' SIG '' dHA6Ly9jcmwtMi50cnVzdC50ZWxpYXNvbmVyYS5jb20v
'' SIG '' dGVsaWFzb25lcmFyb290Y2F2MS5jcmwwHQYDVR0OBBYE
'' SIG '' FPN0uB0TM9HJrVvOZiiamTKB8CDOMB8GA1UdIwQYMBaA
'' SIG '' FPCPWTgAs/WPmpYM1ev6e6oX6BMSMA0GCSqGSIb3DQEB
'' SIG '' BQUAA4ICAQArs2++A8o8ipWwd0gcPeofedayPQYLSXcj
'' SIG '' U+zL9he/j3ig0ynIShNh0O91SBxNM1gitb1T5/42205/
'' SIG '' 9W2aJX8XFQS/YpqASXslMM8gYqIjqIxgaIG93LiZMMiZ
'' SIG '' xYja8REZIkCEChl29wviNiBXlnGRb3BSjbeHaZCmcCVH
'' SIG '' YkyXFPJQGo4btaEgitBNNeAWFLAYeL7sf49Jwqlih3i5
'' SIG '' sZ0s9wqAYrEzy2wL11a2ImRMqbM7A0I1r+nYM3/8lBWA
'' SIG '' 8Lx+G6FQhZIPrHbOs1kg5bRUw2jEPgBrarghrL5E2xnC
'' SIG '' tzF8HEk+qri2/xeHrWVbIfvka0Q0+fccMRUogJa8p8Kl
'' SIG '' L31QQAu7KlQAcHGrgfwrf+0zS1tabmsdGtGjbgHIBNKi
'' SIG '' NHuo4IRsRd/5AuGCatDVPFr3wn0VuXpb/ZcmqkQIbHaD
'' SIG '' PhOIR6kikNIcB1m8ABctliRrXZagx2s6a+Q28n8VZrLj
'' SIG '' 5XFxixM/39qQkP+sUw6tMwqk9VHTcWmHslkzu+QN3mOv
'' SIG '' tnav8DWy7+KtMJhArHhYBbtbjVtTbTEoM4jjbGD4tNlm
'' SIG '' DnXBsFczNp59fkAg2Tq9mUtoX/mLwBCQjnfGPxZmpINj
'' SIG '' FrUOp/n+H4gwi4fsEbq/FBRR7uITkx3Jw8usmPDm8O2n
'' SIG '' gh6/liyX//4ZXFO3jo1bp2snLfqnjlunwjGCAUcwggFD
'' SIG '' AgEBME0wODEUMBIGA1UECgwLVGVsaWFTb25lcmExIDAe
'' SIG '' BgNVBAMMF1RlbGlhU29uZXJhIEVtYWlsIENBIHYzAhEA
'' SIG '' rjgzDpZ7RNHf+CabtHMFgDAJBgUrDgMCGgUAoFIwEAYK
'' SIG '' KwYBBAGCNwIBDDECMAAwGQYJKoZIhvcNAQkDMQwGCisG
'' SIG '' AQQBgjcCAQQwIwYJKoZIhvcNAQkEMRYEFNEVzsfyI7PU
'' SIG '' OvcDVrOUBY6kR/KSMA0GCSqGSIb3DQEBAQUABIGAHich
'' SIG '' B1Is3VvT5e8OLUOK1O0ZemaabmzSV/2608Vi4Gj/5h8W
'' SIG '' oA2briGE35h/ydZLXRO72Ppsb3BfuwIqMB4njlJ74MkJ
'' SIG '' oBAp31T/nyhYp5TcJivEHRrt+cfrjCGVPsEW1ucjnFdD
'' SIG '' VMmg64E/ud74qiDmeE2iF0tz0sCDVKmoQbs=
'' SIG '' End signature block
