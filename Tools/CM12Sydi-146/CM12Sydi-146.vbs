'Option Explicit

'==========================================================
' LANG : VBScript
' NAME : sydi-SCCM.vbs
' AUTHOR : Garth Jones (Garth@enhansoft.com)
' Based on SYDI-Server wrtten Patrick Ogenstad (patrick.ogenstad@netsafe.se)
' VERSION : 1.44
' DATE : 2015-June-13
' Description : Creates a basic documentation for Systems
' Management Server, which you can use as a starting point.
'
' COMMENTS : You are supposed to change the text appearing inside
' brackets. 
'
' UPDATES : http://www.enhansoft.com/Pages/Downloads.aspx
'
' Running the script:
' You have to have  Word installed on the computer you are running
' the script from. I would recommend running the script with cscript
' instead of wscript.
' For Options: cscript.exe sydi-SCCM.vbs
' Feedback: support@enhansoft.com
'
' LICENSE :
' Copyright (c) 2006 - 2013 Enhansoft 
' All rights reserved.
'
' Redistribution and use in source and binary forms, with or without
' modification, are permitted provided that the following conditions are met:
'
'  * Redistributions of source code must retain the above copyright notice,
'    this list of conditions and the following disclaimer.
'  * Redistributions in binary form must reproduce the above copyright notice,
'    this list of conditions and the following disclaimer in the documentation
'    and/or other materials provided with the distribution.
'  * Neither the name SYDI nor the names of its contributors may be used
'    to endorse or promote products derived from this software without
'    specific prior written permission.
'
' THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
' IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
' ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
' LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
' CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
' SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
' INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
' CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)p
' ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
' POSSIBILITY OF SUCH DAMAGE.
'==========================================================
'==========================================================
'History
'
'1.46 - Update Boundaries section based on Feedback from Ross Rozga
'1.45 - Syncing CM12 and CMCB version numbers.
'1.44 - Add more logging to GetAdvert
'1.43 - Define objSender object; Fixed issue with Protect sites; update Boundaries function.  
'1.42 - Defined Instr attributes
'1.41 - Created sub function for populating the Word doc. 
'1.40 - Added Security Roles, Admin Users, and Security Scopes
'1.39 - Added Applicaiton and Deployment Types
'1.38 - Sprilt CM12 and CM07 versions. 
'1.37 - Move most data collection to subs, this it to make it easy to debug and to help with the migration to CM12
'1.36 - Updated display help and added more debugging in the SMSProv section.
'1.35 - Added more debugging in the smsProv section.
'1.34 - Fixed typo and ??
'1.33 - Fix issue with debug code and fixed up the commenting out of the sender section.
'1.32 - Even more Debugging code
'1.31 - Merged Scripts 
'1.30 - Added debug code to provide section
'1.28 - Class Premissions
'1.27 - Added Program Details
'1.25-1.29 - Reserved these update will be added to v1.31 or later. 
'1.25 - Fix Typo and ..
'1.24 - Even more var declared and fix Boundary issues. 
'1.23 - Set "Option Explicit OFF" 
'1.22 - Don't remember and added bWMILocalGroups to vars list. 
'1.21 - Fixed Boundaries and make this version work for ConfigMgr only now!
'1.20 - interim release.
'1.19 - more var issues. Fix issue with the alt username and password. (Doh!) 
'1.18 - Increased MaxCharacters 500 to fix Microsoft Cursor Engine: Multiple-step operation generated errors. Check each status value. issue.
'1.17 - Made sure that all vars are declared, added ECStr Function, update some of the debug code
'1.16 - Fixed anther issue with username and password. Add more debug mode code
'1.15 - Fixed issue with username and password.
'1.14 - Re-released 
'1.13 - Fixed typos Thanks to Jim Dempsey for finding them 
'1.12 - Add lots of conversion details such as 1/0 to True/False etc.
'1.11 - Added site control file refresh 
'1.10 - Fully Add  schedule token decode and update
'1.09 - Added bit shifting functions
'1.08 - Add Decodetext schedule Token
'1.07 - Add Decodetext Function
'1.06 - Add Boundary, Agent setting (HW, SW, etc.)
'1.05 - Add Help, Added Command line options
'1.04 - Changed Default Font size from 12 to 10
'1.03 - Removed SQL Query for Web report, Added ReportID
'1.02 - Fixed Basic site info
'==========================================================

' Settings
Dim strDocumentAuthor, strComputer, objSWbemLocator

' Who Authored the document
strDocumentAuthor = "Garth Jones"

' Script version
Dim strScriptVersion
strScriptVersion = "1.40"

' Fonts to use in document
Dim strFontBodyText, strFontHeading1, strFontHeading2, strFontHeading3, strFontHeading4, strFontTitle, strFontTOC1, strFontTOC2, strFontTOC3
Dim strFontHeader, strFontFooter
strFontBodyText = "Arial"
strFontHeading1 = "Trebuchet MS"
strFontHeading2 = "Trebuchet MS"
strFontHeading3 = "Trebuchet MS"
strFontHeading4 = "Trebuchet MS"
strFontTitle = "Trebuchet MS"
strFontTOC1 = "Trebuchet MS"
strFontTOC2 = "Trebuchet MS"
strFontTOC3 = "Trebuchet MS"
strFontHeader = "Arial"
strFontFooter = "Arial"
nBaseFontSize = 10

' Username and Password
Dim strUserName, strPassword

' Other
Dim bInvalidArgument, bDisplayHelp, bAlternateCredentials, bCheckVersion

' Word
Dim bShowWord, bWordExtras, bUseDOTFile, bSaveFile, bUseSpecificTable
Dim strDOTFile, strWordTable

' Export Options
Dim strExportFormat, strSaveFile

' XML Options
Dim strStylesheet, strXSLFreeText

Const wbemFlagReturnImmediately = &h10
Const wbemFlagForwardOnly = &h20
Const wbemFlagReturnWhenComplete = &h0

'Site Control file refresh
dim InParams

' Variables for the Win32_ComputerSystem class
Dim strComputerSystem_Name, strComputerSystem_TotalPhysicalMemory, strComputerSystem_Domain, nComputerSystem_DomainRole
Dim strTotalPhysicalMemoryMB, strDomainType, strComputerRole

' Variables for the Win32_OperatingSystems Class
Dim strOperatingSystem_InstallDate, strOperatingSystem_Caption, strOperatingSystem_ServicePack, strOperatingSystem_WindowsDirectory
Dim strOperatingSystem_LanguageCode, arrOperatingSystem_Name

' Variables for the SMS_Site
Dim objSite, p, objIsite

' Variables for the Agent Settings
Dim objSWAgent, objHWAgent, objCAgent, objRCAgent, objSMAgent, objSUAgent, objSDAgent

' Variables for the Site_Boundaries
Dim objBoundary

' Variables for the SMS_Collection
Dim objCollect

' Variables for the SMS_Package
Dim objPackage

' Variables for the SMS_Program, 
Dim objProgram, Name, OS_REAL_NAME, objProgram_OS
Const RUN_ON_SPECIFIED_PLATFORMS = &H08000000

' Variables for the SMS_Application
Dim objApplication

' Variables for the SMS_DeploymentType, 
Dim objDeploymentType

' Variables for the SMS_Advert
Dim objAdvert

' Variables for the SMS_SWMeter
Dim objswmeter

' Variables for the SMS_WebReports
Dim objWebR

' Variables for the SMS_Queries
Dim objQueries

' Variables for the Security Classes
Dim ObjUserClass, objSecObj, objUserInstance , objSecuredCategory
Dim objSecuredCategoryMembership, objUser, objRoles

' Variables for the Sender
Dim objSender

' Variables to handle different versions of Windows
Dim nOperatingSystemLevel

' Objects for WMI and Word
Dim objWMIService, colItems, objItem, oReg, bHasMicrosoftIISv2
Dim oWord, oListTemplate,i
Dim bWMICollection, bWMIQueries, bWMISite, bWMIReports, bWMIPackages, bWMIAdvert, bWMIMeter, bWMISecurity

' Variables for System Roles
Dim bRoleSMS, bRoleMP, bRoleCAP, bRoleSQL, bRoleRP, bRoleDP, objDbrSystemRoles, bRoleDC

' Variables for routines
Dim errGatherWMIInformation, errGatherRegInformation, errWin32_Product
Dim bAllowErrors, bHasSMS, bRegPrintSpoolLocation, bRegWindowsComponents

Dim nTerminalServerMode, bRegPrograms, strLastUserDomain, strLastUser, strComputerSystemProduct_IdentifyingNumber
Dim bWMILocalAccounts, bWMILocalGroups

Dim bRegDomainSuffix, bRegLastUser, bDoRegistryCheck, debugmode

'debugmode = False
'debugmode = True
'SMS WMI Prov
Dim SMSProv 
SMSProv = Null

' Constants
Const adVarChar = 200
Const MaxCharacters = 500

Dim nBaseFontSize

	' WdListNumberStyle
	Const wdListNumberStyleArabic = 0
	Const wdListNumberStyleUppercaseRoman = 1
	Const wdListNumberStyleLowercaseRoman = 2
	Const wdListNumberStyleUppercaseLetter = 3
	Const wdListNumberStyleLowercaseLetter = 4
	Const wdListNumberStyleOrdinal = 5
	Const wdListNumberStyleCardinalText = 6
	Const wdListNumberStyleOrdinalText = 7
	Const wdListNumberStyleArabicLZ = 22
	Const wdListNumberStyleBullet = 23
	Const wdListNumberStyleLegal = 253
	Const wdListNumberStyleLegalLZ = 254
	Const wdListNumberStyleNone = 255
	
	' WdListGalleryType
	Const wdBulletGallery = 1
	Const wdNumberGallery = 2
	Const wdOutlineNumberGallery = 3
	
	' WdBreakType
	Const wdPageBreak = 7
	
	' WdBuiltInProperty
	Const wdPropertyAuthor = 3
	Const wdPropertyComments = 5
	
	' WdBuiltInStyle
	Const wdStyleBodyText = -67
	Const wdStyleFooter = -33
	Const wdStyleHeader = -32
	Const wdStyleHeading1 = -2
	Const wdStyleHeading2 = -3
	Const wdStyleHeading3 = -4
	Const wdStyleHeading4 = -5
	Const wdStyleTitle = -63
	Const wdStyleTOC1 = -20
	Const wdStyleTOC2 = -21
	Const wdStyleTOC3 = -22
	
	' WdFieldType
	'Const wdFieldEmpty = -1
	Const wdFieldNumPages = 26
	Const wdFieldPage = 33
	
	' WdParagraphAlignment
	Const wdAlignParagraphRight = 2
	
	' WdSeekView
	Const wdSeekMainDocument = 0
	Const wdSeekCurrentPageHeader = 9
	Const wdSeekCurrentPageFooter = 10
	
	' Page Viewing
	Const wdPaneNone = 0
	Const wdPrintView = 3


'bShowWord = True

'==========================================================
'==========================================================
' Main Body

If LCase (Right (WScript.FullName, 11)) <> "cscript.exe" Then
    MsgBox "This script should be run from a command line (eg ""cscript.exe sydi-server.vbs"")", vbCritical, "Error"
    WScript.Quit
End If

' Get Options from user
GetOptions()

If (bInvalidArgument) Then
	WScript.Echo "Invalid Arguments" & VbCrLf
	bDisplayHelp = True
End If

If (bDisplayHelp) Then
	DisplayHelp
Else
	If (bCheckVersion) Then
		CheckVersion
	End If
	If (strComputer = "") Then
		strComputer = InputBox("What Computer do you want to document (default=localhost)","Select Target",".")
	End If
	If (strComputer <> "") Then
		' Run the GatherWMIInformation() function and return the status
		' to errGatherInformation, if the function fails then the
		' rest is skipped. The same applies to GatherRegInformation
		' if it is successful we place the information in a
		' new word document
		GetWMIProviderList()
		if (bHasSMS) then
			GetSMSProvider()
		end if

		errGatherWMIInformation = GatherWMIInformation()
		If (errGatherWMIInformation) Then
			If (bDoRegistryCheck) Then
				errGatherRegInformation = GatherRegInformation
			End If
			GetWMIProviderList
'			if (bHasSMS) then
'				GetSMSProvider
'			end if
		End If

'		If (bHasMicrosoftIISv2) Then ' Does the system have the WMI IIS Provider
'			GatherIISInformation
'		End If

		SystemRolesSet()
		
		If (errGatherWMIInformation) Then
			Select Case strExportFormat
				Case "word"
					PopulateWordfile
				Case "xml"
					PopulateXMLFile
			End Select
		End If
	End If
End If

'==========================================================

Function GatherWMIInformation

	If (bAllowErrors) Then
		On Error Resume Next
	End If

	If (bAlternateCredentials) Then
		Set objSWbemLocator = CreateObject("WbemScripting.SWbemLocator")
		Set objWMIService = objSWbemLocator.ConnectServer(strComputer,"root\cimv2",strUserName,strPassword)
	Else
		Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\cimv2")
	End If

	ReportProgress " Connecting to WMI " & Err

	If (Err <> 0) Then
	    ReportProgress Err.Number & " -- " &  Err.Description & " (" & strComputer & ")"
	    Err.Clear
	    GatherWMIInformation = False
	    Exit Function
	End If
	
	GatherOS()
	GatherComputerSystem()

	If (bAlternateCredentials) Then
		if (debugmode) then
			ReportProgress " Debug SMSProv " 
			ReportProgress " SMSProv = " & SMSProv		
		End if
		Set objSWbemLocator = CreateObject("WbemScripting.SWbemLocator")
		Set objWMIService = objSWbemLocator.ConnectServer(strComputer,"root\SMS\" & SMSProv,strUserName,strPassword)
	Else
		if (debugmode) then
			ReportProgress " Debug SMSProv " 
			ReportProgress " SMSProv = " & SMSProv
		End if
		Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\SMS\" & SMSProv)
	End If
	If (Err <> 0) Then
	    ReportProgress Err.Number & " -- " &  Err.Description & " (" & strComputer & ")"
	    Err.Clear
	    GatherWMIInformation = False
	    Exit Function
	End If

	if (bWMISite) Then
		GatherSite ()
		GatherBoundary()
		GatherHardware()
		GatherSoftware()
		GatherClientAgent()
		GatherRemoteControl()
		GatherSoftwareMetering()
		GatherSoftwareUpdateAgent()
		GatherSoftwareDistributionAgent()
		GatherSender()
	End if
	
	if (bWMICollection) Then
		GatherCollection()
	End if

	if (bWMIPackages) Then
		GatherPackage()
		GatherApplication()
	end if

	if (bWMIAdvert) Then
		GatherAdvertisement()
	end if

	if (bWMIMeter) Then
		GatherMeteringRules()
	end if

	if (bWMIReports) Then
		GatherASPReports()
	end If
	
	if (bWMIQueries) then
		GatherQueries()
	end if

	if (bWMISecurity) Then
		GatherSecurityScopes()
		GatherSecuredCategoryMembership()
		GatherUsers()
		GatherRoles()
	end If
	
	GatherWMIInformation = True
	
end function 'GatherWMIInformation


Sub PopulateWordfile()

	If (bAllowErrors) Then
		On Error Resume Next
	End If
	
	ReportProgress VbCrLf & "Start Subroutine: PopulateWordfile()"
	Set oWord = CreateObject("Word.Application")
	If (Err <> 0) Then
	    ReportProgress Err.Number & " -- " &  Err.Description & " (" & strComputer & ")"
	    ReportProgress " Could not open Microsoft Word, verify that it is correctly installed on the computer you are scanning from."
	    Err.Clear
	    Exit Sub
	End If

	'oWord.Activate
	
	If (bUseDOTFile) Then
		oWord.Documents.Add strDOTFile
		If (Err <> 0) Then
		    ReportProgress Err.Number & " -- " &  Err.Description & " (" & strDOTFile & ")"
		    ReportProgress " Unable to open the template file " & strDOTFile
		    ReportProgress " Did you use the correct path?"
		    Err.Clear
		    Exit Sub
		End If
	Else
		oWord.Documents.Add
	End If
	oWord.Application.Visible = bShowWord
	ReportProgress " Opening Empty Document"
	Set oListTemplate = oWord.ListGalleries(wdOutlineNumberGallery).ListTemplates(1)
	oWord.ListGalleries(wdOutlineNumberGallery).ListTemplates(1).listlevels(1).Numberformat = "%1."
	oWord.ListGalleries(wdOutlineNumberGallery).ListTemplates(1).listlevels(1).NumberStyle = wdListNumberStyleArabic
	oWord.ListGalleries(wdOutlineNumberGallery).ListTemplates(1).listlevels(2).Numberformat = "%1.%2."
	oWord.ListGalleries(wdOutlineNumberGallery).ListTemplates(1).listlevels(2).NumberStyle = wdListNumberStyleArabic
	oWord.ListGalleries(wdOutlineNumberGallery).ListTemplates(1).listlevels(3).Numberformat = "%1.%2.%3."
	oWord.ListGalleries(wdOutlineNumberGallery).ListTemplates(1).listlevels(3).NumberStyle = wdListNumberStyleArabic
	oWord.ListGalleries(wdOutlineNumberGallery).ListTemplates(1).listlevels(4).Numberformat = "%1.%2.%3.%4."
	oWord.ListGalleries(wdOutlineNumberGallery).ListTemplates(1).listlevels(4).NumberStyle = wdListNumberStyleArabic

	If Not (bUseDOTFile) Then
		oWord.ActiveDocument.Styles(wdStyleTOC1).Font.Bold = True
		oWord.ActiveDocument.Styles(wdStyleBodyText).Font.Name = strFontBodyText
		oWord.ActiveDocument.Styles(wdStyleBodyText).Font.Size = nBaseFontSize
		oWord.ActiveDocument.Styles(wdStyleHeading1).Font.Name = strFontHeading1
		oWord.ActiveDocument.Styles(wdStyleHeading1).Font.Size = (nBaseFontSize + 4)
		oWord.ActiveDocument.Styles(wdStyleHeading2).Font.Name = strFontHeading2
		oWord.ActiveDocument.Styles(wdStyleHeading2).Font.Size = (nBaseFontSize + 2)
		oWord.ActiveDocument.Styles(wdStyleHeading3).Font.Name = strFontHeading3
		oWord.ActiveDocument.Styles(wdStyleHeading3).Font.Size = (nBaseFontSize + 1)
		oWord.ActiveDocument.Styles(wdStyleHeading4).Font.Name = strFontHeading4
		oWord.ActiveDocument.Styles(wdStyleHeading4).Font.Size = nBaseFontSize
		oWord.ActiveDocument.Styles(wdStyleTitle).Font.Name = strFontTitle
		oWord.ActiveDocument.Styles(wdStyleTitle).Font.Size = (nBaseFontSize + 4)
		oWord.ActiveDocument.Styles(wdStyleTOC1).Font.Name = strFontTOC1
		oWord.ActiveDocument.Styles(wdStyleTOC1).Font.Size = nBaseFontSize
		oWord.ActiveDocument.Styles(wdStyleTOC2).Font.Name = strFontTOC2
		oWord.ActiveDocument.Styles(wdStyleTOC2).Font.Size = nBaseFontSize
		oWord.ActiveDocument.Styles(wdStyleTOC3).Font.Name = strFontTOC3
		oWord.ActiveDocument.Styles(wdStyleTOC3).Font.Size = nBaseFontSize
		oWord.ActiveDocument.Styles(wdStyleHeader).Font.Name = strFontHeader
		oWord.ActiveDocument.Styles(wdStyleHeader).Font.Size = (nBaseFontSize - 1)
		oWord.ActiveDocument.Styles(wdStyleFooter).Font.Name = strFontFooter
		oWord.ActiveDocument.Styles(wdStyleFooter).Font.Size = (nBaseFontSize - 1)
		ReportProgress " Setting Styles"	
	End If

	oWord.Selection.Style = wdStyleTitle
	oWord.Selection.TypeText "Basic Documentation For " & strComputerSystem_Name & VbCrLf & VbCrLf

	If (strDocumentAuthor = "") Then
		strDocumentAuthor = oWord.ActiveDocument.BuiltInDocumentProperties(wdPropertyAuthor).Value
	End If
	oWord.Selection.Style = wdStyleBodyText
	oWord.Selection.TypeText "Document versions:" & vbCrLf & "Version 1.0" & vbTab & Date & vbTab & strDocumentAuthor & vbTab & "First Draft" & vbCrLf & vbCrLf
	
	oWord.Selection.Font.Bold = True
	oWord.Selection.TypeText "SUMMARY" & vbCrLf
	oWord.Selection.Font.Bold = False
	
	oWord.Selection.Style = wdStyleBodyText
	If (bWordExtras) Then 
		oWord.Selection.TypeText "[Introduce the system in a short sentence]. "
	End If
	oWord.Selection.TypeText "The system is running " & strOperatingSystem_Caption & " " & strOperatingSystem_ServicePack & VbCrLf

	If (bWordExtras) Then 
		oWord.Selection.TypeText "System Owner: "
		oWord.Selection.TypeText "[provide name and title]" & VbCrLf
	End If

	If (bRegDomainSuffix) Then
		oWord.Selection.TypeText "FQDN: " &  LCase(strComputerSystem_Name) & "." & strPrimaryDomain & VbCrLf
	End If
	oWord.Selection.TypeText "NetBIOS: " & strComputerSystem_Name & VbCrLf
	oWord.Selection.TypeText "Roles: "

	i = 0
	If Not (objDbrSystemRoles.Bof) Then
		objDbrSystemRoles.MoveFirst
	End If
	Do Until objDbrSystemRoles.EOF
		If (i = 0) Then
			oWord.Selection.TypeText ECStr(objDbrSystemRoles.Fields.Item("Role"))
		Else
			oWord.Selection.TypeText ", " & ECStr(objDbrSystemRoles.Fields.Item("Role"))
		End If
		i = i + 1
		objDbrSystemRoles.MoveNext
	Loop
	If (i = 0) Then
		oWord.Selection.TypeText "[provide the roles of this system]" & vbCrLf
	Else
		oWord.Selection.TypeText vbCrLf
	End If
	If (bWordExtras) Then 
		oWord.Selection.TypeText "Physical location: "
		oWord.Selection.TypeText "[provide info: Floor 3, Street 3, Stockholm]" & vbCrLf
		oWord.Selection.TypeText "Logical location: " 
		oWord.Selection.TypeText "[provide info: Server VLAN 2]" & VbCrLf
	End If

	oWord.Selection.TypeText "Identifying Number: " & strComputerSystemProduct_IdentifyingNumber & VbCrLf 
	If (bWordExtras) Then 
		oWord.Selection.TypeText "Shipping date: "  
		oWord.Selection.TypeText "[provide shipping date]" & VbCrLf
		oWord.Selection.TypeText "Support contract: "  
		oWord.Selection.TypeText "[provide hardware service level purchased for this server]" & VbCrLf
		oWord.Selection.TypeText "Maintenance and changes to this documentation are recorded in "  
		oWord.Selection.TypeText "[reference to log file/system]." & VbCrLf
		oWord.Selection.TypeText "Continuity and disaster recovery are covered in "  
		oWord.Selection.TypeText "[reference to continuity plan]" & VbCrLf
	End If		
	oWord.Selection.InsertBreak wdPageBreak
	
	ReportProgress " Writing Summary"
	oWord.Selection.Font.Bold = True
	oWord.Selection.TypeText vbCrLf & "TABLE OF CONTENTS" & vbCrLf
	oWord.Selection.Font.Bold = False

	oWord.ActiveDocument.TablesOfContents.Add oWord.Selection.Range, False, 2, 3, , , , ,oWord.ActiveDocument.Styles(wdStyleHeading1)& ";1", True
	
	
	ReportProgress " Inserting Table Of Contents"
	oWord.Selection.TypeText vbCrLf
	oWord.Selection.InsertBreak wdPageBreak

	'--------------------------------------------------------------------------------
	'Chapter 1 - System Information
	'--------------------------------------------------------------------------------
	If (bWordExtras) Then 
		ReportProgress " Writing System Information"
		WriteHeader 1,"System Information"
		oWord.Selection.Style = wdStyleBodyText
		oWord.Selection.TypeText "[Enter information about your server, what the system means to your organization, the purpose of this document etc.]" & vbCrLf
	End If
	oWord.Selection.TypeText VbCrLf

	if (bWMISite) then
		'--------------------------------------------------------------------------------
		'Chapter 2 - Site Info Platform
		'--------------------------------------------------------------------------------
		ReportProgress " Writing Basic Site Info"
		oWord.Selection.InsertBreak wdPageBreak
		'oWord.Selection.PageSetup.Orientation wdOrientLandscape
		WriteHeader 1,"Site Information"
		WriteHeader 2,"Basic Site info"

		oWord.Selection.Style = wdStyleBodyText
	
		If Not (objsite.Bof) Then
			objsite.Movefirst
		End If			


		Do Until objSite.EOF
			WriteHeader 3,cstr(objSite("SiteCode"))
			oWord.Selection.Style = wdStyleBodyText
			oWord.Selection.Font.Bold = True
			oWord.Selection.TypeText "Site Code: "
			oWord.Selection.Font.Bold = FALSE
			oWord.Selection.TypeText ECStr(objSite("SiteCode")) & vbCrLf
			oWord.Selection.Font.Bold = True
			oWord.Selection.TypeText "Site Name: "
			oWord.Selection.Font.Bold = FALSE
			oWord.Selection.TypeText ECStr(objSite("SiteName")) & vbCrLf
			oWord.Selection.Font.Bold = True
			oWord.Selection.TypeText "Build Number: "
			oWord.Selection.Font.Bold = FALSE
			oWord.Selection.TypeText ECStr(objSite("BuildNumber")) & vbCrLf
			oWord.Selection.Font.Bold = True
			oWord.Selection.TypeText "Site Type: "
			oWord.Selection.Font.Bold = FALSE
			if objSite("Type") = 2 then 
				oWord.Selection.TypeText "Primary Site" & vbCrLf
			Else
				oWord.Selection.TypeText "Secondary Site" & vbCrLf
			End IF
			oWord.Selection.Font.Bold = True
			oWord.Selection.TypeText "Version: "
			oWord.Selection.Font.Bold = FALSE
			oWord.Selection.TypeText ECStr(objSite("Version")) & vbCrLf
			oWord.Selection.Font.Bold = True
			oWord.Selection.TypeText "Site Server: "
			oWord.Selection.Font.Bold = FALSE
			oWord.Selection.TypeText ECStr(objSite("ServerName")) & vbCrLf
			oWord.Selection.Font.Bold = True
			oWord.Selection.TypeText "Install Directory: "
			oWord.Selection.Font.Bold = FALSE
			oWord.Selection.TypeText ECStr(objSite("InstallDir")) & vbCrLf
			oWord.Selection.Font.Bold = True
			oWord.Selection.TypeText "Parent Site: "
			oWord.Selection.Font.Bold = FALSE
			oWord.Selection.TypeText ECStr(objSite("ReportingSiteCode")) & vbCrLf
			oWord.Selection.Font.Bold = True
'			oWord.Selection.TypeText "Assigned: "
'			oWord.Selection.Font.Bold = FALSE
'			oWord.Selection.TypeText ECStr(objSite("AssignDetail")) 
'			oWord.Selection.TypeText vbCrLf
'			oWord.Selection.Font.Bold = True
'			oWord.Selection.TypeText "Assign Type: "
'			oWord.Selection.Font.Bold = FALSE
'			oWord.Selection.TypeText ECStr(objSite("AssignType")) 
'			oWord.Selection.TypeText vbCrLf
			objSite.MoveNext
		Loop


		'--------------------------------------------------------------------------------
		'Chapter 2.2 - Agent Info 
		'--------------------------------------------------------------------------------

		oWord.Selection.TypeText VbCrLf
		WriteHeader 2,"Agents"

		'--------------------------------------------------------------------------------
		'Chapter 2.2.1 - Client Agent Info 
		'--------------------------------------------------------------------------------
		WriteHeader 3,"Client Agent Setting"
		ReportProgress "  Client Agent Settings"
			objCAgent.Movefirst
			oWord.Selection.Style = wdStyleBodyText
			oWord.Selection.TypeText "Client Agent Setting: "
			if (objCAgent("Flags")) = 1 then 
				oWord.Selection.TypeText "Enable"
			Else
				oWord.Selection.TypeText "Disable"
			End if	
			oWord.Selection.TypeText VbCrLf
			Do Until objCAgent.EOF
				Select case (objCAgent("PropertyName"))
					Case "DisplayTrayNotifications"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Display Tray Notifications is set to " & TorF(objCAgent("Value0"))
						oWord.Selection.TypeText vbCrLf
					Case "BrandingTitle"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = True
						oWord.Selection.TypeText "Branding Title: " 
						oWord.Selection.Font.Bold = False
						oWord.Selection.TypeText ECStr(objCAgent("Value1"))
						oWord.Selection.TypeText vbCrLf
					Case "SUMBrandingSubTitle"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = True
						oWord.Selection.TypeText "Software Update Branding SubTitle: " 
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText ECStr(objCAgent("Value1"))
						oWord.Selection.TypeText vbCrLf
					Case "SWDBrandingSubTitle"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = True
						oWord.Selection.TypeText "Software Distribution Branding SubTitle: "
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText ECStr(objCAgent("Value1"))
						oWord.Selection.TypeText vbCrLf
					Case "OSDBrandingSubTitle"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = True
						oWord.Selection.TypeText "OS Branding SubTitle: "
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText ECStr(objCAgent("Value1"))
						oWord.Selection.TypeText vbCrLf
					Case "Report Timeout"
						'Nedd to 
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Report Timeout is " & objCAgent("Value0") & " minutes"
						oWord.Selection.TypeText vbCrLf
					Case "ReminderInterval"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Reminder Interval is " & objCAgent("Value0") & " minutes"
						oWord.Selection.TypeText vbCrLf
					Case "DayReminderInterval"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Day Reminder Interval is " & objCAgent("Value0") & " seconds"
						oWord.Selection.TypeText vbCrLf
					Case "HourReminderInterval"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Hour Reminder Interval is " & objCAgent("Value0") & " seconds"
						oWord.Selection.TypeText vbCrLf
					Case "SystemRestartTurnaroundTime"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "System Restart Turn around Time is " & objCAgent("Value0") & " seconds"
						oWord.Selection.TypeText vbCrLf
					case Else
				end Select
				objCAgent.movenext
			Loop

		'--------------------------------------------------------------------------------
		'Chapter 2.2.2 - Hardware Agent Info 
		'--------------------------------------------------------------------------------
		WriteHeader 3,"Hardware Inventory"
		ReportProgress "  Hardware Inventory"
			'objHWAgent.Movefirst
			'oWord.Selection.Style = wdStyleBodyText
			'oWord.Selection.TypeText "Hardware Inventory Agent: "
			'if (objHWAgent("Flags")) = 1 then 
			'	oWord.Selection.TypeText "Enable"
			'Else
			'	oWord.Selection.TypeText "Disable"
			'End if	
			oWord.Selection.TypeText VbCrLf
			Do Until objHWAgent.EOF
				Select case (objHWAgent("PropertyName"))
					Case "MIF Collection"
						WriteHeader 4,"MIF Files"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "NOIDMIF Collection is " 
						If objHWAgent("Value0") = 4 then 
							oWord.Selection.TypeText "Enable"
						ElseIf objHWAgent("Value0") = 12 then 
							oWord.Selection.TypeText "Enable"
						Else
							oWord.Selection.TypeText "Disable"
						end if
						oWord.Selection.TypeText vbCrLf
						oWord.Selection.TypeText "IDMIF Collection is " 
						If objHWAgent("Value0") = 8 then 
							oWord.Selection.TypeText "Enable"
						ElseIf objHWAgent("Value0") = 12 then 
							oWord.Selection.TypeText "Enable"
						Else
							oWord.Selection.TypeText "Disable"
						end if
						oWord.Selection.TypeText vbCrLf
					Case "Maximum 3rd Party MIF Size"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Maximum 3rd Party MIF Size is " & objHWAgent("Value0") & "KB"
						oWord.Selection.TypeText vbCrLf
					Case "Inventory Schedule"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Inventory Schedule starting date is " & strtodate(objHWAgent("Value2")) & " "
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText Schedule(right(objHWAgent("Value2"),8))
						oWord.Selection.TypeText vbCrLf
						oWord.Selection.TypeText "Inventory schedule is " & Scheduletype(objHWAgent("Value2")) & " schedule"
						oWord.Selection.TypeText vbCrLf

					Case "MIF Collection"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "MIF Collection is " 
						If objHWAgent("Value0") = 1 then 
							oWord.Selection.TypeText "Enable"
						Else 
							oWord.Selection.TypeText "Disable"
						end if

						oWord.Selection.TypeText vbCrLf
					case Else
				End Select
				objHWAgent.movenext
			Loop

		'--------------------------------------------------------------------------------
		'Chapter 2.2.3 - Software Agent Info 
		'--------------------------------------------------------------------------------
		WriteHeader 3,"Software Inventory"
		ReportProgress "  Software Inventory"
			objSWAgent.Movefirst
			oWord.Selection.Style = wdStyleBodyText
			oWord.Selection.TypeText "Software Inventory Agent: "
			if (objSWAgent("Flags")) = 1 then 
				oWord.Selection.TypeText "Enable"
			Else
				oWord.Selection.TypeText "Disable"
			End if	
			oWord.Selection.TypeText VbCrLf
			Do Until objSWAgent.EOF
				Select case (objSWAgent("PropertyName"))
					Case "Report Options"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Report Options is set to " & objSWAgent("Value0")
						oWord.Selection.TypeText vbCrLf
					Case "Scan Interval"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Scan Interval is " & objSWAgent("Value0")
						oWord.Selection.TypeText vbCrLf
					Case "Inventory Schedule"
'						oWord.Selection.Style = wdStyleBodyText
'						oWord.Selection.Font.Bold = FALSE
'						oWord.Selection.TypeText "Inventory Schedule is " & objHWAgent("Value2") 
'						oWord.Selection.TypeText vbCrLf
'						oWord.Selection.TypeText "Inventory Schedule is " & Scheduletype(objHWAgent("Value2")) 
'						oWord.Selection.TypeText vbCrLf

						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Inventory Schedule starting date is " & strtodate(objSWAgent("Value2")) & " "
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText Schedule(right(objSWAgent("Value2"),8))
						oWord.Selection.TypeText vbCrLf
						oWord.Selection.TypeText "Inventory schedule is " & Scheduletype(objSWAgent("Value2")) & " schedule"
						oWord.Selection.TypeText vbCrLf
					Case "Query Timeout"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Query Timeout is " & objSWAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "Report Timeout"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Report Timeout is " & objSWAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					case Else
				end Select
				objSWAgent.movenext
			Loop

		'--------------------------------------------------------------------------------
		'Chapter 2.2.4 - Software Metering Agent Info 
		'--------------------------------------------------------------------------------
		WriteHeader 3,"Software Metering Agent Setting"
		ReportProgress "  Software Metering Agent Settings"
			objSMAgent.Movefirst
			oWord.Selection.Style = wdStyleBodyText
			oWord.Selection.TypeText "Client Agent Setting: " & EorD(objSMAgent("Flags")) 
			oWord.Selection.TypeText VbCrLf
			Do Until objSMAgent.EOF
				Select case (objSMAgent("PropertyName"))
					Case "Application Download Schedule"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Application Download schedule starting date is " & strtodate(objSMAgent("Value2")) & " "
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText Schedule(right(objSMAgent("Value2"),8))
						oWord.Selection.TypeText vbCrLf
						oWord.Selection.TypeText "Application Download Schedule is " & Scheduletype(objSMAgent("Value2")) & " schedule"
						oWord.Selection.TypeText vbCrLf
					Case "Data Collection Schedule"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Data Collection schedule starting date is " & strtodate(objSMAgent("Value2")) & " "
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText Schedule(right(objSMAgent("Value2"),8))
						oWord.Selection.TypeText vbCrLf
						oWord.Selection.TypeText "Data Collection Schedule is " & Scheduletype(objSMAgent("Value2")) & " schedule"
						oWord.Selection.TypeText vbCrLf
					Case "Maintenance Schedule"
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Maintenance schedule starting date is " & strtodate(objSMAgent("Value2")) & " "
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.TypeText vbCrLf
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText Schedule(right(objSMAgent("Value2"),8))
						oWord.Selection.TypeText vbCrLf
						oWord.Selection.TypeText "Maintenance Schedule is " & Scheduletype(objSMAgent("Value2")) & " schedule"
						oWord.Selection.TypeText vbCrLf
					Case "Historical Meter Data Upload File Size "
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Historical Meter Data Upload File Size is " & objSMAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "Application Download Retries "
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Application Download Retries is " & objSMAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "Application Download Retry Interval"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Application Download Retry Interval is " & objSMAgent("Value0") & " seconds"
						oWord.Selection.TypeText vbCrLf
					Case "Maximum Usage Instances Per Report"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Maximum Usage Instances Per Report is " & objSMAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "Report Timeout"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Report Timeout is " & objSMAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "Auto Create Disabled Rule"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Auto Create Disabled Rule is " & TorF(objSMAgent("Value0")) 
						oWord.Selection.TypeText vbCrLf
					Case "Auto Create Percentage"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Auto Create Percentage is " & objSMAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "Auto Create Threshold"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Auto Create Threshold is " & objSMAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "MRU Refresh In Minutes"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "MRU Refresh In Minutes is " & objSMAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "MRU Age Limit In Days"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "MRU Age Limit In Days is " & objSMAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					case Else
				end Select
				objSMAgent.movenext
			Loop

		'--------------------------------------------------------------------------------
		'Chapter 2.2.5 - Client Agent Info 
		'--------------------------------------------------------------------------------
		WriteHeader 3,"Software Update Agent Setting"
		ReportProgress "  Software Update Agent Settings"
			objSUAgent.Movefirst
			oWord.Selection.Style = wdStyleBodyText
			oWord.Selection.TypeText "Software Update Agent Setting: " & EorD(objSUAgent("Flags"))
			oWord.Selection.TypeText VbCrLf
			Do Until objSUAgent.EOF
				Select case (objSUAgent("PropertyName"))
					Case "DisplayTrayNotifications"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Display Tray Notifications is set to " & objSUAgent("Value0")
						oWord.Selection.TypeText vbCrLf
					Case "BrandingTitle"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = True
						oWord.Selection.TypeText "Branding Title: " 
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText ECStr(objSUAgent("Value1"))
						oWord.Selection.TypeText vbCrLf
					Case "SUMBrandingSubTitle"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = True
						oWord.Selection.TypeText "Software Update Branding SubTitle: "
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText objSUAgent("Value1")
						oWord.Selection.TypeText vbCrLf
					Case "SWDBrandingSubTitle"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = True
						oWord.Selection.TypeText "Software Distribution Branding SubTitle: "
 						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText  objSUAgent("Value1") 
						oWord.Selection.TypeText vbCrLf
					Case "OSDBrandingSubTitle"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = True
						oWord.Selection.TypeText "OS Branding SubTitle: " 
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText objSUAgent("Value1") 
						oWord.Selection.TypeText vbCrLf
					Case "Report Timeout"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Report Timeout is " & objSUAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "ReminderInterval"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Reminder Interval is " & objSUAgent("Value0") & " minutes"
						oWord.Selection.TypeText vbCrLf
					Case "DayReminderInterval"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Day Reminder Interval is " & objSUAgent("Value0") & " seconds"
						oWord.Selection.TypeText vbCrLf
					Case "HourReminderInterval"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Hour Reminder Interval is " & objSUAgent("Value0") & " seconds"
						oWord.Selection.TypeText vbCrLf
					Case "SystemRestartTurnaroundTime"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "System Restart Turn around Time is " & objSUAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					case Else
				end Select
				objSUAgent.movenext
			Loop
			
		'--------------------------------------------------------------------------------
		'Chapter 2.2.6 - Remote Control Agent Settings
		'--------------------------------------------------------------------------------

		WriteHeader 3,"Remote Control Agent Settings"
		ReportProgress "  Remote Control Agent Settings"
			objRCAgent.Movefirst
			oWord.Selection.Style = wdStyleBodyText
			oWord.Selection.TypeText "Remote Control Agent Setting: " & EorD(objRCAgent("Flags"))
			oWord.Selection.TypeText VbCrLf
			Do Until objRCAgent.EOF
				Select case (objRCAgent("PropertyName"))
					Case "Allow Client Change"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Allow Client Change is set to " & TorF(objRCAgent("Value0"))
						oWord.Selection.TypeText vbCrLf
					Case "Control Level"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Control level is " & objRCAgent("Value0")
						oWord.Selection.TypeText vbCrLf
					Case "Permission Required"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Permission Required is set to " & TorF(objRCAgent("Value0"))
						oWord.Selection.TypeText vbCrLf
					Case "Visible Signal"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Visible Signal is " & EorD(objRCAgent("Value0"))
						oWord.Selection.TypeText vbCrLf
					Case "Always Visible"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Always Visible is " & TorF(objRCAgent("Value0")) 
						oWord.Selection.TypeText vbCrLf
					Case "Access Level"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Access Level is " & objRCAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "Allow Takeover"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Allow Takeover is " & TorF(objRCAgent("Value0")) 
						oWord.Selection.TypeText vbCrLf
					Case "Allow Remote Execute"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Allow Remote Execute is " & EorD(objRCAgent("Value0"))
						oWord.Selection.TypeText vbCrLf
					Case "Allow File Transfer"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Allow File Transfer is " & EorD(objRCAgent("Value0")) 
						oWord.Selection.TypeText vbCrLf
					Case "Allow Reboot"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Allow Reboot is " & EorD(objRCAgent("Value0")) 
						oWord.Selection.TypeText vbCrLf
					Case "Allow Chat"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Allow Chat is " & EorD(objRCAgent("Value0")) 
						oWord.Selection.TypeText vbCrLf
					Case "Allow View Configuration"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Allow View Configuration is " & EorD(objRCAgent("Value0")) 
						oWord.Selection.TypeText vbCrLf
					Case "Last Changed At"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Last Changed At is " & objRCAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "CompressionType"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Compression Type is " & objRCAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "Use IDIS"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Use IDIS is " & EorD(objRCAgent("Value0")) 
						oWord.Selection.TypeText vbCrLf
					Case "Audible Signal"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Audible Signal is " & EorD(objRCAgent("Value0"))
						oWord.Selection.TypeText vbCrLf
					Case "Default Protocol"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Default Protocol is " & objRCAgent("Value2") 
						oWord.Selection.TypeText vbCrLf
					Case "LanaNum"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "LanaNum is " & objRCAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "Disable Tools on XP"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Disable Tools on XP is " & EorD(objRCAgent("Value0")) 
						oWord.Selection.TypeText vbCrLf
					Case "Manage RA"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Manage RA is " & EorD(objRCAgent("Value0")) 
						oWord.Selection.TypeText vbCrLf
					Case "Enable RA"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Enable RA is " & EorD(objRCAgent("Value0"))
						oWord.Selection.TypeText vbCrLf
					Case "Allow RA Unsolicited View"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Allow RA Unsolicited View is " & TorF(objRCAgent("Value0"))
						oWord.Selection.TypeText vbCrLf
					Case "Allow RA Unsolicited Control"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Allow RA Unsolicited Control is " & TorF(objRCAgent("Value0"))
						oWord.Selection.TypeText vbCrLf
					Case "Manage TS"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Manage TS is " & EorD(objRCAgent("Value0"))
						oWord.Selection.TypeText vbCrLf
					Case "Enable TS"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Enable TS is " & EorD(objRCAgent("Value0"))
						oWord.Selection.TypeText vbCrLf
					Case "TS User Authentication"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "TS User Authentication is " & EorD(objRCAgent("Value0"))
						oWord.Selection.TypeText vbCrLf
					Case "Enforce RA and TS Settings"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Enforce RA and TS Settings is " & EorD(objRCAgent("Value0"))
						oWord.Selection.TypeText vbCrLf
					case Else
				end Select
				objRCAgent.movenext
			Loop


		'--------------------------------------------------------------------------------
		'Chapter 2.2.7 - Software Distribution Agent Settings
		'--------------------------------------------------------------------------------

		WriteHeader 3,"Software Distribution Agent Settings"
		ReportProgress "  Software Distribution Agent Settings"
			objSDAgent.Movefirst
			oWord.Selection.Style = wdStyleBodyText
			oWord.Selection.TypeText "Software Distribution Agent Setting: " & EorD(objSDAgent("Flags"))
			oWord.Selection.TypeText VbCrLf
			Do Until objSDAgent.EOF
				Select case (objSDAgent("PropertyName"))
					Case "Peer DP Status Reporting Interval"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Peer DP Status Reporting Interval is set to " & objSDAgent("Value0") & " minutes"
						oWord.Selection.TypeText vbCrLf
					Case "Peer DP Pending Package Check Interval"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Peer DP Pending Package Check Interval is " & objSDAgent("Value0") & " minutes"
						oWord.Selection.TypeText vbCrLf
					Case "Audible Countdown Signal"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Audible Countdown Signal is set to " & EorD(objSDAgent("Value0"))
						oWord.Selection.TypeText vbCrLf
					Case "Audible Signal on Available"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Audible Signal on Available is " & EorD(objSDAgent("Value0")) 
						oWord.Selection.TypeText vbCrLf
					Case "Countdown Minutes"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Countdown Minutes is " & objSDAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "Countdown Signal"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Countdown Signal is " & EorD(objSDAgent("Value0")) 
						oWord.Selection.TypeText vbCrLf
					Case "Refresh Minutes"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Refresh Minutes is (minutes) " & objSDAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "Policy Refresh Interval"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Policy Refresh Interval is (minutes) " & objSDAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "Show Icon"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Show Icon is " & Eord(objSDAgent("Value0")) 
						oWord.Selection.TypeText vbCrLf
					Case "Use Settings"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Use Settings is " & EorD(objSDAgent("Value0")) 
						oWord.Selection.TypeText vbCrLf
					Case "Visible Signal on Available"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Visible Signal on Available is " & EorD(objSDAgent("Value0")) 
						oWord.Selection.TypeText vbCrLf
					Case "Reboot Countdown"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Reboot Countdown is " & objSDAgent("Value0") & " minutes"
						oWord.Selection.TypeText vbCrLf
					Case "MS_SMS_ProgramCountdownBegin"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "MS_SMS_ProgramCountdownBegin is " & EorD(objSDAgent("Value0")) & " and " & objSDAgent("Value2") 
						oWord.Selection.TypeText vbCrLf
					Case "MS_SMS_ProgramCountdownComplete"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "MS_SMS_ProgramCountdownComplete is " & EorD(objSDAgent("Value0")) & " and " & objSDAgent("Value2") 
						oWord.Selection.TypeText vbCrLf
					Case "MS_SMS_ProgramCountdownProgress"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "MS_SMS_ProgramCountdownProgressis " & EorD(objSDAgent("Value0")) & " and " & objSDAgent("Value2") 
						oWord.Selection.TypeText vbCrLf
					Case "MS_SMS_NewProgramsAvailable"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "MS_SMS_NewProgramsAvailable is " & EorD(objSDAgent("Value0")) & " and " & objSDAgent("Value2") 
						oWord.Selection.TypeText vbCrLf
					Case "Local Cache"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Local Cache is " & objSDAgent("Value0") & " and " & objSDAgent("Value2") 
						oWord.Selection.TypeText vbCrLf
					Case "Slow Network Threshold Speed"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Slow Network Threshold Speed is " & objSDAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "Reboot Logoff Notification"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Reboot Logoff Notification is " & EorD(objSDAgent("Value0"))
						oWord.Selection.TypeText vbCrLf
					Case "Reboot Logoff Notification Final Window"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Reboot Logoff Notification Final Window is " & objSDAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "Whats New Duration"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Whats New Duration is " & objSDAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "Success Return Codes"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Success Return Codes is " & objSDAgent("Value2") 
						oWord.Selection.TypeText vbCrLf
					Case "Reboot Return Codes"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Reboot Return Codes is " & objSDAgent("Value2") 
						oWord.Selection.TypeText vbCrLf
					Case "Logoff Return Codes"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Logoff Return Codes is " & objSDAgent("Value2") 
						oWord.Selection.TypeText vbCrLf
					Case "Network Access User Name"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Network Access User Name is " & objSDAgent("Value2") 
						oWord.Selection.TypeText vbCrLf
					Case "Execution Failure Retry Count"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Execution Failure Retry Count is " & objSDAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "Execution Failure Retry Interval"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Execution Failure Retry Interval is " & objSDAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "Execution Failure Retry Error Codes"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Execution Failure Retry Error Codes is " & objSDAgent("Value2") 
						oWord.Selection.TypeText vbCrLf
					Case "Cache Failure Retry Count"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Cache Failure Retry Count is " & objSDAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "Cache Failure Retry Interval"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Cache Failure Retry Interval is " & objSDAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "Cache Tombstone Content Min Duration"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Cache Tombstone Content Min Duration is " & objSDAgent("Value0") & " seconds"
						oWord.Selection.TypeText vbCrLf
					Case "Cache Content Timeout"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Cache Content Timeout is " & objSDAgent("Value0") & " seconds" 
						oWord.Selection.TypeText vbCrLf
					Case "Content Location Timeout Interval"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Content Location Timeout Interval is " & objSDAgent("Value0") & " seconds"
						oWord.Selection.TypeText vbCrLf
					Case "Content Location Timeout Retry Count"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Content Location Timeout Retry Count is " & objSDAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "UI Content Location Timeout Interval"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "UI Content Location Timeout Interval is " & objSDAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "Default Max Duration"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Default Max Duration is " & objSDAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "User Preemption Timeout"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "User Preemption Timeout is " & objSDAgent("Value0") & " seconds"
						oWord.Selection.TypeText vbCrLf
					Case "User Preemption Countdown"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "User Preemption Countdown is " & objSDAgent("Value0") & " seconds" 
						oWord.Selection.TypeText vbCrLf
					Case "New Program Notification UI"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "New Program Notification UI is " & objSDAgent("Value0") & " or " & objSDAgent("Value2") 
						oWord.Selection.TypeText vbCrLf
					Case "Download Retry Interval"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Download Retry Interval is " & objSDAgent("Value0") & " seconds"
						oWord.Selection.TypeText vbCrLf
					Case "Download Modification Interval"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Download Modification Interval is " & objSDAgent("Value0") & " seconds"
						oWord.Selection.TypeText vbCrLf
					Case "Enable Bits Max Bandwidth"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Enable Bits Max Bandwidth is " & TorF(objSDAgent("Value0")) 
						oWord.Selection.TypeText vbCrLf
					Case "Max Bandwidth Valid From"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Max Bandwidth Valid From is " & objSDAgent("Value0") & " (24hour clock)"
						oWord.Selection.TypeText vbCrLf
					Case "Max Bandwidth Valid To"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Max Bandwidth Valid To is " & objSDAgent("Value0") & " (24hour clock)"
						oWord.Selection.TypeText vbCrLf
					Case "Max Transfer Rate On Schedule"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Max Transfer Rate On Schedule is " & objSDAgent("Value0") & "%" 
						oWord.Selection.TypeText vbCrLf
					Case "Apply To All Clients"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Apply To All Clients is " & TorF(objSDAgent("Value0")) 
						oWord.Selection.TypeText vbCrLf
					Case "Send NAA To All Clients"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Send NAA To All Clients is " & objSDAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					Case "Request User Policy"
						oWord.Selection.Style = wdStyleBodyText
						oWord.Selection.Font.Bold = FALSE
						oWord.Selection.TypeText "Request User Policy is " & objSDAgent("Value0") 
						oWord.Selection.TypeText vbCrLf
					case Else
				end Select
				objSDAgent.movenext
			Loop

		'--------------------------------------------------------------------------------
		'Chapter 2.3 - Boundary Info 
		'--------------------------------------------------------------------------------
		ReportProgress " Writing Boundary Info"
		oWord.Selection.InsertBreak wdPageBreak
		
		oWord.Selection.TypeText VbCrLf
		WriteHeader 2,"Boundary"
		objBoundary.Movefirst

		oWord.Selection.Style = wdStyleBodyText
	
		oWord.ActiveDocument.Tables.Add oWord.Selection.Range, objBoundary.Recordcount + 1, 5
'		oWord.Selection.Font.Bold = True
'		oWord.Selection.TypeText "BoundaryID" 
'		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "DisplayName" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		'oWord.Selection.TypeText "Sitecode" 
		'oWord.Selection.MoveRight
		'oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Value" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "BoundaryType" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "BoundaryFlags" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
'		oWord.Selection.TypeText "ActionInProgress" 
'		oWord.Selection.MoveRight
'		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "SiteSystems" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = False
		if (debugmode) then
			ReportProgress " Upper Bound " & objBoundary.Recordcount + 1
		End If
		
		objBoundary.Movefirst
		Do Until objBoundary.EOF
			if (debugmode) then
				ReportProgress "BoundaryID " & ECStr(objBoundary("BoundaryID"))
				ReportProgress "DisplayName " & ECStr(objBoundary("DisplayName"))
				'ReportProgress "Sitecode " & ECStr(objBoundary("Sitecode"))
				ReportProgress "Value " & ECStr(objBoundary("Value"))
				ReportProgress "BoundaryType " & ECStr(objBoundary("BoundaryType"))
				ReportProgress "BoundaryFlags " & ECStr(objBoundary("BoundaryFlags"))
				'ReportProgress "ActionInProgress " & ECStr(objBoundary("ActionInProgress"))
				ReportProgress "SiteSystems " & ECStr(objBoundary("SiteSystems"))
			End If
'			oWord.Selection.TypeText ECStr(objBoundary("BoundaryID")) : oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objBoundary("DisplayName")) : oWord.Selection.MoveRight
'			oWord.Selection.TypeText ECStr(objBoundary("Sitecode")) : oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objBoundary("Value")) : oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objBoundary("BoundaryType")) : oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objBoundary("BoundaryFlags")) : oWord.Selection.MoveRight
'			oWord.Selection.TypeText ECStr(objBoundary("ActionInProgress")) : oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objBoundary("SiteSystems")) : oWord.Selection.MoveRight
			objBoundary.MoveNext	
		loop
		oWord.Selection.Style = wdStyleBodyText
		oWord.Selection.TypeText VbCrLf
'		debugmode = False
	End if

	If(bWMICollection) then
		'--------------------------------------------------------------------------------
		'Chapter 3 - Collection Info
		'--------------------------------------------------------------------------------
		ReportProgress " Writing Collection Info"
		PW_Collection()
	end if


	if (bWMIPackages) then
		'--------------------------------------------------------------------------------
		'Chapter 4 - Package Info
		'--------------------------------------------------------------------------------
		ReportProgress " Writing Package Info"
		oWord.Selection.InsertBreak wdPageBreak

		'oWord.Selection.TypeText "" & vbCrLf

		WriteHeader 1,"Package Information"

		PW_Packages()
		

		'--------------------------------------------------------------------------------
		'Chapter 2 - Program Inforomation
		'--------------------------------------------------------------------------------
		ReportProgress " Writing Program Informaiton"
		oWord.Selection.InsertBreak wdPageBreak
		
		WriteHeader 1,"Program Information"
		PW_Programs()
		
		'--------------------------------------------------------------------------------
		'Chapter 4 - Applicaitons
		'--------------------------------------------------------------------------------
		ReportProgress " Writing Applciaiton Info"
		oWord.Selection.InsertBreak wdPageBreak

		'oWord.Selection.TypeText "" & vbCrLf

		WriteHeader 1,"Application Information"
		PW_Applications()
		PW_DeploymentType()
	end if

	if (bwMIAdvert) then
		'--------------------------------------------------------------------------------
		'Chapter 5 - Advertisement Info
		'--------------------------------------------------------------------------------
		ReportProgress " Writing Advertisement Info"
		oWord.Selection.InsertBreak wdPageBreak
		
		WriteHeader 1,"Advertisement information"
		PW_Advertisements()
	end if

	If (bWMIMeter) then
		'--------------------------------------------------------------------------------
		'Chapter 6 - SW Meter Rule
		'--------------------------------------------------------------------------------
		ReportProgress " Writing SW Metering Rules"
		oWord.Selection.InsertBreak wdPageBreak
		
		WriteHeader 1,"Software Metering Rules"
		PW_SoftwareMeteringRules()
	end if

	if (bWMIQueries) then
		'--------------------------------------------------------------------------------
		'Chapter 7 - Queries
		'--------------------------------------------------------------------------------
		ReportProgress " Writing Queries"
		oWord.Selection.InsertBreak wdPageBreak
		
		WriteHeader 1,"Queries"
		PW_Queries()
	End if

	If (bWMIReports) then
		'--------------------------------------------------------------------------------
		'Chapter 8 - Web Reports
		'--------------------------------------------------------------------------------
		ReportProgress " Writing Web Report"
'		oWord.Selection.InsertBreak wdPageBreak
'		
'		WriteHeader 1,"ASP Web Reports"
'		PW_WebReport()
	end if

	If (bWMISecurity) then
		'--------------------------------------------------------------------------------
		'Chapter 8 - Security
		'--------------------------------------------------------------------------------
		ReportProgress " Writing Security"
		oWord.Selection.InsertBreak wdPageBreak
		
		WriteHeader 1,"Security"
		PW_AdministrativeUsers()
		PW_SecurityRoles()
		PW_SecuredCategoryMembership()
		PW_SecurityScopes()
	end if


	'--------------------------------------------------------------------------------
	'Close out tasks
	'--------------------------------------------------------------------------------


	If (bUseSpecificTable) Then
		For i = 1 To CInt(oWord.ActiveDocument.Tables.Count)
			oWord.ActiveDocument.Tables(i).Style = strWordTable
		Next
	End If
	
	If Not (bUseDOTFile) Then
		' Adding header and footer
		If oWord.ActiveWindow.View.SplitSpecial = wdPaneNone Then
			oWord.ActiveWindow.ActivePane.View.Type = wdPrintView
		Else
			oWord.ActiveWindow.View.Type = wdPrintView
		End If
		oWord.ActiveWindow.ActivePane.View.SeekView = wdSeekCurrentPageHeader
		oWord.Selection.TypeText "Basic documentation For " & strComputerSystem_Name
		oWord.ActiveWindow.ActivePane.View.SeekView = wdSeekCurrentPageFooter
		oWord.Selection.ParagraphFormat.Alignment = wdAlignParagraphRight
		oWord.Selection.TypeText "Page ("
		oWord.Selection.Fields.Add oWord.Selection.Range, wdFieldPage
		oWord.Selection.TypeText "/"
		oWord.Selection.Fields.Add oWord.Selection.Range, wdFieldNumPages
		oWord.Selection.TypeText ")"
		oWord.ActiveWindow.ActivePane.View.SeekView = wdSeekMainDocument
	End If
	
	' Update table of contents
	ReportProgress " Updating Tables Of Contents"
	oWord.ActiveDocument.TablesOfContents.Item(1).Update
	
	oWord.ActiveDocument.BuiltInDocumentProperties(wdPropertyComments).Value = "Generated by SYDI-SMS " & strScriptVersion & " (http://www.Enhansoft.com)"
	
	If (bSaveFile) Then 
		ReportProgress " Saving Document"	
		oWord.ActiveDocument.SaveAs strSaveFile
		If (Err <> 0) Then
		    ReportProgress Err.Number & " -- " &  Err.Description & " (" & strSaveFile & ")"
		    ReportProgress " Would not save to " & strSaveFile
		    ReportProgress " Did you specify a path?"
		    Err.Clear
		    Exit Sub
		End If
	End If
	
	If (bShowWord = False And bSaveFile = True) Then
		ReportProgress " Document Saved"
		oWord.Application.Quit
		Set oWord = Nothing
		ReportProgress "End subroutine: PopulateWordfile()"
	Else
		oWord.Application.Visible = True
		ReportProgress "End subroutine: PopulateWordfile()"
	End If
	
	Set oListTemplate = Nothing
	Set oWord = Nothing

End Sub ' PopulateWordfile

Sub ReportProgress(strMessage)
	WScript.Echo strMessage
End Sub ' ReportProgress

Sub GetOptions()
	Dim objArgs, nArgs
	' Default settings
	bWMICollection = True
	bWMIQueries = True
	bWMISite = True
	bWMIReports = True
	bWMIPackages = True
	bWMIAdvert = True
	bWMIMeter = True
	bWMIsecurity = True
	bRegLastUser = True
	bDoRegistryCheck = True
	strComputer = ""
	bAlternateCredentials = False
	bInvalidArgument = False
	bDisplayHelp = False
	bShowWord = True
	bWordExtras = True 
	nBaseFontSize = 10
	bUseSpecificTable = False
	bUseDOTFile = False
'	bSaveFile = False
'	bCheckVersion = False
	strExportFormat = "word"
	strStylesheet = ""
	bAllowErrors = True
	Set objArgs = WScript.Arguments
	If (objArgs.Count > 0) Then
		For nArgs = 0 To objArgs.Count - 1
			SetOptions objArgs(nArgs)
		Next
	Else
		WScript.Echo "For help type: cscript.exe sydi-server.vbs -h"
	End If
	SystemRolesDefine
	If (bSaveFile = False And strExportFormat = "xml") Then
		bInvalidArgument = True
	End If
End Sub ' GetOptions

Sub SetOptions(strOption)
	Dim strFlag, strParameter
	Dim nArguments
	nArguments = Len(strOption)
	If (nArguments < 2) Then
		bInvalidArgument = True
	Else
		strFlag = Left(strOption,2)
		Select Case strFlag
			Case "-b"
				strWordTable = ""
				bUseSpecificTable = True
				If (nArguments > 2) Then
					strWordTable = Right(strOption,(nArguments - 2))
				End If
				If (strWordTable = "") Then
					bInvalidArgument = True
				End If
			Case "-D"
					bAllowErrors = False
					debugmode = True
			Case "-w"
				bWMICollection = False
				bWMIQueries = False
				bWMIReports = False
				bWMISite = False
				bWMIPackages = False
				bWMIAdvert  = False
				bWMIMeter = False
				bWMISecurity = False
				If (nArguments > 2) Then
					For i = 3 To nArguments
						strParameter = Mid(strOption,i,1)
						Select Case strParameter
							Case "a"
								bWMIAdvert = True
							Case "c"
								bWMICollection = True
							case "i"
								bWMISecurity = True
							case "m"
								bWMIMeter = True
							Case "p"
								bWMIPackages = True
							Case "q"
								bWMIQueries = True
							Case "r"
								bWMIReports = True
							Case "s"
								bWMISite = True
						End Select
					Next
				End If
			Case "-e"
				If (nArguments > 2) Then

					For i = 3 To nArguments
						strParameter = Mid(strOption,i,1)
						Select Case strParameter
							Case "w"
								strExportFormat = "word"
							Case Else
								bInvalidArgument = True
						End Select
					
					Next
				End If
			Case "-t"
				If (nArguments > 2) Then
					strComputer = Right(strOption,(nArguments - 2))
				End If
			Case "-d"
					bShowWord = False
			Case "-n"
					bWordExtras  = False
			Case "-o"
					bSaveFile  = True
				If (nArguments > 2) Then
					strSaveFile = Right(strOption,(nArguments - 2))
				Else
					bInvalidArgument = True
				End If
			Case "-f"
				If (nArguments > 2) Then
					nBaseFontSize = Right(strOption,(nArguments - 2))
					If Not (IsNumeric(nBaseFontSize)) Then
						bInvalidArgument = True
					End If
				End If
			Case "-u"
				strUserName = ""
				bAlternateCredentials = True
				If (nArguments > 2) Then
					strUserName = Right(strOption,(nArguments - 2))
				End If
			Case "-p"
				strPassword = ""
				If (nArguments > 2) Then
					strPassword = Right(strOption,(nArguments - 2))
				End If
			Case "-h"
				bDisplayHelp = True
			Case Else
				bInvalidArgument = True
		End Select
	
	End If

End Sub ' SetOptions


Sub WriteHeader(nHeaderLevel,strHeaderText)
	Const wdStyleHeading1 = -2
	Const wdStyleHeading2 = -3
	Const wdStyleHeading3 = -4
	Const wdStyleHeading4 = -5

	Select Case nHeaderLevel
		Case 1
			oWord.Selection.Style = wdStyleHeading1
		Case 2
			oWord.Selection.Style = wdStyleHeading2
		Case 3
			oWord.Selection.Style = wdStyleHeading3
		Case 4
			oWord.Selection.Style = wdStyleHeading4
	End Select
	oWord.Selection.Range.ListFormat.ApplyListTemplate oListTemplate, True
	oWord.Selection.TypeText strHeaderText & vbCrLf
End Sub ' WriteHeader

Sub SystemRolesDefine()
	bRoleSMS = TRUE
	bRoleMP = False
	bRoleCAP = False
	bRoleRP = False
	bRoleSQL = TRUE
	bRoleDP = TRUE
End Sub ' SystemRolesDefine


Sub SystemRolesSet()
	Set objDbrSystemRoles = CreateObject("ADOR.Recordset")
	objDbrSystemRoles.Fields.Append "Role", adVarChar, MaxCharacters
	objDbrSystemRoles.Open

	If (bRoleSMS) Then
		objDbrSystemRoles.AddNew
		objDbrSystemRoles("Role") = "Primary Site"
		objDbrSystemRoles.Update
	End If
	If (bRoleMP) Then
		objDbrSystemRoles.AddNew
		objDbrSystemRoles("Role") = "Management Point"
		objDbrSystemRoles.Update
	End If
	If (bRoleCAP) Then
		objDbrSystemRoles.AddNew
		objDbrSystemRoles("Role") = "Client Access Point"
		objDbrSystemRoles.Update
	End If
	If (bRoleRP) Then
		objDbrSystemRoles.AddNew
		objDbrSystemRoles("Role") = "Reporting Server"
		objDbrSystemRoles.Update
	End If
	If (bRoleSQL) Then
		objDbrSystemRoles.AddNew
		objDbrSystemRoles("Role") = "SQL"
		objDbrSystemRoles.Update
	End If
End Sub ' SystemRolesSet

Sub GetWMIProviderList
	If (bAllowErrors) Then
		On Error Resume Next
	End If
	Dim colNameSpaces
	ReportProgress vbCrlf & "Checking for Other WMI Providers"
	Dim objSWbemLocator
	If (bAlternateCredentials) Then
		Set objSWbemLocator = CreateObject("WbemScripting.SWbemLocator")
		Set objWMIService = objSWbemLocator.ConnectServer(strComputer,"root",strUserName,strPassword)
	Else
		Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root")
	End If
	If (Err <> 0) Then
	    ReportProgress Err.Number & " -- " &  Err.Description & " (" & strComputer & ")"
	    Err.Clear
	    Exit Sub
	End If
	Set colNameSpaces = objWMIService.InstancesOf("__NAMESPACE")
	For Each objItem In colNameSpaces
		Select Case objItem.Name
			Case "MicrosoftIISv2"
				bHasMicrosoftIISv2 = True
				ReportProgress " Found MicrosoftIISv2 (Internet Information Services)"
			Case "SMS"
				bHasSMS = True
				ReportProgress " Found SMS"

		End Select
	Next	
End Sub ' GetWMIProviderList


Sub GetSMSProvider
	If (bAllowErrors) Then
		On Error Resume Next
	End If
	Dim colNameSpaces
	ReportProgress vbCrlf & "Checking SMS WMI Providers"
	Dim objSWbemLocator
	If (bAlternateCredentials) Then
		Set objSWbemLocator = CreateObject("WbemScripting.SWbemLocator")
		Set objWMIService = objSWbemLocator.ConnectServer(strComputer,"root\SMS",strUserName,strPassword)
	Else
		Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\SMS")
	End If
	If (Err <> 0) Then
	    ReportProgress Err.Number & " -- " &  Err.Description & " (" & strComputer & ")"
	    Err.Clear
	    Exit Sub
	End If
	Set colNameSpaces = objWMIService.InstancesOf("__NAMESPACE")
	For Each objProv In colNameSpaces
		if (debugmode) then
			ReportProgress " Debug SMSProv (GetSMSProvider)" 
			ReportProgress " objProv.name = " & objProv.name
			ReportProgress " " 
		End if
		if (instr(1,UCase(objProv.name),"SITE",vbTextCompare) >0) then
			SMSProv = objProv.name
			if (debugmode) then
				ReportProgress " Debug SMSProv (GetSMSProvider)" 
				ReportProgress " SMSProv = " & SMSProv
			End If
		end If
	Next
	'SMSProv = Null ' used for testing only. 
	If (IsNull(SMSProv) = True) Or (SMSProv = "") Then 
		ReportProgress " Didn't determine SMS Provider" 
		SMSProv = InputBox("Enter SMS Provide string (example site_es1) ","Enter Priveder name","site_es1")
	End If
	if (debugmode) then
		ReportProgress " Debug Final SMSProv (GetSMSProvider) name" 
		ReportProgress " SMSProv = " & SMSProv
	End If
	wscript.echo ECStr(SMSProv)
end sub

Function GatherRegInformation()
	Dim arrRegValueNames, arrRegValueTypes
	Dim dwValue
	Dim objRegLocator, objRegService
	Dim arrRegPrograms, strRegProgram, strRegProgramsDisplayName, strRegProgramsDisplayVersion, strRegProgramsTmp
	Dim bRegProgramsSkip
	Dim objRegExp
	
	Const HKEY_LOCAL_MACHINE = &H80000002
	If (bAllowErrors) Then
		On Error Resume Next
	End If
	ReportProgress VbCrLf & "Start subroutine: GatherRegInformation(" & strComputer & ")"
	
	If (bAlternateCredentials) Then
		Set objRegLocator = CreateObject("WbemScripting.SWbemLocator")
		Set objRegService = objRegLocator.ConnectServer(strComputer,"root\default",strUserName,strPassword)
		Set oReg = objRegService.Get("StdRegProv")
	Else
		Set oReg=GetObject("winmgmts:\\" &  strComputer & "\root\default:StdRegProv")
	End If
	
	If (Err <> 0) Then
	    Wscript.Echo Err.Number & " -- " &  Err.Description
	    Err.Clear
	    GatherRegInformation = False
	    Exit Function
	End If

	If (bRegDomainSuffix) Then
		ReportProgress " Reading Domain Information"
		oReg.GetStringValue HKEY_LOCAL_MACHINE,"SYSTEM\CurrentControlSet\Services\Tcpip\Parameters","Domain", strPrimaryDomain
	End If

	If (bRegPrintSpoolLocation) Then
		ReportProgress " Reading Print Spool Location"
		oReg.GetStringValue HKEY_LOCAL_MACHINE,"SYSTEM\CurrentControlSet\Control\Print\Printers","DefaultSpoolDirectory", strPrintSpoolLocation
	End If

	' Checking Terminal Server Settings
	oReg.GetDwordValue HKEY_LOCAL_MACHINE,"SYSTEM\CurrentControlSet\Control\Terminal Server","TSAppCompat", nTerminalServerMode
	
	If (bRegPrograms) Then
		ReportProgress " Reading Programs from Registry"
		Set objDbrRegPrograms = CreateObject("ADOR.Recordset")
		objDbrRegPrograms.Fields.Append "DisplayName", adVarChar, MaxCharacters
		objDbrRegPrograms.Fields.Append "DisplayVersion", adVarChar, MaxCharacters
		objDbrRegPrograms.Open
		Set objRegExp = New RegExp
		oReg.EnumKey HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",arrRegPrograms
		For Each strRegProgram In arrRegPrograms
			bRegProgramsSkip = False
			oReg.GetStringValue HKEY_LOCAL_MACHINE, "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\" & strRegProgram, "DisplayName", strRegProgramsDisplayName
			
			' Remove programs without Display Name
			If (IsNull(strRegProgramsDisplayName)) Then : bRegProgramsSkip = True : End If 
	
			' Remove MSI applications
			If (Len(strRegProgram) = 38) Then 
				strRegProgramsTmp = Left(strRegProgram,1) & Right(strRegProgram,1)
				If (strRegProgramsTmp = "{}") Then : bRegProgramsSkip = True : End If
			End If
			
			' Remove Patches
			objRegExp.IgnoreCase = True
			objRegExp.Pattern = "KB\d{6}"
			strRegProgramsTmp = objRegExp.Test(strRegProgram)
			If (strRegProgramsTmp) Then : bRegProgramsSkip = True : End If
			objRegExp.Pattern = "Q\d{6}"
			strRegProgramsTmp = objRegExp.Test(strRegProgram)
			If (strRegProgramsTmp) Then : bRegProgramsSkip = True : End If

			
			If Not (bRegProgramsSkip) Then
				objDbrRegPrograms.AddNew
				objDbrRegPrograms("DisplayName") = strRegProgramsDisplayName
				
				oReg.GetStringValue HKEY_LOCAL_MACHINE, "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\" & strRegProgram, "DisplayVersion", strRegProgramsDisplayVersion
				objDbrRegPrograms("DisplayVersion") = Scrub(strRegProgramsDisplayVersion)
				
				
				objDbrRegPrograms.Update
			End If
		Next
		objDbrRegPrograms.Sort = "DisplayName"
	End If
	
	If (bRegLastUser) Then
		ReportProgress " Reading Last User"
		oReg.GetStringValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon","DefaultDomainName", strLastUserDomain
		oReg.GetStringValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon","DefaultUserName", strLastUser
		If (Len(strLastUserDomain) > 0) Then
			strLastUser = strLastUserDomain & "\" & strLastUser
		End If
	End If

	If (bRegWindowsComponents) Then
		ReportProgress " Reading Windows Components Information"
		Set objDbrWindowsComponents = CreateObject("ADOR.Recordset")
		objDbrWindowsComponents.Fields.Append "Name", adVarChar, MaxCharacters
		objDbrWindowsComponents.Fields.Append "DisplayName", adVarChar, MaxCharacters
		objDbrWindowsComponents.Fields.Append "Class", adVarChar, MaxCharacters
		objDbrWindowsComponents.Fields.Append "ClassName", adVarChar, MaxCharacters
		objDbrWindowsComponents.Fields.Append "Level", adVarChar, MaxCharacters
		objDbrWindowsComponents.Open
		oReg.EnumValues HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\OC Manager\Subcomponents", arrRegValueNames, arrRegValueTypes
		For i=0 To Ubound(arrRegValueNames)
			oReg.GetDWORDValue HKEY_LOCAL_MACHINE,"SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\OC Manager\Subcomponents",arrRegValueNames(i), dwValue
			If (dwValue = 1) Then
				ReturnWindowsComponentName arrRegValueNames(i)
			End If
	
		Next
		objDbrWindowsComponents.Sort = "Class, DisplayName"
	End If
	
	ReportProgress "End subroutine: GatherRegInformation()"
	GatherRegInformation = True
End Function ' GatherRegInformation


Function WMIDateStringToDate(dtmDate)
dim temp
	If (DebugMode) then
		ReportProgress "WMIDateStringtoDate value=" & dtmDate
	End IF

	temp = CDate(Mid(dtmDate, 5, 2) & "/" & Mid(dtmDate, 7, 2) & "/" & Left(dtmDate, 4) & " " & Mid (dtmDate, 9, 2) & ":" & Mid(dtmDate, 11, 2) & ":" & Mid(dtmDate,13, 2))

	If (DebugMode) then
		ReportProgress "WMIDateStringtoDate  (temp) value=" & temp
	End IF

WMIDateStringToDate = temp
End Function

Sub DisplayHelp
	WScript.Echo "SYDI-Server v." & strScriptVersion
	WScript.Echo "Usage: cscript.exe sydi-server.vbs [options]"
	WScript.Echo "Examples: cscript.exe sydi-server.vbs -wacrs -rc -f10 -tSERVER1"
	WScript.Echo "          cscript.exe sydi-server-vbs -ew -o""H:\Server docs\DC1.xml -tDC1"""
	WScript.Echo "Gathering Options"
	WScript.Echo " -w	- WMI Options (Default: -wcqrs)"
	WScript.Echo "   a	- Advertising Information"
	WScript.Echo "   c	- Collection Information"
 	WScript.Echo "   i	- Security Information"
	WScript.Echo "   m	- Software Metering Information"
 	WScript.Echo "   p	- Package information"
 	WScript.Echo "   q	- Query Information"
 	WScript.Echo "   r	- Report information"
 	WScript.Echo "   s	- Site Information"
 	WScript.Echo " -t	- Target Machine (Default: ask user)"
	WScript.Echo " -u	- Username (To run with different credentials)"
	WScript.Echo " -p	- Password (To run with different credentials, must be used with -u)"
	WScript.Echo "Output Options"
	WScript.Echo " -e	- Export format"
	WScript.Echo "   w	- Microsoft Word (Default)"
 	WScript.Echo " -o	- Save to file (-oc:\corpfiles\server1.doc, use in combination with -d"
 	WScript.Echo "   	  if you don't want to display word at all, use a Path or the file will"
 	WScript.Echo "  	  be placed in your default location usually 'My documents')"
 	WScript.Echo "  	  -oC:\corpfiles\server1.xml"
 	WScript.Echo "  	  WARNING USING -o WILL OVERWRITE TARGET FILE WITHOUT ASKING"
 	WScript.Echo "Word Options"
 	WScript.Echo " -b	- Use specific Word Table (-b""Table Contemporary"""
 	WScript.Echo "   	  or -b""Table List 4"")"
 	WScript.Echo " -f	- Base font size (Default: -f12)"
 	WScript.Echo " -d	- Don't display Word while writing (runs faster)"
 	WScript.Echo " -n	- No extras (minimize the text inside brackets)"
 	WScript.Echo "Other Options"
 	WScript.Echo " -D	- Debug mode, useful for reporting bugs"
 	WScript.Echo VbCrLf
 	WScript.Echo " -h	- Display help"
 	WScript.Echo VbCrLf
End Sub ' DisplayHelp

Function DecodeText(encodedText)

	Dim index, t
	Dim returnString: returnString = ""
	t = encodedText
	encodedText = Mid(encodedText, 7)

	For index = 1 To Len(encodedText) Step 4
		If Mid(encodedText, index + 2, 2) <> "" Then
		returnString = returnString & chr(CDbl("&h" & ECStr(Mid(encodedText, index + 2, 2))))
		End If
	Next
	DecodeText = returnString
End Function


Function Scheduletype(strSchedule)
	Dim strHexStartTime
	Dim returnString: returnString = ""
	strHexStartTime = Left(strSchedule,8)
	If strHexStartTime = "00012000" then
		returnString = "Simple"
	Else                                                   
		returnString = "Custom"
	End IF

	Scheduletype = returnString 
End Function

Function StrTodate(value) 
	Dim ch1
	Dim ch2

	Dim Minutes
	Dim Hours
	Dim Days
	Dim Month
	Dim Year
	Dim date

	ch1 = chartohex(Asc(value))
	ch2 = chartohex(Asc(Mid(value, 2, 1)))

	Ch1 = leftshift(ch1, 2)
	ch2 = rightshift(ch2,2)

	Minutes = ch1 or ch2

	ch1 = chartohex(Asc(Mid(value, 2, 1))) 
	ch2 = chartohex(Asc(Mid(value, 3, 1))) 

	ch1 = ch1 mod 4
	ch1 = leftshift(ch1, 3)
	Ch2 = rightshift(ch2, 1)

	Hours = ch1 or ch2

	ch1 = chartohex(Asc(Mid(value, 3, 1))) 
	ch2 = chartohex(Asc(Mid(value, 4, 1))) 

	ch1 = CH1 mod 2
	ch1 = leftshift(ch1,4)

	Days = ch1 or ch2

	Month = chartohex(Asc(Mid(value, 5, 1)))

	ch1 = chartohex(Asc(Mid(value, 6, 1)))
	ch2 = ChartoHex(Asc(Mid(value, 7, 1)))

	ch1 = leftshift(ch1,2)
	Ch2 = rightshift(ch2, 2)
	Year = (ch1 or ch2 ) + 1970
	date= year & "/" & month & "/" & days & " " & Hours 
	
	if (len(minutes) = 1) then 
		date = date & ":0" & minutes
	else 
		date = date & ":" & minutes
	End if

	StrToDate = date
End Function

Function ChartoHex(Value)
	If value => 48 and Value <= 57 then
		ChartoHex = Value - 48
	Elseif value => 65 and Value <= 70 then 
		ChartoHex = Value - 55 
	else
		ChartoHex = 0
	End if	
End Function

Function LeftShift( expr, bits )
	LeftShift = expr * (2 ^ bits)
End Function

Function RightShift( expr, bits)
	RightShift = expr \ (2 ^ bits)
End Function

Function Schedule(value)
	Dim ch1
	Dim ch2
	Dim flag
	Dim sMinutes
	Dim sHours
	Dim sGMT
	dim sNumMonths
	dim sWeekOrder
	dim sWeeks
	dim sNumberWeeks
	dim sWeekday
	dim sDays
	dim s

'Bits
' 1-5 = Duration time (Hours)
'6-10 = Duration time (Minutes)

	s = "error"

	ch1 = chartohex(Asc(Mid(value, 3, 1)))
	ch2 = chartohex(Asc(Mid(value, 4, 1)))
	
	Ch1 = ch1 mod 4
	Ch1 = leftshift(ch1,1)
	ch2 = rightshift(ch2, 3) 

	flag = Ch1 or ch2

	select case flag
		Case 1 	' Non-Recuring
			s = "Bad Scheduel token"
		Case 2	' Recurinterval
			'Minutes
			ch1 = chartohex(Asc(Mid(value, 4, 1)))
			ch2 = chartohex(Asc(Mid(value, 5, 1)))
			Ch1 = leftshift(ch1,3)
			ch2 = rightshift(ch2, 1) 
			sMinutes = ch1 or ch2
		
			'Hours
			ch1 = chartohex(Asc(Mid(value, 5, 1)))
			ch2 = chartohex(Asc(Mid(value, 6, 1)))
			Ch1 = leftshift(ch1,4)
			sHours = ch1 or ch2
			

			'Days
			ch1 = chartohex(Asc(Mid(value, 7, 1)))
			ch2 = chartohex(Asc(Mid(value, 8, 1)))
			Ch1 = leftshift(ch1,1)
			ch2 = rightshift(ch2, 3) 
			sDays = ch1 or ch2


			If sMinutes <> 0 then s = "Occurs every " & sMinutes & " minutes"
			If sHours <> 0 then s = "Occurs every " & sHours & " hours"
			If sDays <> 0 then s = "Occurs every " & sDays & " days"


'			Not used
'			ch1 = chartohex(Asc(Mid(value, 8, 1)))
'			sGMT = ch1 mod 2

		Case 3	' RecurWeekly
			'Day of the week
			ch1 = chartohex(Asc(Mid(value, 4, 1)))
			sWeekDay = ch1 mod 8

			ch1 = chartohex(Asc(Mid(value, 5, 1)))
			sNumberWeeks = rightshift(ch1,1)

			s = "Occurs every " & sNumberWeeks & " week(s) on "
			select case sWeekday
				case 1
					s = s & "Sunday"
				case 2
					s = s & "Monday"
				case 3
					s = s & "Tuesday"
				case 4
					s = s & "Wednesday"
				case 5
					s = s & "Thursday"
				case 6
					s = s & "Friday"
				case 7
					s = s & "Saturday"
				case else
					s = s & "error"
			End Select
		Case 4	' RecurMonthly
			'Day of the week
			ch1 = chartohex(Asc(Mid(value, 4, 1)))
			sWeekDay = ch1 mod 8

			sNumMonths = chartohex(Asc(Mid(value, 5, 1)))

			ch1 = chartohex(Asc(Mid(value, 6, 1)))
			ch1 = rightshift(ch1,1)
			sWeekOrder = ch1 mod 8

			s = "Occurs the "
			select case sWeekOrder
				case 0
					s = s & "last "
				case 1
					s = s & "first "
				case 2
					s = s & "second "
				case 3
					s = s & "third "
				case 4
					s = s & "forth "
				case else
					s = s & "error "
			End Select
	
			select case sWeekday
				case 1
					s = s & "Sunday"
				case 2
					s = s & "Monday"
				case 3
					s = s & "Tuesday"
				case 4
					s = s & "Wednesday"
				case 5
					s = s & "Thursday"
				case 6
					s = s & "Friday"
				case 7
					s = s & "Saturday"
				case else
					s = s & "error"
			End Select
			s = s & " of every " & sNumMonths & " month(s)"
		Case 5	' RecurMonthlybyDate
			'Day of the week
			ch1 = chartohex(Asc(Mid(value, 4, 1)))
			ch2 = chartohex(Asc(Mid(value, 5, 1)))
			Ch1 = leftshift (ch1,2)
			ch2 = rightshift (ch2,2)
			sDate = ch1 or Ch2
	
			ch1 = chartohex(Asc(Mid(value, 5, 1)))
			ch2 = chartohex(Asc(Mid(value, 6, 1)))
			Ch1 = leftshift (ch1,2)
			ch2 = rightshift (ch2,2)
			sNumMonths = ch1 or ch2

			select case sdate
				case 0
					s = "Occurs the last day of every "

				case else
					s = "Occurs day " & sdate & " of every "
			end select
			s = s & sNumMonths & " month(s)"
		
		case else
			s = "Bad Schedule token"
	End Select
	Schedule = s
End Function

Function TorF(value)
	Dim R
	if Value = 1 then
		R = "true"
	Elseif Value = 0 then 
		R = "false"
	Else
		R = "Error"
	End if
	TorF = R
End Function

Function EorD(value)
	Dim R
	if Value = 1 then
		R = "enable"
	Elseif Value = 0 then 
		R = "disable"
	Else
		R = "Error"
	End if
	EorD = R
End Function

Function ECStr(Value)
	Dim v 
	v = ""
'	if (DebugMode) Then
'		ReportProgress "ECStr v=" & v
'	End If
	if isNull(Value) then
		v=""
		if (DebugMode) Then
			ReportProgress "ECStr is Null"
		End If
	ELse
		v = cstr(Value)
	End If
	ECStr = v
End Function

Sub GatherBoundary 
		Dim tempBoundary, PSS, txtPSS
		txtPSS =""

		'--------------------------------------------------------------------------------
		'Boundary Details
		'--------------------------------------------------------------------------------
		ReportProgress " Gathering Boundary Details"
		
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_Boundary", "WQL", wbemFlagForwardOnly + wbemFlagReturnWhenComplete)
		set objBoundary = createobject("ADOR.Recordset")
		
		objBoundary.fields.append "BoundaryFlags", advarchar, MaxCharacters
		objBoundary.fields.append "BoundaryID", advarchar, MaxCharacters
		objBoundary.fields.append "BoundaryType", advarchar, MaxCharacters
		'objBoundary.fields.append "CreatedBy", advarchar, MaxCharacters
		'objBoundary.fields.append "CreatedOn", advarchar, MaxCharacters
		'objBoundary.fields.append "DefaultSiteCode", advarchar, MaxCharacters
		objBoundary.fields.append "DisplayName", advarchar, MaxCharacters
		'objBoundary.fields.append "GroupCount", advarchar, MaxCharacters
		'objBoundary.fields.append "ModifiedBy", advarchar, MaxCharacters
		'objBoundary.fields.append "ModifiedOn", advarchar, MaxCharacters
		objBoundary.fields.append "SiteSystems", advarchar, MaxCharacters
		objBoundary.fields.append "Value", advarchar, MaxCharacters
		objBoundary.Open
		
		For Each objItem In colItems
			txtPSS =""
			if (debugmode) then
				ReportProgress "  Start Boundary Loop"
			End if
			objBoundary.AddNew
			
			If (debugmode) then
				ReportProgress "  Determine Boundary Flags"
			End if
			if (objItem.BoundaryFlags) = 0 then 
				objBoundary("BoundaryFlags") = ECStr("Fast") 
			Elseif (objItem.BoundaryFlags) = 1 then 
				objBoundary("BoundaryFlags") = ECStr("Slow") 
			Else 
				objBoundary("BoundaryFlags") = ECStr("Unknown Speed")
			End If

			
			objBoundary("BoundaryID") = ECStr(objItem.BoundaryID)
			
			if (debugmode) then
				ReportProgress "  Determine Boundary type"
			End if
			if (ECStr(objItem.BoundaryType)) = 0 then 
				objBoundary("BoundaryType") = ECStr("IPv4 Boundary")
			Elseif (ECStr(objItem.BoundaryType)) = 1 then 
				objBoundary("BoundaryType") = ECStr("AD Boundary") 
			Elseif (ECStr(objItem.BoundaryType)) = 2 then 
				objBoundary("BoundaryType") = ECStr("IPv6 Prefix Boundary")
			Elseif (ECStr(objItem.BoundaryType)) = 3 then 
				objBoundary("BoundaryType") = ECStr("IPv4 Range Boundary")
			Else 
				objBoundary("BoundaryType") = ECStr("Unknown Boundary")
			End If

			objBoundary("DisplayName") = ECStr(objItem.DisplayName)
						
			if (debugmode) then
				ReportProgress "  Determine Protected Boundary Site System"
			End If
			
			ReportProgress "   ProtectedSiteSystems " 
			If isNull(objItem.SiteSystems) Then
				If (debugmode) Then
					ReportProgress "   SiteSystems Null " 
				End If
				txtPSS = ""
			Else
				For Each PSS In objItem.SiteSystems
					If (debugmode) Then
						ReportProgress "   SiteSystems: " & ECStr(PSS)
					End IF
					txtPSS = txtPSS+", "+ECStr(PSS)
				Next
			End If

			objBoundary("SiteSystems") = txtPSS
			if (debugmode) Then
				ReportProgress "   ProtectedSiteSystems: " & txtPSS
				ReportProgress "  After Boundary Protected Site System"
			End If
			
			objBoundary("Value") = ECStr(objItem.Value)
			
			if (debugmode) Then
				ReportProgress "   BoundaryFlags " & objBoundary("BoundaryFlags")
				ReportProgress "   BoundaryID " & objBoundary("BoundaryID")
				ReportProgress "   BoundaryType " & objBoundary("BoundaryType")
				'ReportProgress "   CreatedBy " & objBoundary("CreatedBy")
				'ReportProgress "   CreatedOn " & objBoundary("CreatedOn")
				'ReportProgress "   DefaultSiteCode " & objBoundary("DefaultSiteCode")
				ReportProgress "   DisplayName " & objBoundary("DisplayName")
				'ReportProgress "   GroupCount " & objBoundary("GroupCount")
				'ReportProgress "   ModifiedBy " & objBoundary("ModifiedBy")
				'ReportProgress "   ModifiedOn " & objBoundary("ModifiedOn")
				ReportProgress "   SiteSystems " & objBoundary("SiteSystems")
				ReportProgress "   Value " & objBoundary("Value")
			End if
			objBoundary.update
			if (debugmode) then
				ReportProgress "  End Boundary Loop"
			End if

		Next
		if (debugmode) then
			ReportProgress "  End of Boundary section"
		End if
End Sub 

Sub GatherSite
		'--------------------------------------------------------------------------------
		'Basic Site
		'--------------------------------------------------------------------------------
		ReportProgress " Gathering Basic Site information"
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_Site", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
		set objSite = createobject("ADOR.Recordset")
		objSite.fields.append "BuildNumber", advarchar, MaxCharacters
		objSite.fields.append "InstallDir", advarchar, MaxCharacters
		objSite.fields.append "ReportingSiteCode", advarchar, MaxCharacters
		objSite.fields.append "ServerName", advarchar, MaxCharacters
		objSite.fields.append "SiteCode", advarchar, MaxCharacters
		objSite.fields.append "SiteName", advarchar, MaxCharacters
		objSite.fields.append "Type", advarchar, MaxCharacters
		objSite.fields.append "version", advarchar, MaxCharacters
		objSite.open

		For Each objItem In colItems
			objSite.addnew
			objSite("BuildNumber") = objItem.BuildNumber
			objSite("InstallDir") = objItem.InstallDir
			objSite("ReportingSiteCode") = objItem.ReportingSiteCode
			objSite("ServerName") = objItem.ServerName
			objSite("SiteCode") = objItem.SiteCode
			objSite("SiteName") = objItem.SiteName
			objSite("Type") = objItem.Type
			objSite("version") = objItem.Version
			objsite.update
		next
		objsite.sort = "SiteName"

		ReportProgress " Refreshing Site Control File"
		Set InParams = objWMIService.Get("SMS_SiteControlFile").Methods_("RefreshSCF").InParameters.SpawnInstance_
		InParams.SiteCode = objSite("SiteCode")
		objWMIService.ExecMethod "SMS_SiteControlFile", "RefreshSCF", InParams
End Sub

Sub GatherHardware
		'--------------------------------------------------------------------------------
		'Hardware Agent Setting
		'--------------------------------------------------------------------------------
		ReportProgress " Gathering Hardware Agent Detail"
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_SCI_ClientComp WHERE ClientComponentName = 'Hardware Inventory Agent' AND SiteCode = '" & CStr(objSite("SiteCode")) & "'"& " and filetype = '1'", "WQL", wbemFlagForwardOnly + wbemFlagReturnWhenComplete)
		set objHWAgent = createobject("ADOR.Recordset")
		objHWAgent.fields.append "ClientComponentName", advarchar, MaxCharacters
		objHWAgent.fields.append "Flags", advarchar, MaxCharacters
		objHWAgent.fields.append "ItemName", advarchar, MaxCharacters
		objHWAgent.fields.append "ItemType", advarchar, MaxCharacters
		objHWAgent.fields.append "Proplists", advarchar, MaxCharacters
		objHWAgent.fields.append "PropertyName", advarchar, MaxCharacters
		objHWAgent.fields.append "Value0", advarchar, MaxCharacters
		objHWAgent.fields.append "Value1", advarchar, MaxCharacters
		objHWAgent.fields.append "Value2", advarchar, MaxCharacters
'		objHWAgent.fields.append "RegMultistringlists", advarchar, MaxCharacters
		objHWAgent.fields.append "SiteCode", advarchar, MaxCharacters
		objHWAgent.open
		For Each objItem In colItems
			For Each p in objItem.Props
				if (debugmode) then
					ReportProgress "Client Component " & ECStr(objItem.ClientComponentName)
					ReportProgress "Flags " & ECStr(objItem.Flags)
					ReportProgress "Property Name " & ECStr(p.PropertyName)
					ReportProgress "Property List " & ECStr(ObjItem.PropLists)
					ReportProgress "Item Name " & ECStr(objItem.ItemName)
					ReportProgress "Item Type " & ECStr(objItem.ItemType)
					ReportProgress "PropertyName " & ECStr(p.PropertyName)
					ReportProgress "Value0 " & p.Value
					ReportProgress "Value1 " & p.Value1
					ReportProgress "Value2 " & p.Value2
 					ReportProgress "SiteCode " & ECStr(objItem.SiteCode)
				End if
				objHWAgent.addnew
				objHWAgent("ClientComponentName") = ECStr(objItem.ClientComponentName)
				objHWAgent("Flags") = ECStr(objItem.Flags)
				objHWAgent("ItemType") = ECStr(objItem.ItemType)
				objHWAgent("Proplists") = ECStr(objItem.PropLists)
				objHWAgent("PropertyName") = ECStr(p.PropertyName)
				objHWAgent("Value0") = p.Value
				objHWAgent("Value1") = p.Value1
				objHWAgent("Value2") = p.Value2
'				objHWAgent("RegMultiStringLists") = Ecstr(objItem.RegMultiStringLists)
				objHWAgent("SiteCode") = ECStr(objItem.SiteCode)
				objHWAgent.update
			Next
		Next
		ReportProgress " End of Gathering Hardware Agent Detail"
End Sub

Sub GatherSoftware
		Dim GStemp
		'--------------------------------------------------------------------------------
		'Software Inventory Agent Setting
		'--------------------------------------------------------------------------------
		ReportProgress " Gathering Software Inventory Agent Detail"
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_SCI_ClientComp WHERE ClientComponentName = 'Software Inventory Agent' AND SiteCode = '" & ECStr(objSite("SiteCode")) & "'", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
		set objSWAgent = createobject("ADOR.Recordset")
		objSWAgent.fields.append "ClientComponentName", advarchar, MaxCharacters
		objSWAgent.fields.append "Flags", advarchar, MaxCharacters
		objSWAgent.fields.append "ItemName", advarchar, MaxCharacters
		objSWAgent.fields.append "ItemType", advarchar, MaxCharacters
		objSWAgent.fields.append "Proplists", advarchar, MaxCharacters
		objSWAgent.fields.append "PropertyName", advarchar, MaxCharacters
		objSWAgent.fields.append "Value0", advarchar, MaxCharacters
		objSWAgent.fields.append "Value1", advarchar, MaxCharacters
		objSWAgent.fields.append "Value2", advarchar, MaxCharacters
'		objSWAgent.fields.append "RegMultistringlists", advarchar, MaxCharacters
		objSWAgent.fields.append "SiteCode", advarchar, MaxCharacters
		objSWAgent.open
		For Each objItem In colItems
			For Each p in objItem.Props
				if (debugmode) then
					ReportProgress "ClientComponentName " & ECStr(objItem.ClientComponentName)
					ReportProgress "Flags " & ECStr(objItem.Flags)
					ReportProgress "ItemType " & ECStr(objItem.ItemType)
					ReportProgress "PropertyName " & p.PropertyName
					ReportProgress "Value0 " & ECStr(p.Value)
					ReportProgress "Value1 " & p.Value1
					ReportProgress "Value2 " & p.Value2
					GStemp = objItem.SiteCode
 					ReportProgress "Sitecode " & ECStr(objItem.SiteCode)
				End if
				objSWAgent.addnew
				objSWAgent("ClientComponentName") = ECStr(objItem.ClientComponentName)
				objSWAgent("Flags") = ECStr(objItem.Flags)
				objSWAgent("ItemType") = ECStr(objItem.ItemType)
				objSWAgent("Proplists") = ECStr(objItem.PropLists)
				objSWAgent("PropertyName") = p.PropertyName
				objSWAgent("Value0") = ECStr(p.Value)
				objSWAgent("Value1") = p.Value1
				objSWAgent("Value2") = p.Value2
'				objSWAgent("RegMultiStringLists") = ECStr(objItem.RegMultiStringLists)
				objSWAgent("SiteCode") = ECStr(objItem.SiteCode)
				objSWAgent.update
			Next
		Next
		ReportProgress " End Gathering Software Inventory Agent Detail"
End Sub

Sub GatherClientAgent
		'--------------------------------------------------------------------------------
		'Client Agent Setting
		'--------------------------------------------------------------------------------
		ReportProgress " Gathering Client Agent Detail"
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_SCI_ClientComp WHERE ClientComponentName = 'Client Agent' AND SiteCode = '" & ECStr(objSite("SiteCode")) & "'", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
		set objCAgent = createobject("ADOR.Recordset")
		objCAgent.fields.append "ClientComponentName", advarchar, MaxCharacters
		objCAgent.fields.append "Flags", advarchar, MaxCharacters
		objCAgent.fields.append "ItemName", advarchar, MaxCharacters
		objCAgent.fields.append "ItemType", advarchar, MaxCharacters
		objCAgent.fields.append "Proplists", advarchar, MaxCharacters
		objCAgent.fields.append "PropertyName", advarchar, MaxCharacters
		objCAgent.fields.append "Value0", advarchar, MaxCharacters
		objCAgent.fields.append "Value1", advarchar, MaxCharacters
		objCAgent.fields.append "Value2", advarchar, MaxCharacters
'		objCAgent.fields.append "RegMultistringlists", advarchar, MaxCharacters
		objCAgent.fields.append "SiteCode", advarchar, MaxCharacters
		objCAgent.open
		For Each objItem In colItems
			For Each p in objItem.Props
				objCAgent.addnew
				objCAgent("ClientComponentName") = ECStr(objItem.ClientComponentName)
				objCAgent("Flags") = ECStr(objItem.Flags)
				objCAgent("ItemType") = ECStr(objItem.ItemType)
				objCAgent("Proplists") = ECStr(objItem.PropLists)
				objCAgent("PropertyName") = p.PropertyName
				objCAgent("Value0") = p.Value
				objCAgent("Value1") = p.Value1
				objCAgent("Value2") = p.Value2
'				objCAgent("RegMultiStringLists") = Ecstr(objItem.RegMultiStringLists)
				objCAgent("SiteCode") = ECStr(objItem.SiteCode)
				objCAgent.update
				if (debugmode) then
					ReportProgress objCAgent("ClientComponentName") 
					ReportProgress objCAgent("Flags") 
					ReportProgress objCAgent("ItemName") 
					ReportProgress objCAgent("ItemType")
					ReportProgress objCAgent("PropertyName")
					ReportProgress objCAgent("Value0")
					ReportProgress objCAgent("Value1")
					ReportProgress objCAgent("Value2")
 					ReportProgress objCAgent("Sitecode") 
				End if
			Next
		Next
		ReportProgress " End of Gathering Client Agent Detail"
End Sub

Sub GatherRemoteControl

		'--------------------------------------------------------------------------------
		'Remote Control Agent Setting
		'--------------------------------------------------------------------------------
		ReportProgress " Gathering Remote Control Agent Detail"
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_SCI_ClientComp WHERE ClientComponentName = 'Remote Control' AND SiteCode = '" & ECStr(objSite("SiteCode")) & "'", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
		set objRCAgent = createobject("ADOR.Recordset")
		objRCAgent.fields.append "ClientComponentName", advarchar, MaxCharacters
		objRCAgent.fields.append "Flags", advarchar, MaxCharacters
		objRCAgent.fields.append "ItemName", advarchar, MaxCharacters
		objRCAgent.fields.append "ItemType", advarchar, MaxCharacters
		objRCAgent.fields.append "Proplists", advarchar, MaxCharacters
		objRCAgent.fields.append "PropertyName", advarchar, MaxCharacters
		objRCAgent.fields.append "Value0", advarchar, MaxCharacters
		objRCAgent.fields.append "Value1", advarchar, MaxCharacters
		objRCAgent.fields.append "Value2", advarchar, MaxCharacters
'		objRCAgent.fields.append "RegMultistringlists", advarchar, MaxCharacters
		objRCAgent.fields.append "SiteCode", advarchar, MaxCharacters
		objRCAgent.open
		For Each objItem In colItems
			For Each p in objItem.Props
				objRCAgent.addnew
				objRCAgent("ClientComponentName") = ECStr(objItem.ClientComponentName)
				objRCAgent("Flags") = ECStr(objItem.Flags)
				objRCAgent("ItemType") = ECStr(objItem.ItemType)
				objRCAgent("Proplists") = ECStr(objItem.PropLists)
				objRCAgent("PropertyName") = p.PropertyName
				objRCAgent("Value0") = p.Value
				objRCAgent("Value1") = p.Value1
				objRCAgent("Value2") = p.Value2
'				objRCAgent("RegMultiStringLists") = ecstr(objItem.RegMultiStringLists)
				objRCAgent("SiteCode") = ECStr(objItem.SiteCode)
				objRCAgent.update
				if (debugmode) then
					ReportProgress objRCAgent("ClientComponentName") 
					ReportProgress objRCAgent("Flags") 
					ReportProgress objRCAgent("ItemName") 
					ReportProgress objRCAgent("ItemType")
					ReportProgress objRCAgent("PropertyName")
					ReportProgress objRCAgent("Value0")
					ReportProgress objRCAgent("Value1")
					ReportProgress objRCAgent("Value2")
 					ReportProgress objRCAgent("Sitecode") 
				End if
			Next
		Next
		ReportProgress " End of Gathering Remote Control Agent Detail"
End Sub

Sub GatherSoftwareMetering
		'--------------------------------------------------------------------------------
		'Software Metering Agent Setting
		'--------------------------------------------------------------------------------
		ReportProgress " Gathering Software Metering Agent Detail"
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_SCI_ClientComp WHERE ClientComponentName = 'Software Metering Agent' AND SiteCode = '" & ECStr(objSite("SiteCode")) & "'", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
		set objSMAgent = createobject("ADOR.Recordset")
		objSMAgent.fields.append "ClientComponentName", advarchar, MaxCharacters
		objSMAgent.fields.append "Flags", advarchar, MaxCharacters
		objSMAgent.fields.append "ItemName", advarchar, MaxCharacters
		objSMAgent.fields.append "ItemType", advarchar, MaxCharacters
		objSMAgent.fields.append "Proplists", advarchar, MaxCharacters
		objSMAgent.fields.append "PropertyName", advarchar, MaxCharacters
		objSMAgent.fields.append "Value0", advarchar, MaxCharacters
		objSMAgent.fields.append "Value1", advarchar, MaxCharacters
		objSMAgent.fields.append "Value2", advarchar, MaxCharacters
'		objSMAgent.fields.append "RegMultistringlists", advarchar, MaxCharacters
		objSMAgent.fields.append "SiteCode", advarchar, MaxCharacters
		objSMAgent.open
		For Each objItem In colItems
			For Each p in objItem.Props
				objSMAgent.addnew
				objSMAgent("ClientComponentName") = ECStr(objItem.ClientComponentName)
				objSMAgent("Flags") = ECStr(objItem.Flags)
				objSMAgent("ItemType") = ECStr(objItem.ItemType)
				objSMAgent("Proplists") = ECStr(objItem.PropLists)
				objSMAgent("PropertyName") = p.PropertyName
				objSMAgent("Value0") = p.Value
				objSMAgent("Value1") = p.Value1
				objSMAgent("Value2") = p.Value2
'				objSMAgent("RegMultiStringLists") = ECStr(objItem.RegMultiStringLists)
				objSMAgent("SiteCode") = ECStr(objItem.SiteCode)
				objSMAgent.update
				if (debugmode) then
					ReportProgress objSMAgent("ClientComponentName") 
					ReportProgress objSMAgent("Flags") 
					ReportProgress objSMAgent("ItemName") 
					ReportProgress objSMAgent("ItemType")
					ReportProgress objSMAgent("PropertyName")
					ReportProgress objSMAgent("Value0")
					ReportProgress objSMAgent("Value1")
					ReportProgress objSMAgent("Value2")
 					ReportProgress objSMAgent("Sitecode") 
				End if
			Next
		Next
		ReportProgress " End of Gathering Software Metering Agent Detail"
End Sub

Sub GatherComputerSystem
	'--------------------------------------------------------------------------------
	'Computer System
	'--------------------------------------------------------------------------------
	ReportProgress " Gathering Computer System Information"
	Set colItems = objWMIService.ExecQuery("Select Domain, DomainRole, Name, TotalPhysicalMemory from Win32_ComputerSystem",,48)
	For Each objItem in colItems
		strComputerSystem_Domain = objItem.Domain
		nComputerSystem_DomainRole = objItem.DomainRole
		strComputerSystem_Name = objItem.Name
		strComputerSystem_TotalPhysicalMemory = objItem.TotalPhysicalMemory
		strTotalPhysicalMemoryMB = Round(strComputerSystem_TotalPhysicalMemory / 1024 / 1024)
		Select Case nComputerSystem_DomainRole
			Case 0 
	            strComputerRole = "Standalone Workstation" : strDomainType = "workgroup"
	        Case 1        
	            strComputerRole = "Member Workstation" : strDomainType = "domain"
	        Case 2
	            strComputerRole = "Standalone Server" : strDomainType = "workgroup"
	        Case 3
	            strComputerRole = "Member Server" : strDomainType = "domain"
	        Case 4
	        	bWMILocalAccounts = False
	        	bWMILocalGroups = False
	            strComputerRole = "Domain Controller" : strDomainType = "domain"
	            bRoleDC = True
	        Case 5
	        	bWMILocalAccounts = False
	        	bWMILocalGroups = False
	            strComputerRole = "Domain Controller (PDC Emulator)" : strDomainType = "domain"
	            bRoleDC = True
		End Select
	Next
End sub

Sub GatherOS
	'--------------------------------------------------------------------------------
	'OS
	'--------------------------------------------------------------------------------
	ReportProgress " Gathering OS Information"
	Set colItems = objWMIService.ExecQuery("Select Name, CSDVersion, InstallDate, OSLanguage, Version, WindowsDirectory from Win32_OperatingSystem",,48)
	For Each objItem in colItems
		strOperatingSystem_InstallDate = objItem.InstallDate
		arrOperatingSystem_Name = Split(objItem.Name,"|")
		strOperatingSystem_Caption = arrOperatingSystem_Name(0)
		strOperatingSystem_ServicePack = objItem.CSDVersion
		strOperatingSystem_LanguageCode = Clng(objItem.OSLanguage)
		strOperatingSystem_LanguageCode = Hex(strOperatingSystem_LanguageCode)
		nOperatingSystemLevel = objItem.Version
		strOperatingSystem_WindowsDirectory = objItem.WindowsDirectory
	Next
	nOperatingSystemLevel = Mid(nOperatingSystemLevel,1,1) & Mid(nOperatingSystemLevel,3,1) ' 50 for Win2k 51 for XP
End Sub

Sub GatherSoftwareUpdateAgent
		'--------------------------------------------------------------------------------
		'Software Update Agent Setting
		'--------------------------------------------------------------------------------
		ReportProgress " Gathering Software Update Agent Detail"
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_SCI_ClientComp WHERE ClientComponentName = 'Software Updates' AND SiteCode = '" & ECStr(objSite("SiteCode")) & "'", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
		set objSUAgent = createobject("ADOR.Recordset")
		objSUAgent.fields.append "ClientComponentName", advarchar, MaxCharacters
		objSUAgent.fields.append "Flags", advarchar, MaxCharacters
		objSUAgent.fields.append "ItemName", advarchar, MaxCharacters
		objSUAgent.fields.append "ItemType", advarchar, MaxCharacters
		objSUAgent.fields.append "Proplists", advarchar, MaxCharacters
		objSUAgent.fields.append "PropertyName", advarchar, MaxCharacters
		objSUAgent.fields.append "Value0", advarchar, MaxCharacters
		objSUAgent.fields.append "Value1", advarchar, MaxCharacters
		objSUAgent.fields.append "Value2", advarchar, MaxCharacters
'		objSUAgent.fields.append "RegMultistringlists", advarchar, MaxCharacters
		objSUAgent.fields.append "SiteCode", advarchar, MaxCharacters
		objSUAgent.open
		For Each objItem In colItems
			For Each p in objItem.Props
				objSUAgent.addnew
				objSUAgent("ClientComponentName") = ECStr(objItem.ClientComponentName)
				objSUAgent("Flags") = ECStr(objItem.Flags)
				objSUAgent("ItemType") = ECStr(objItem.ItemType)
				objSUAgent("Proplists") = ECStr(objItem.PropLists)
				objSUAgent("PropertyName") = p.PropertyName
				objSUAgent("Value0") = p.Value
				objSUAgent("Value1") = p.Value1
				objSUAgent("Value2") = p.Value2
'				objSUAgent("RegMultiStringLists") = ECStr(objItem.RegMultiStringLists) 
				objSUAgent("SiteCode") = ECStr(objItem.SiteCode)
				objSUAgent.update
				if (debugmode) then
					ReportProgress objSUAgent("ClientComponentName") 
					ReportProgress objSUAgent("Flags") 
					ReportProgress objSUAgent("ItemName") 
					ReportProgress objSUAgent("ItemType")
					ReportProgress objSUAgent("PropertyName")
					ReportProgress objSUAgent("Value0")
					ReportProgress objSUAgent("Value1")
					ReportProgress objSUAgent("Value2")
 					ReportProgress objSUAgent("Sitecode") 
				End if
			Next
		Next

End Sub

Sub GatherSoftwareDistributionAgent 
		Dim SDATemp
		'--------------------------------------------------------------------------------
		'Software Distribution Agent Setting
		'--------------------------------------------------------------------------------
		ReportProgress " Gathering Software Distribution Agent Detail"
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_SCI_ClientComp WHERE ClientComponentName = 'Software Distribution' AND SiteCode = '" & ECStr(objSite("SiteCode")) & "'", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
		set objSDAgent = createobject("ADOR.Recordset")
		objSDAgent.fields.append "ClientComponentName", advarchar, MaxCharacters
		'objSDAgent.fields.append "FileType", advarchar, MaxCharacters
		objSDAgent.fields.append "Flags", advarchar, MaxCharacters
		objSDAgent.fields.append "ItemName", advarchar, MaxCharacters
		objSDAgent.fields.append "ItemType", advarchar, MaxCharacters
		'objSDAgent.fields.append "Proplists", advarchar, MaxCharacters
		objSDAgent.fields.append "PropertyName", advarchar, MaxCharacters
		objSDAgent.fields.append "Value0", advarchar, MaxCharacters
		objSDAgent.fields.append "Value1", advarchar, MaxCharacters
		objSDAgent.fields.append "Value2", advarchar, MaxCharacters
'		objSDAgent.fields.append "RegMultistringlists", advarchar, MaxCharacters
		objSDAgent.fields.append "SiteCode", advarchar, MaxCharacters
		objSDAgent.open
		For Each objItem In colItems
				For Each p in objItem.Props

					If (debugmode) then
						ReportProgress "ClientComponentName " & ECStr(objItem.ClientComponentName)
						'ReportProgress "Filetype " & ECStr(objItem.Filetype)
						ReportProgress "Flags " & ECStr(objItem.Flags)
						ReportProgress "ItemType " & ECStr(objItem.ItemType)
						ReportProgress "PropertyName " & p.PropertyName
						ReportProgress "Value0 " & p.value
						ReportProgress "Value1 "  & p.value1
						ReportProgress "Value2 "  & p.value2
	 					ReportProgress "Sitecode " & ECStr(objItem.SiteCode)
					End if
					objSDAgent.addnew
					objSDAgent("ClientComponentName") = ECStr(objItem.ClientComponentName)
					'objSDAgent("Filetype") = ECStr(objItem.FileType)
					objSDAgent("Flags") = ECStr(objItem.Flags)
					objSDAgent("ItemType") = ECStr(objItem.ItemType)
					objSDAgent("PropertyName") = p.PropertyName
					objSDAgent("Value0") = p.Value
					objSDAgent("Value1") = p.Value1
					objSDAgent("Value2") = p.Value2
'					objSDAgent("RegMultiStringLists") = ECStr(objItem.RegMultiStringLists) 
					objSDAgent("SiteCode") = ECStr(objItem.SiteCode)
					objSDAgent.update
				Next
		Next
		ReportProgress " End of Gathering Software Distribution Agent Detail"
End Sub

Sub GatherSender
		'--------------------------------------------------------------------------------
		'Sender Setting
		'--------------------------------------------------------------------------------
		ReportProgress " Gathering Sender Detail"
'		DebugMode = True
		'Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_SCI_Address WHERE SiteCode = '" & CStr(objSite("SiteCode")) & "'"& " and filetype = '1'", "WQL", wbemFlagForwardOnly + wbemFlagReturnWhenComplete)
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_SCI_Address WHERE SiteCode = '" & CStr(objSite("SiteCode")) & "'", "WQL", wbemFlagForwardOnly + wbemFlagReturnWhenComplete)
		set objSender = createobject("ADOR.Recordset")

		'objSender.fields.append "AddressPriorityOrder", advarchar, MaxCharacters
		objSender.fields.append "AddressType", advarchar, MaxCharacters
		objSender.fields.append "DesSiteCode", advarchar, MaxCharacters
		'objSender.fields.append "DestinationType", advarchar, MaxCharacters
		objSender.fields.append "FileType", advarchar, MaxCharacters
		objSender.fields.append "ItemName", advarchar, MaxCharacters
		objSender.fields.append "ItemType", advarchar, MaxCharacters
		'objSender.fields.append "Proplists", advarchar, MaxCharacters
		'objSender.fields.append "Props", advarchar, MaxCharacters
		objSender.fields.append "PropertyName", advarchar, MaxCharacters
		objSender.fields.append "Value0", advarchar, MaxCharacters
		objSender.fields.append "Value1", advarchar, MaxCharacters
		objSender.fields.append "Value2", advarchar, MaxCharacters
		objSender.fields.append "SiteCode", advarchar, MaxCharacters
		'objSender.fields.append "SiteName", advarchar, MaxCharacters
		objSender.fields.append "UnlimitedRateForAll", advarchar, MaxCharacters
		'objSender.fields.append "UsageSchedule", advarchar, MaxCharacters
		'objSender.fields.append "Backup", advarchar, MaxCharacters
		'objSender.fields.append "HourUsage", advarchar, MaxCharacters
		'objSender.fields.append "update", advarchar, MaxCharacters
		objSender.open
'		for each objitem in colItems
'			ReportProgress "Sender Setting - SiteCode " & CStr(objSite("SiteCode"))
'		Next
		
		
'			Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_SCI_Address WHERE SiteCode = '" & CStr(objSite("SiteCode")) & "'"& " and filetype = '1'", "WQL", wbemFlagForwardOnly + wbemFlagReturnWhenComplete)
''		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_SCI_Address WHERE SiteCode = '" & CStr(objSite("SiteCode")) & "'", "WQL", wbemFlagForwardOnly + wbemFlagReturnWhenComplete)
			For Each objItem In colItems
				For Each p in objItem.Props
					if (debugmode) then
						ReportProgress "AddressType " & ECStr(objItem.AddressType)
						ReportProgress "DesSiteCode " & ECStr(objItem.DesSiteCode)
						ReportProgress "FileType " & ECStr(ObjItem.FileType)
						ReportProgress "Item Name " & ECStr(objItem.ItemName)
						ReportProgress "Item Type " & ECStr(objItem.ItemType)
						'ReportProgress "Props " & ECStr(p.Props)
						ReportProgress "PropertyName " & ECStr(p.PropertyName)
						ReportProgress "Value0 " & p.Value
						ReportProgress "Value1 " & p.Value1
						ReportProgress "Value2 " & p.Value2
						ReportProgress "SiteCode" & ECStr(objItem.SiteCode)
						ReportProgress "UnlimitedRateForAll" & ECStr(objItem.UnlimitedRateForAll)
 						'ReportProgress "UsageSchedule" & ECStr(objItem.UsageSchedule)
					End if
					objSender.addnew
					objSender("AddressType") = ECStr(objItem.AddressType)
					objSender("DesSiteCode") = ECStr(objItem.DesSiteCode)
					objSender("FileType") = ECStr(objItem.FileType)
					objSender("ItemName") = ECStr(objItem.ItemName)
					objSender("Itemtype") = ECStr(objItem.ItemType)
					objSender("PropertyName") = ECStr(p.PropertyName)
					objSender("Value0") = p.Value
					objSender("Value1") = p.Value1
					objSender("Value2") = p.Value2
					objSender("SiteCode") = ECStr(objItem.SiteCode)
					objSender("UnlimitedRateForAll") = ECStr(objItem.UnlimitedRateForAll)
					'objSender("UsageSchedule") = ECStr(objItem.UsageSchedule)
					objSender.update
				Next
			Next
End Sub

Sub GatherCollection
		'--------------------------------------------------------------------------------
		'Collection
		'--------------------------------------------------------------------------------

		ReportProgress " Gathering Collection information"
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_Collection", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
		set objCollect = createobject("ADOR.Recordset")
		objCollect.fields.append "CollectionID",advarchar, MaxCharacters
		objCollect.fields.append "Name",advarchar, MaxCharacters
		objCollect.fields.append "Comment", advarchar, MaxCharacters
		objCollect.fields.append "LastRefreshTime", advarchar, MaxCharacters
'		objCollect.fields.append "RefreshSchedule", advarchar, MaxCharacters
		objCollect.open
	
		For Each objItem In colItems
				if (debugmode) then
					ReportProgress "CollectionID " & objItem.CollectionID
					ReportProgress "Name " & objItem.Name
					ReportProgress "Comment " & objItem.Comment
					ReportProgress "LastRefreshTime " & WMIDateStringToDate(objItem.LastRefreshTime)
'					ReportProgress "RefreshSchedule " & WMIDateStringToDate(objItem.RefreshSchedule)
				End If 
			objcollect.addnew
			objcollect("CollectionID") = objItem.CollectionID
			objcollect("Name") = objItem.Name
			objcollect("Comment") = objItem.Comment
			objcollect("LastRefreshTime") = WMIDateStringToDate(objItem.LastRefreshTime)
'			objcollect("RefreshSchedule") = WMIDateStringToDate(objItem.RefreshSchedule)
			objcollect.update
		next
		objcollect.sort = "Name"
End Sub

Sub GatherPackage
		ReportProgress " Gathering Package information"
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_Package", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
		set objPackage = createobject("ADOR.Recordset")
		objPackage.fields.append "Description",advarchar, MaxCharacters
		objPackage.fields.append "Language",advarchar, MaxCharacters
'		objPackage.fields.append "LastRefreshTime", advarchar, MaxCharacters
		objPackage.fields.append "Manufacturer", advarchar, MaxCharacters
		objPackage.fields.append "Name", advarchar, MaxCharacters
		objPackage.fields.append "Packageid",advarchar, MaxCharacters
		objPackage.fields.append "PkgFlags", advarchar, MaxCharacters
		objPackage.fields.append "PkgSourcePath",advarchar, MaxCharacters
'		objPackage.fields.append "RefreshSchedule", advarchar, MaxCharacters
'		objPackage.fields.append "ShareName", advarchar, MaxCharacters
'		objPackage.fields.append "ShareType", advarchar, MaxCharacters	
'		objPackage.fields.append "SourceSite", advarchar, MaxCharacters
'		objPackage.fields.append "SourceVersion", advarchar, MaxCharacters
'		objPackage.fields.append "Version", advarchar, MaxCharacters	
		objPackage.open
	
		For Each objItem In colItems
			objPackage.addnew
			objPackage("Description") = objItem.Description
			objPackage("Language") = objItem.Language
'			objPackage("LastRefreshTime") = WMIDateStringToDate(objItem.LastRefreshTime)
			objPackage("Manufacturer") = objItem.Manufacturer
			objPackage("Name") = objItem.Name
			objPackage("PackageID") = objItem.PackageID
			objPackage("PkgFlags") = objItem.PkgFlags
			objPackage("PkgSourcePath") = ECStr(objItem.PkgSourcePath)
'			strRefreshSchedule = Join(objItem.RefreshSchedule, ",")
'			objPackage("RefreshSchedule") = strRefreshSchedule
'			objPackage("ShareName") = ECStr(objItem.ShareName)
'			objPackage("ShareType") = objItem.ShareType
'			objPackage("SourceSite") = objItem.SourceSite
'			objPackage("SourceVersion") = objItem.SourceVersion
'			objPackage("Version") = objItem.Version
			objPackage.update
			if (debugmode) then
				ReportProgress objItem.Description
				ReportProgress objItem.Language
				ReportProgress objItem.Manufacturer
				ReportProgress objItem.Name
				ReportProgress objItem.PackageID
				ReportProgress objItem.PkgFlags
				ReportProgress objItem.PkgSourcePath
			end if
'			ReportProgress " PKGFlags" 
		next
		objPackage.sort = "Name"

	'--------------------------------------------------------------------------------
	'Programs
	'--------------------------------------------------------------------------------

		ReportProgress " Gathering Programs information"
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_Program", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
		set objProgram = createobject("ADOR.Recordset")
		objProgram.fields.append "ActionInProgress",advarchar, MaxCharacters
		objProgram.fields.append "ApplicationHierarchy",advarchar, MaxCharacters
		objProgram.fields.append "CommandLine", advarchar, MaxCharacters
		objProgram.fields.append "Comment", advarchar, MaxCharacters
		objProgram.fields.append "DependentProgram", advarchar, MaxCharacters
		objProgram.fields.append "Description",adVarChar, MaxCharacters
		objProgram.fields.append "DeviceFlags",advarchar, MaxCharacters
		objProgram.fields.append "DiskSpaceReq",advarchar, MaxCharacters
		objProgram.fields.append "DriveLetter", advarchar, MaxCharacters
		objProgram.fields.append "Duration", advarchar, MaxCharacters
		objProgram.fields.append "MSIFilePath", advarchar, MaxCharacters	
		objProgram.fields.append "MSIProductID", advarchar, MaxCharacters
		objProgram.fields.append "PackageID", advarchar, MaxCharacters
		objProgram.fields.append "ProgramFlags", advarchar, MaxCharacters
		objProgram.fields.append "ProgramName", advarchar, MaxCharacters	
		objProgram.fields.append "RemovalKey", advarchar, MaxCharacters
		objProgram.fields.append "WorkingDirectory", advarchar, MaxCharacters
		objProgram.Open
		
		set objProgram_OS = createobject("ADOR.Recordset")
		objProgram_OS.fields.append "PackageID", advarchar, MaxCharacters
		objProgram_OS.fields.append "ProgramName", advarchar, MaxCharacters	
		objProgram_OS.fields.append "Platform",advarchar, MaxCharacters
		objProgram_OS.fields.append "MaxVersion",advarchar, MaxCharacters
		objProgram_OS.fields.append "MinVersion", advarchar, MaxCharacters
		objProgram_OS.fields.append "OS_REAL_NAME", advarchar, MaxCharacters
		objProgram_OS.Open
		
		For Each objItem2 In colItems
'			debugmode = True
			objProgram.addnew
			objProgram("ActionInProgress") = objItem2.ActionInProgress
			objProgram("ApplicationHierarchy") = objItem2.ApplicationHierarchy
			objProgram("CommandLine") = objItem2.CommandLine
			objProgram("Comment") = objItem2.Comment
			objProgram("DependentProgram") = objItem2.DependentProgram
			objProgram("Description") = objItem2.Description
			objProgram("DeviceFlags") = objItem2.DeviceFlags
			objProgram("DiskSpaceReq") = objItem2.DiskSpaceReq
			objProgram("DriveLetter") = objItem2.DriveLetter
			objProgram("Duration") = objItem2.Duration
			objProgram("MSIFilePath") = objItem2.MSIFilePath
			objProgram("MSIProductID") = objItem2.MSIProductID
			objProgram("PackageID") = objItem2.PackageID
			objProgram("ProgramFlags") = objItem2.ProgramFlags
			objProgram("ProgramName") = objItem2.ProgramName
			objProgram("RemovalKey") = objItem2.RemovalKey
			objProgram("WorkingDirectory") = objItem2.WorkingDirectory
			objProgram.update

			if (debugmode) then
				ReportProgress "ProgramFlags: " & ecstr(objProgram("ProgramFlags"))
				ReportProgress "ProgramFlags2: " & ecstr((objProgram("ProgramFlags") and RUN_ON_SPECIFIED_PLATFORMS))
				for each name in objItem.SupportedOperationSystem
					ReportProgress "ProgramFlags3: " & ecstr(objItem2.name)
				next
			End If

			If (objProgram("ProgramFlags") and RUN_ON_SPECIFIED_PLATFORMS) <> 0 Then
				if (debugmode) then
					ReportProgress "All OS & CPU types"
				End if
				objProgram_OS.addnew
				objProgram_OS("PackageID") = objItem2.PackageID
				objProgram_OS("ProgramName") = objItem2.ProgramName
				objProgram_OS("Platform") = "x86, x64, & i64"
				objProgram_OS("MaxVersion") = "9.9"
				objProgram_OS("MinVersion") = "3.1"
				objProgram_OS("OS_REAL_NAME") = "All OS & CPU types"
				objProgram_OS.update
			Else 
'			ReportProgress ECStr(objItem.SupportedOperatingSystems)
				For each Name in objItem2.SupportedOperatingSystems
					OS_REAL_NAME = Name.Platform + " " + Name.minversion + " " + Name.MaxVersion  
'					debugmode = True
					if (debugmode) then
						ReportProgress "Defined CPU type"
						ReportProgress "Real OS name: " & OS_REAL_NAME
						ReportProgress "OS Name: " & name.Platform
						ReportProgress "OS Min Version: " & name.minversion
						ReportProgress "OS Max Version: " & name.MaxVersion  
					End IF
					If name.Platform = "IA64" and name.MaxVersion = "6.20.9999.9999" and name.minversion = "6.20.0000.0" then
						OS_REAL_NAME = "All IA64 Windows Server 2003 (Non R2)"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = ecstr(name.Platform)
						objProgram_OS("MaxVersion") = ecstr(name.MaxVersion)
						objProgram_OS("MinVersion") = ecstr(name.minversion)
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
					End if
					If name.Platform = "IA64" and name.MaxVersion = "6.00.9999.9999" and name.minversion = "6.00.0000.1" then
						OS_REAL_NAME = "All IA64 Windows Server 2008"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
					End if
					If name.Platform = "x64" and name.MaxVersion = "6.10.9999.9999" and name.minversion = "6.10.0000.0" then
						OS_REAL_NAME = "All x64 Windows 7"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
					End if
					If name.Platform = "x64" and name.MaxVersion = "5.20.9999.9999" and name.minversion = "5.20.0000.0" then
        					OS_REAL_NAME = "All x64 Windows 2003 Server (Non R2)"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
		        		If name.Platform = "x64" and name.MaxVersion = "5.20.3790.2" and name.minversion = "5.20.3790.0" then
       						OS_REAL_NAME = "All x64 Windows 2003 Server R2"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
       					End if
	        			If name.Platform = "x64" and name.MaxVersion = "6.00.9999.9999" and name.minversion = "6.00.0000.1" then
       						OS_REAL_NAME = "All x64 Windows 2008 Server"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
       					End if
		        		If name.Platform = "x64" and name.MaxVersion = "6.10.9999.9998" and name.minversion = "6.10.0000.0" then
       						OS_REAL_NAME = "All x64 Windows 2008 Server R2"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
       					End if
					If name.Platform = "x64" and name.MaxVersion = "6.00.9999.9999" and name.minversion = "6.00.0000.0" then
						OS_REAL_NAME = "All x64 Windows Vista"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
		        		If name.Platform = "x64" and name.MaxVersion = "5.20.9999.9999" and name.minversion = "5.20.3790.0" then
        					OS_REAL_NAME = "All x64 Windows XP"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
					End if
	        			If name.Platform = "I386" and name.MaxVersion = "5.00.9999.9999" and name.minversion = "5.00.0000.0" then
        					OS_REAL_NAME = "All x86 Windows 2000"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
		        		If name.Platform = "I386" and name.MaxVersion = "6.10.9999.9999" and name.minversion = "6.10.0000.0" then
        					OS_REAL_NAME = "All x86 Windows 7"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
	        			If name.Platform = "I386" and name.MaxVersion = "5.20.9999.9999" and name.minversion = "5.20.0000.0" then
        					OS_REAL_NAME = "All x86 Windows 2003 Server (Non R2)"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
	        			If name.Platform = "I386" and name.MaxVersion = "5.20.3790.2" and name.minversion = "5.20.3790.0" then
        					OS_REAL_NAME = "All x86 Windows 2003 Server R2"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
	        			End if
        				If name.Platform = "I386" and name.MaxVersion = "6.00.9999.9999" and name.minversion = "6.00.0000.1" then
        					OS_REAL_NAME = "All x86 Windows Server 2008"
		       				if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
					End if
	               			If name.Platform = "I386" and name.MaxVersion = "6.00.9999.9999" and name.minversion = "6.00.0000.0" then
        					OS_REAL_NAME = "All x86 Windows Vista"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
	       				End if
                			If name.Platform = "I386" and name.MaxVersion = "5.10.9999.9999" and name.minversion = "5.10.0000.0" then
        					OS_REAL_NAME = "All x86 Windows XP"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
	               			If name.Platform = "IA64" and name.MaxVersion = "5.20.3790.0" and name.minversion = "5.20.3790.0" then
        					OS_REAL_NAME = "IA64 Windows 2003 Sever SP1"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
               				If name.Platform = "IA64" and name.MaxVersion = "5.20.3790.2" and name.minversion = "5.20.3790.2" then
        					OS_REAL_NAME = "IA64 Windows 2003 Server SP2"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
	               			If name.Platform = "IA64" and name.MaxVersion = "6.00.6001.1" and name.minversion = "6.00.6000.1" then
        					OS_REAL_NAME = "IA64 Windows Server 2008"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
               				If name.Platform = "IA64" and name.MaxVersion = "6.00.9990.2" and name.minversion = "6.00.6002.2" then
        					OS_REAL_NAME = "IA64 Windows Server 2008"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
	               			If name.Platform = "x64" and name.MaxVersion = "6.10.9990.0" and name.minversion = "6.10.7600.0" then
      						OS_REAL_NAME = "x64 Windows 7"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
               				If name.Platform = "x64" and name.MaxVersion = "5.20.3790.3" and name.minversion = "5.20.3790.0" then
        					OS_REAL_NAME = "x64 Windows Server 2003 R2 Original Release (SP1)"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
	               			If name.Platform = "x64" and name.MaxVersion = "5.20.3790.0" and name.minversion = "5.20.3790.0" then
        					OS_REAL_NAME = "x64 Windows 2003 Server SP1"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
               				If name.Platform = "x64" and name.MaxVersion = "5.20.3790.2" and name.minversion = "5.20.3790.2" then
        					OS_REAL_NAME = "x64 Windows 2003 Server SP2"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
	               			If name.Platform = "x64" and name.MaxVersion = "6.00.6001.1" and name.minversion = "6.00.6001.1" then
        					OS_REAL_NAME = "x64 Windows 2008"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
					End if
               				If name.Platform = "x64" and name.MaxVersion = "6.10.9991.0" and name.minversion = "6.10.7600.0" then
        					OS_REAL_NAME = "x64 Windows 2008 Server R2"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
	               			If name.Platform = "x64" and name.MaxVersion = "6.00.9990.2" and name.minversion = "6.00.6002.2" then
        					OS_REAL_NAME = "x64 Windows 2008 Server SP2"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
               				If name.Platform = "x64" and name.MaxVersion = "6.00.6000.0" and name.minversion = "6.00.6000.0" then
        					OS_REAL_NAME = "x64 Windows Vista Original Release"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
       					End if
	               			If name.Platform = "x64" and name.MaxVersion = "6.00.6001.0" and name.minversion = "6.00.6001.0" then
        					OS_REAL_NAME = "x64 Windows Vista SP1"
        					if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
					End if
               				If name.Platform = "x64" and name.MaxVersion = "6.00.9999.2" and name.minversion = "6.00.6002.2" then
        					OS_REAL_NAME = "x64 Windows Vista SP2"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
	               			If name.Platform = "x64" and name.MaxVersion = "5.20.3790.3" and name.minversion = "5.20.3790.3" then
        					OS_REAL_NAME = "x64 Windows XP SP3"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
               				If name.Platform = "x64" and name.MaxVersion = "5.20.3790.0000" and name.minversion = "5.20.3790.0" then
        					OS_REAL_NAME = "x64 Windows XP SP1"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
	               			If name.Platform = "x64" and name.MaxVersion = "5.20.3790.2000" and name.minversion = "5.20.3790.2" then
        					OS_REAL_NAME = "x64 Windows XP SP2"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
               				If name.Platform = "I386" and name.MaxVersion = "5.00.2195.4" and name.minversion = "5.00.2195.4" then
        					OS_REAL_NAME = "x86 Windows 2000 SP4"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
	               			If name.Platform = "I386" and name.MaxVersion = "6.10.9990.0" and name.minversion = "6.10.7600.0" then
        					OS_REAL_NAME = "x86 Windows 7"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
               				If name.Platform = "I386" and name.MaxVersion = "5.20.3790.3" and name.minversion = "5.20.3790.0" then
        					OS_REAL_NAME = "x64 Windows Server 2003 R2 Original Release (SP1)"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
	               			If name.Platform = "I386" and name.MaxVersion = "5.20.3790.1" and name.minversion = "5.20.3790.0" then
        					OS_REAL_NAME = "x86 Windows 2003 Server SP1"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
               				If name.Platform = "I386" and name.MaxVersion = "5.20.3790.2" and name.minversion = "5.20.3790.2" then
        					OS_REAL_NAME = "x86 Windows 2003 Server SP2"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
	               			If name.Platform = "I386" and name.MaxVersion = "6.00.6001.1" and name.minversion = "6.00.6001.1" then
        					OS_REAL_NAME = "x86 Windows 2008"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
               				If name.Platform = "I386" and name.MaxVersion = "6.00.9990.2" and name.minversion = "6.00.6002.2" then
        					OS_REAL_NAME = "x86 Windows 2008 Server SP2"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
	               			If name.Platform = "I386" and name.MaxVersion = "6.00.6000.0" and name.minversion = "6.00.6000.0" then
        					OS_REAL_NAME = "x86 Windows Vista Original Release"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
	       				End if
                			If name.Platform = "I386" and name.MaxVersion = "6.00.6001.0" and name.minversion = "6.00.6001.0" then
        					OS_REAL_NAME = "x86 Windows Vista SP1"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
        				End if
	        	       		If name.Platform = "I386" and name.MaxVersion = "6.00.9999.2" and name.minversion = "6.00.6002.2" then
        					OS_REAL_NAME = "x86 Windows Vista SP2"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
	        			End if
                			If name.Platform = "I386" and name.MaxVersion = "5.10.2600.2" and name.minversion = "5.10.2600.2" then
        					OS_REAL_NAME = "x86 Windows XP SP2"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
		        		End if
	                		If name.Platform = "I386" and name.MaxVersion = "5.10.2600.3" and name.minversion = "5.10.2600.3" then
	       					OS_REAL_NAME = "x86 Windows XP SP3"
						if (debugmode) then
							ReportProgress "Platform: " & ecstr(Name.Platform)
							ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
							ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
							ReportProgress "OS name: " & OS_REAL_NAME
						End if
						objProgram_OS.addnew
						objProgram_OS("PackageID") = objItem.PackageID
						objProgram_OS("ProgramName") = objItem.ProgramName
						objProgram_OS("Platform") = name.Platform
						objProgram_OS("MaxVersion") = name.MaxVersion
						objProgram_OS("MinVersion") = name.minversion
						objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
						objProgram_OS.update
					End if
					if (debugmode) then
						ReportProgress "Platform: " & ecstr(Name.Platform)
						ReportProgress "Max Version: " & ecstr(Name.MaxVersion)
						ReportProgress "Min Version: " & ecstr(Name.MinVersion) 
						ReportProgress "OS name: " & OS_REAL_NAME
					End if
					objProgram_OS.addnew
					objProgram_OS("PackageID") = objItem.PackageID
					objProgram_OS("ProgramName") = objItem.ProgramName
					objProgram_OS("Platform") = name.Platform
					objProgram_OS("MaxVersion") = name.MaxVersion
					objProgram_OS("MinVersion") = name.minversion
					objProgram_OS("OS_REAL_NAME") = OS_REAL_NAME
					objProgram_OS.update
				Next
					debugmode = False
			end if
			objProgram.update
			if (debugmode) then
				ReportProgress objItem.ActionInProgress
				ReportProgress objItem.ApplicationHierarchy
				ReportProgress objItem.CommandLine
				ReportProgress objItem.Comment
				ReportProgress objItem.DependentProgram
				ReportProgress objItem.Description
				ReportProgress objItem.DeviceFlags
				ReportProgress objItem.DiskSpaceReq
				ReportProgress objItem.DriveLetter
				ReportProgress objItem.Duration
				ReportProgress objItem.MSIFilePath
				ReportProgress objItem.MSIProductID
				ReportProgress objItem.PackageID
				ReportProgress objItem.ProgramFlags
				ReportProgress objItem.ProgramName
				ReportProgress objItem.RemovalKey
				ReportProgress objItem.Requirements
				ReportProgress objItem.WorkingDirectory
				ReportProgress objProgram("ProgramName")
			end if
'			ReportProgress " Program " 
		next
		objProgram.sort = "ProgramName"
'		debugmode = Flase
End Sub

Sub GatherAdvertisement
		'--------------------------------------------------------------------------------
		'Advertisement
		'--------------------------------------------------------------------------------

		ReportProgress " Gathering Advertisement information"
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_Advertisement", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
		set objAdvert = createobject("ADOR.Recordset")
		objadvert.fields.append "AdvertisementID",advarchar, MaxCharacters
		objadvert.fields.append "AdvertisementName",advarchar, MaxCharacters
		objadvert.fields.append "CollectionID", advarchar, MaxCharacters
		objadvert.fields.append "SourceSite", advarchar, MaxCharacters
		objadvert.fields.append "PackageID", advarchar, MaxCharacters
		objadvert.fields.append "ProgramName", advarchar, MaxCharacters
		objadvert.fields.append "Comment", advarchar, MaxCharacters
		objadvert.open
	
		For Each objItem In colItems
			If (Debugmode) then 
				ReportProgress "AdvertisementID = " & objItem.AdvertisementID
				ReportProgress "AdvertisementName = " & objItem.AdvertisementName
				ReportProgress "CollectionID = " & objItem.CollectionID
				ReportProgress "SourceSite = " & objItem.SourceSite
				ReportProgress "PackageID = " & objItem.PackageID
				ReportProgress "ProgramName = " & objItem.ProgramName
				ReportProgress "Comment = " & objItem.Comment
			End If

			objadvert.addnew
			objadvert("AdvertisementID") = objItem.AdvertisementID
			objadvert("AdvertisementName") = objItem.AdvertisementName
			objadvert("CollectionID") = objItem.CollectionID
			objadvert("SourceSite") = objItem.ProgramName
			objadvert("PackageID") = objItem.PackageID
			objadvert("ProgramName") = objItem.ProgramName
			objadvert("Comment") = objItem.Comment
			objadvert.update
		next
		objadvert.sort = "AdvertisementName"
End Sub

Sub GatherMeteringRules
		'--------------------------------------------------------------------------------
		'Metering Rules
		'--------------------------------------------------------------------------------

		ReportProgress " Gathering SW mettering rules  information"
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_MeteredProductRule", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
		set objswmeter = createobject("ADOR.Recordset")
		objswmeter.fields.append "ApplyToChildSites",advarchar, MaxCharacters
		objswmeter.fields.append "Comment",advarchar, MaxCharacters
		objswmeter.fields.append "Enabled", advarchar, MaxCharacters
		objswmeter.fields.append "FileName", advarchar, MaxCharacters
		objswmeter.fields.append "FileVersion", advarchar, MaxCharacters
		objswmeter.fields.append "LanguageID", advarchar, MaxCharacters
		objswmeter.fields.append "Lastupdatetime", advarchar, MaxCharacters
		objswmeter.fields.append "originalfilename",advarchar, MaxCharacters
		objswmeter.fields.append "productname",advarchar, MaxCharacters
		objswmeter.fields.append "ruleid", advarchar, MaxCharacters
		objswmeter.fields.append "securityKey", advarchar, MaxCharacters
		objswmeter.fields.append "sitecode", advarchar, MaxCharacters
		objswmeter.fields.append "sourcesite", advarchar, MaxCharacters
		objswmeter.open
	
		For Each objItem In colItems
			If (Debugmode) then 
				ReportProgress "ApplyToChildSites " & objItem.ApplyToChildSites
				ReportProgress "Comment " & objItem.Comment
				ReportProgress "Enabled " & objItem.Enabled
				ReportProgress "FileName " & objItem.FileName
				ReportProgress "FileVersion " & objItem.FileVersion
				ReportProgress "LanguageID " & objItem.LanguageID
				ReportProgress "Lastupdatetime " & objItem.Lastupdatetime
				ReportProgress "originalfilename " & objItem.Originalfilename
				ReportProgress "productname " & objItem.productname
				ReportProgress "ruleid " & objItem.ruleid
				ReportProgress "securityKey " & objItem.securitykey
				ReportProgress "sitecode " & objItem.sitecode
				ReportProgress "sourcesite " & objItem.sourcesite
			End If

			objswmeter.addnew
			objswmeter("ApplyToChildSites") = objItem.ApplyToChildSites
			objswmeter("Comment") = objItem.Comment
			objswmeter("Enabled") = objItem.Enabled
			objswmeter("FileName") = objItem.FileName
			objswmeter("FileVersion") = objItem.FileVersion
			objswmeter("LanguageID") = objItem.LanguageID
			objswmeter("Lastupdatetime") = objItem.Lastupdatetime
			objswmeter("originalfilename") = objItem.Originalfilename
			objswmeter("productname") = objItem.productname
			objswmeter("ruleid") = objItem.ruleid
			objswmeter("securityKey") = objItem.securitykey
			objswmeter("sitecode") = objItem.sitecode
			objswmeter("sourcesite") = objItem.sourcesite
			objswmeter.update
		next
		objswmeter.sort = "productname"
End Sub

Sub GatherASPReports
		'--------------------------------------------------------------------------------
		'web Reports
		'--------------------------------------------------------------------------------

		ReportProgress " Gathering ASP Report information"
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_Report", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
		set objWebR = createobject("ADOR.Recordset")
		objWebR.fields.append "Category",advarchar, MaxCharacters
		objWebR.fields.append "Comment",advarchar, MaxCharacters
		objWebR.fields.append "Name", advarchar, MaxCharacters
		objWebR.fields.append "ReportID", advarchar, MaxCharacters
'		objWebR.fields.append "SQLQuery", advarchar, MaxCharacters
		objWebR.open
	
		For Each objItem In colItems

			if (debugmode) then
				ReportProgress "-----------"
				ReportProgress ECStr(objItem.ReportID)
				ReportProgress ECStr(objItem.Category)
				ReportProgress ECStr(objItem.Comment)
				ReportProgress ECStr(objItem.Name)
				ReportProgress "-----------"
			end if

			objWebR.addnew
			objWebR("Category") = ECStr(objItem.Category)
			objWebR("Comment") = ECStr(objItem.Comment)
			objWebR("Name") = ECStr(objItem.Name)
			objWebR("ReportID") = ECStr(objItem.ReportID)
'			objWebR("SQLQuery") = ECStr(objItem.SQLQuery)
			objWebR.update
		next
		objWebR.sort = "Name"
End Sub

Sub GatherQueries

		'--------------------------------------------------------------------------------
		'Queries
		'--------------------------------------------------------------------------------

		ReportProgress " Gathering Queries  information"
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_Query", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
		set objQueries = createobject("ADOR.Recordset")
		objQueries.fields.append "Comments",advarchar, MaxCharacters
		objQueries.fields.append "Name", advarchar, MaxCharacters
		objQueries.fields.append "QueryID", advarchar, MaxCharacters
		objQueries.open
	
		For Each objItem In colItems
			if (debugmode) then
				ReportProgress "-----------"
				ReportProgress ECStr(objItem.Name)
				ReportProgress ECStr(objItem.Comments)
				ReportProgress ECStr(objItem.QueryID)
				ReportProgress "-----------"
			end if

			objQueries.addnew
			objQueries("Comments") = objItem.Comments
			objQueries("Name") = objItem.Name
			objQueries("QueryID") = objItem.QueryID
			objQueries.update
		next
		objQueries.sort = "Name"
End Sub

Sub GatherApplication
	Dim tmp77
	'--------------------------------------------------------------------------------
	' Application
	'--------------------------------------------------------------------------------

		ReportProgress " Gathering Application information"
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_Application Where IsExpired = 0", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
		set objApplication = createobject("ADOR.Recordset")
		objApplication.fields.append "LocalizedDescription",advarchar, MaxCharacters
		objApplication.fields.append "LocalizedDisplayName",advarchar, MaxCharacters
		objApplication.fields.append "Manufacturer", advarchar, MaxCharacters
		objApplication.fields.append "ModelName", advarchar, MaxCharacters
		objApplication.open
	
		For Each objItem In colItems
			objApplication.AddNew
			tmp77 = objItem.LocalizedDescription
			tmp77 = objItem.LocalizedDisplayName
			tmp77 = objItem.Manufacturer
			tmp77 = objItem.ModelName
			objApplication("LocalizedDescription") = objItem.LocalizedDescription
			objApplication("LocalizedDisplayName") = objItem.LocalizedDisplayName
			objApplication("Manufacturer") = objItem.Manufacturer
			objApplication("ModelName") = objItem.ModelName
			objApplication.update
			if (debugmode) then
				ReportProgress objItem.LocalizedDescription
				ReportProgress objItem.LocalizedDisplayName
				ReportProgress objItem.Manufacturer
				ReportProgress objItem.ModelName
			end if
		next
		objApplication.sort = "LocalizedDisplayName"

	'--------------------------------------------------------------------------------
	' Depoyment Type
	'--------------------------------------------------------------------------------

		ReportProgress " Gathering Deployment Type information"
		'Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_DeploymentType", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_DeploymentType Where IsExpired = 0", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
		set objDeploymentType = createobject("ADOR.Recordset")
		objDeploymentType.Fields.append "LocalizedDescription",advarchar, MaxCharacters
		objDeploymentType.Fields.append "LocalizedDisplayName",advarchar, MaxCharacters
		objDeploymentType.Fields.append "Technology",advarchar, MaxCharacters
		objDeploymentType.Fields.append "AppModelName",advarchar, MaxCharacters
		objDeploymentType.Open
		
		For Each objItem In colItems
			objDeploymentType.AddNew
			tmp77 = objItem.LocalizedDescription
			tmp77 = objItem.LocalizedDisplayName
			tmp77 = objItem.Technology
			tmp77 = objItem.AppModelName
			objDeploymentType("LocalizedDescription") = objItem.LocalizedDescription
			objDeploymentType("LocalizedDisplayName") = objItem.LocalizedDisplayName
			objDeploymentType("Technology") = objItem.Technology
			objDeploymentType("AppModelName") = objItem.AppModelName
			objDeploymentType.update
			if (debugmode) then
				ReportProgress "LocalizedDescription: " & objItem.LocalizedDescription
				ReportProgress "LocalizedDisplayName: " & objItem.LocalizedDisplayName
				ReportProgress "Technology: " & objItem.Technology
				ReportProgress "AppModelName: " & objItem.AppModelName
			End If
			objProgram.update
		next
		objDeploymentType.sort = "Technology"
End Sub

Sub GatherSecurityScopes
		'--------------------------------------------------------------------------------
		'Security Scopes
		'--------------------------------------------------------------------------------

		ReportProgress " Gathering Security Scope Information"
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_SecuredCategory", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
		set objSecuredCategory = createobject("ADOR.Recordset")
		objSecuredCategory.fields.append "CategoryName",advarchar, MaxCharacters
		objSecuredCategory.fields.append "CategoryID",advarchar, MaxCharacters
		objSecuredCategory.fields.append "CategoryDescription", advarchar, MaxCharacters
		objSecuredCategory.open
	
		For Each objItem In colItems
			if (debugmode) then
				ReportProgress "-----------"
				ReportProgress ECStr(objItem.CategoryName)
				ReportProgress ECStr(objItem.CategoryID)
				ReportProgress ECStr(objItem.CategoryDescription)
				ReportProgress "-----------"
			end if
			objSecuredCategory.addnew
			objSecuredCategory("CategoryName") = objItem.CategoryName
			objSecuredCategory("CategoryID") = objItem.CategoryID
			objSecuredCategory("CategoryDescription") = objItem.CategoryDescription
			objSecuredCategory.update
		next
		objSecuredCategory.sort = "CategoryName"
End Sub

Sub GatherSecuredCategoryMembership
		'--------------------------------------------------------------------------------
		'Security Scopes
		'--------------------------------------------------------------------------------

		ReportProgress " Gathering Secured Category Membership"
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_SecuredCategoryMembership", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
		set objSecuredCategoryMembership = createobject("ADOR.Recordset")
		objSecuredCategoryMembership.fields.append "CategoryID",advarchar, MaxCharacters
		objSecuredCategoryMembership.fields.append "ObjectKey",adVarChar, MaxCharacters
		objSecuredCategoryMembership.fields.append "ObjecttypeID", advarchar, MaxCharacters
		objSecuredCategoryMembership.open
	
		For Each objItem In colItems
			if (debugmode) then
				ReportProgress "-----------"
				ReportProgress ECStr(objItem.CategoryID)
				ReportProgress ECStr(objItem.ObjectKey)
				ReportProgress ECStr(objItem.ObjecttypeID)
				ReportProgress "-----------"
			end if
			objSecuredCategoryMembership.addnew
			objSecuredCategoryMembership("CategoryID") = objItem.CategoryID
			objSecuredCategoryMembership("ObjectKey") = objItem.ObjectKey
			objSecuredCategoryMembership("ObjecttypeID") = objItem.ObjecttypeID
			objSecuredCategoryMembership.update
		next
		objSecuredCategoryMembership.sort = "CategoryID"
End Sub

Sub GatherUsers
		'--------------------------------------------------------------------------------
		'Security Users
		'--------------------------------------------------------------------------------

		ReportProgress " Gathering Security Users"
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_Admin", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
		set objUser = createobject("ADOR.Recordset")
		objUser.fields.append "LogonName",advarchar, MaxCharacters
		objUser.fields.append "DisplayName",adVarChar, MaxCharacters
		objUser.fields.append "RoleNames", advarchar, MaxCharacters
		objUser.open
	
		For Each objItem In colItems
			if (debugmode) then
				ReportProgress "-----------"
				ReportProgress ECStr(objItem.LogonName)
				ReportProgress ECStr(objItem.DisplayName)
				ReportProgress ECStr(objItem.RoleNames)
				ReportProgress "-----------"
			end if
			'objUser.AddNew
			For Each objitem2 In objItem.RoleNames
				objUser.AddNew
				objUser("LogonName") = objItem.LogonName
				objUser("DisplayName") = objItem.DisplayName
				objUser("RoleNames") = objItem2
				objUser.Update
			Next
		next
		objUser.sort = "LogonName"
End Sub

Sub GatherRoles
		'--------------------------------------------------------------------------------
		'Security Security Roles
		'--------------------------------------------------------------------------------

		ReportProgress " Gathering Security Roles"
		Set colItems = objWMIService.ExecQuery("SELECT * FROM SMS_Role", "WQL", wbemFlagReturnImmediately + wbemFlagForwardOnly)
		set objRoles = createobject("ADOR.Recordset")
		objRoles.fields.append "RoleName",advarchar, MaxCharacters
		objRoles.fields.append "NumberOfAdmins",adVarChar, MaxCharacters
		objRoles.fields.append "RoleDescription", advarchar, MaxCharacters
		objRoles.open
	
		For Each objItem In colItems
			if (debugmode) then
				ReportProgress "-----------"
				ReportProgress ECStr(objItem.RoleName)
				ReportProgress ECStr(objItem.NumberOfAdmins)
				ReportProgress ECStr(objItem.RoleDescription)
				ReportProgress "-----------"
			end if
				objRoles.AddNew
				objRoles("RoleName") = objItem.RoleName
				objRoles("NumberOfAdmins") = objItem.NumberOfAdmins
				objRoles("RoleDescription") = objItem.RoleDescription
				objRoles.Update
		next
		objRoles.sort = "RoleName"
End Sub

Sub PW_SecurityScopes
		WriteHeader 2,"Security Scopes"
		oWord.Selection.Style = wdStyleBodyText
		oWord.Selection.TypeText VbCrLf
		oWord.Selection.Font.Bold = False
		oWord.ActiveDocument.Tables.Add oWord.Selection.Range, objSecuredCategory.Recordcount + 1, 3
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Category Name" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Category ID" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Description" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = False

		objSecuredCategory.Movefirst
		Do Until objSecuredCategory.EOF
			oWord.Selection.TypeText ECStr(objSecuredCategory("CategoryName"))
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objSecuredCategory("CategoryID"))
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objSecuredCategory("CategoryDescription"))
			oWord.Selection.MoveRight
			objSecuredCategory.MoveNext
		Loop
		oWord.Selection.TypeText vbCrLf
		
End sub

Sub PW_SecuredCategoryMembership
		WriteHeader 2,"Secured Category Membership"
		oWord.Selection.Style = wdStyleBodyText
		oWord.Selection.TypeText VbCrLf
		oWord.Selection.Font.Bold = False
		oWord.ActiveDocument.Tables.Add oWord.Selection.Range, objSecuredCategoryMembership.Recordcount + 1, 3
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Category ID" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Object Key" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Object Type ID" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = False

		objSecuredCategoryMembership.Movefirst
		Do Until objSecuredCategoryMembership.EOF
			oWord.Selection.TypeText ECStr(objSecuredCategoryMembership("CategoryID"))
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objSecuredCategoryMembership("ObjectKey"))
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objSecuredCategoryMembership("ObjecttypeID"))
			oWord.Selection.MoveRight
			objSecuredCategoryMembership.MoveNext
		Loop
		oWord.Selection.TypeText vbCrLf
End Sub

Sub PW_SecurityRoles
		WriteHeader 2,"Security Roles"
		oWord.Selection.Style = wdStyleBodyText
		oWord.Selection.TypeText VbCrLf
		oWord.Selection.Font.Bold = False
		tmp80 = objRoles.Recordcount + 1
		oWord.ActiveDocument.Tables.Add oWord.Selection.Range, objRoles.Recordcount + 1, 3
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Role Name" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Number Of Admins" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Role Description" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = False

		objRoles.Movefirst
		Do Until objRoles.EOF
			oWord.Selection.TypeText ECStr(objRoles("RoleName"))
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objRoles("NumberOfAdmins"))
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objRoles("RoleDescription"))
			oWord.Selection.MoveRight
			objRoles.MoveNext
		Loop
		oWord.Selection.TypeText VbCrLf
End sub

Sub PW_AdministrativeUsers
		WriteHeader 2,"Administrative Users"
		oWord.Selection.Style = wdStyleBodyText
		oWord.Selection.TypeText VbCrLf
		oWord.Selection.Font.Bold = False
		oWord.ActiveDocument.Tables.Add oWord.Selection.Range, objUser.Recordcount + 1, 3
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Logon Name" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Display Name" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Role Names" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = False

		objRoles.Movefirst
		Do Until objUser.EOF
			oWord.Selection.TypeText ECStr(objUser("LogonName"))
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objUser("DisplayName"))
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objUser("RoleNames"))
			oWord.Selection.MoveRight
			objUser.MoveNext
		Loop
		oWord.Selection.TypeText VbCrLf
End Sub

Sub PW_Queries
		WriteHeader 2,"List of Queries"
		oWord.Selection.Style = wdStyleBodyText
		oWord.Selection.TypeText VbCrLf
		oWord.Selection.Font.Bold = False

		oWord.ActiveDocument.Tables.Add oWord.Selection.Range, objQueries.Recordcount + 1, 3
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Name"
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Query ID" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Comment" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = False

		If Not (objQueries.Bof) Then
			objQueries.Movefirst
		End If			

		Do Until objQueries.EOF
			oWord.Selection.TypeText ECStr(objQueries("Name"))
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objQueries("QueryID"))
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objQueries("Comments"))
			oWord.Selection.MoveRight
			objQueries.MoveNext
		Loop

		oWord.Selection.TypeText VbCrLf
End Sub

Sub PW_SoftwareMeteringRules
		WriteHeader 2,"List of Software Metering Rules"
		oWord.Selection.Style = wdStyleBodyText
		oWord.Selection.TypeText VbCrLf
		oWord.Selection.Font.Bold = False

		oWord.ActiveDocument.Tables.Add oWord.Selection.Range, objswmeter.Recordcount + 1, 6
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Name" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Rule ID" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Comment" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "File Name" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "File Version" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Language ID" 
		oWord.Selection.MoveRight
'		oWord.Selection.Font.Bold = False

		If Not (objswmeter.Bof) Then
			objswmeter.Movefirst
		End If			

		Do Until objswmeter.EOF
			oWord.Selection.TypeText ECStr(objswmeter("productname")) 
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objswmeter("ruleid")) 
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objswmeter("Comment")) 
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objswmeter("FileName")) 
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objswmeter("FileVersion")) 
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objswmeter("Languageid")) 
			oWord.Selection.MoveRight
			objswmeter.MoveNext
		Loop

		oWord.Selection.TypeText VbCrLf
End Sub

Sub PW_Advertisements
		WriteHeader 2,"List of Advertisements"
		oWord.Selection.Style = wdStyleBodyText
		oWord.Selection.TypeText VbCrLf
		oWord.Selection.Font.Bold = True
'		oWord.Selection.TypeText "Advertisement" & vbCrLf
		oWord.Selection.Font.Bold = False

		oWord.ActiveDocument.Tables.Add oWord.Selection.Range, objadvert.Recordcount + 1, 7
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Advertisement ID" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Advertisement Name" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Collection ID" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Source Site" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Package ID" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Program Name" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Comment" 
		oWord.Selection.MoveRight

		oWord.Selection.Font.Bold = False

		If Not (objadvert.Bof) Then
			objadvert.Movefirst
		End If			

		Do Until objadvert.EOF
			oWord.Selection.TypeText ECStr(objadvert("AdvertisementID")) 
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objadvert("AdvertisementName")) 
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objadvert("CollectionID")) 
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objadvert("ProgramName")) 
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objadvert("PackageID")) 
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objadvert("SourceSite")) 
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objadvert("Comment")) 
			oWord.Selection.MoveRight
			objadvert.MoveNext
		Loop

		oWord.Selection.TypeText vbCrLf
End sub

Sub PW_Applications
		WriteHeader 2,"List of Applications"
		oWord.Selection.Style = wdStyleBodyText
		oWord.Selection.TypeText VbCrLf
		oWord.Selection.Font.Bold = False

		oWord.ActiveDocument.Tables.Add oWord.Selection.Range, objApplication.Recordcount + 1, 3
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Display Name" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Description" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Manufacturer" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = False
		'oWord.Selection.TypeText VbCrLf

		If Not (objApplication.Bof) Then
			objApplication.Movefirst
		End If			

		Do Until objApplication.EOF
			oWord.Selection.TypeText ECStr(objApplication("LocalizedDisplayName")) 
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objApplication("LocalizedDescription")) 
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objApplication("Manufacturer")) 
			oWord.Selection.MoveRight
			oWord.Selection.MoveRight
			objApplication.MoveNext
		Loop

		oWord.Selection.TypeText VbCrLf
End Sub

Sub PW_DeploymentType 
		'--------------------------------------------------------------------------------
		'Chapter 2 - Deployment Type
		'--------------------------------------------------------------------------------
		ReportProgress " Writing Deployment Type Informaiton"
		oWord.Selection.InsertBreak wdPageBreak
		
		WriteHeader 1,"Deployment Types Information"
		
		oWord.Selection.Style = wdStyleBodyText
	
		If Not (objApplication.Bof) Then
			objApplication.Movefirst
		End If			

		Do Until objApplication.EOF
			WriteHeader 2, ecstr(objApplication("LocalizedDisplayName"))
			objDeploymentType.Movefirst
			Do Until objDeploymentType.EOF 
				tmp78 = objDeploymentType("AppModelName")
				tmp79 = objApplication("ModelName") 
				If objDeploymentType("AppModelName") = objApplication("ModelName") Then
					WriteHeader 3, objProgram("LocalizedDisplayName")
					oWord.Selection.Style = wdStyleBodyText
					oWord.Selection.TypeText vbCrLf
					oWord.Selection.Font.Bold = True
					oWord.Selection.TypeText "Description: "
					oWord.Selection.Font.Bold = FALSE
					oWord.Selection.TypeText objDeploymentType("LocalizedDescription") & vbCrLf
					oWord.Selection.Font.Bold = True
					oWord.Selection.TypeText "Deployment Technology: "
					oWord.Selection.Font.Bold = FALSE
					oWord.Selection.TypeText objDeploymentType("Technology") & vbCrLf
				End If
				objDeploymentType.Movenext
			Loop
			objApplication.MoveNext
		Loop
End Sub

Sub PW_WebReport
		WriteHeader 2,"List of Web Report"
		oWord.Selection.Style = wdStyleBodyText
		oWord.Selection.TypeText VbCrLf
		oWord.Selection.Font.Bold = False

		oWord.ActiveDocument.Tables.Add oWord.Selection.Range, objWebR.Recordcount + 1, 4
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Name" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Category" : oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Comment" : oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Report ID" : oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = False
'		oWord.Selection.Font.Bold = True
'		oWord.Selection.TypeText "SQL Query" : oWord.Selection.MoveRight
'		oWord.Selection.Font.Bold = False


		If Not (objWebR.Bof) Then
			objWebR.Movefirst
		End If			
		Do Until objWebR.EOF
			oWord.Selection.TypeText ECStr(objWebR("Name"))
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objWebR("Category"))
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objWebR("Comment"))
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objWebR("ReportID"))
			oWord.Selection.MoveRight
'			oWord.Selection.TypeText ECStr(objWebR("SQLQuery"))
'			oWord.Selection.MoveRight
			objwebR.MoveNext
		Loop

		oWord.Selection.TypeText VbCrLf
End Sub

Sub PW_Programs
		oWord.Selection.Style = wdStyleBodyText
	
		If Not (objPackage.Bof) Then
			objPackage.Movefirst
		End If			

		Do Until objPackage.EOF
			WriteHeader 2, ecstr(objPackage("Name"))
			objProgram.Movefirst
			Do Until objProgram.EOF 
				If objProgram("Packageid") = objPackage("Packageid") then
					WriteHeader 3, objProgram("ProgramName")
					oWord.Selection.Style = wdStyleBodyText
					oWord.Selection.TypeText vbCrLf
					oWord.Selection.Font.Bold = True
					oWord.Selection.TypeText "Comment: "
					oWord.Selection.Font.Bold = FALSE
					oWord.Selection.TypeText objProgram("Comment") & vbCrLf

					oWord.Selection.Font.Bold = True
					oWord.Selection.TypeText "Description: "
					oWord.Selection.Font.Bold = FALSE
					oWord.Selection.TypeText  objProgram("Description") & vbCrLf

					oWord.Selection.Font.Bold = True
					oWord.Selection.TypeText "Command Line: "
					oWord.Selection.Font.Bold = FALSE
					oWord.Selection.TypeText objProgram("CommandLine") & vbCrLf

					oWord.Selection.Font.Bold = True
					oWord.Selection.TypeText "Working Directory: "
					oWord.Selection.Font.Bold = FALSE
					oWord.Selection.TypeText  objProgram("WorkingDirectory") & vbCrLf

'					oWord.Selection.Font.Bold = True
'					oWord.Selection.TypeText "Removal Key: "
'					oWord.Selection.Font.Bold = FALSE
'					oWord.Selection.TypeText  objProgram("RemovalKey") & vbCrLf

					oWord.Selection.Font.Bold = True
					oWord.Selection.TypeText "Dependent Program: "
					oWord.Selection.Font.Bold = FALSE
					oWord.Selection.TypeText  objProgram("DependentProgram") & vbCrLf

					oWord.Selection.Font.Bold = True
					oWord.Selection.TypeText "Disk Space Requirements: "
					oWord.Selection.Font.Bold = FALSE
					oWord.Selection.TypeText  objProgram("DiskSpaceReq") & vbCrLf

					oWord.Selection.Font.Bold = True
					oWord.Selection.TypeText "Drive Letter: "
					oWord.Selection.Font.Bold = FALSE
					oWord.Selection.TypeText objProgram("DriveLetter") & vbCrLf

					oWord.Selection.Font.Bold = True
					oWord.Selection.TypeText "Duration: "
					oWord.Selection.Font.Bold = FALSE
					oWord.Selection.TypeText objProgram("Duration") & vbCrLf

					oWord.Selection.Font.Bold = True
					oWord.Selection.TypeText "MSI file Path: "
					oWord.Selection.Font.Bold = FALSE
					oWord.Selection.TypeText objProgram("MSIFilePath") & vbCrLf

'					oWord.Selection.Font.Bold = True
'					oWord.Selection.TypeText "MSI Product ID: "
'					oWord.Selection.Font.Bold = FALSE
'					oWord.Selection.TypeText objProgram("MSIProductID") & vbCrLf

'					oWord.Selection.Font.Bold = True
'					oWord.Selection.TypeText "Requirements: "
'					oWord.Selection.Font.Bold = FALSE
'					oWord.Selection.TypeText objProgram("Requirements") & vbCrLf
'					oWord.Selection.TypeText vbCrLf

					WriteHeader 4, "Supported Operating Systems"
					oWord.Selection.Style = wdStyleBodyText
					objProgram_OS.Movefirst
'					ReportProgress "before loop"
					Do Until objProgram_OS.EOF
'						ReportProgress "In loop"
						If (objProgram("Packageid") = objProgram_OS("Packageid")) then 
							If (objProgram("ProgramName") = objProgram_OS("ProgramName")) then
								oWord.Selection.Font.Bold = True
								oWord.Selection.TypeText "OS Name: "
								oWord.Selection.Font.Bold = FALSE
								oWord.Selection.TypeText objProgram_OS("OS_REAL_NAME") & vbCrLf
	
								oWord.Selection.Font.Bold = True
								oWord.Selection.TypeText "Platform: "
								oWord.Selection.Font.Bold = FALSE
								oWord.Selection.TypeText objProgram_OS("Platform") & vbCrLf
	
								oWord.Selection.Font.Bold = True
								oWord.Selection.TypeText "Min Version: "
								oWord.Selection.Font.Bold = FALSE
								oWord.Selection.TypeText objProgram_OS("MinVersion") & vbCrLf
	
								oWord.Selection.Font.Bold = True
								oWord.Selection.TypeText "Max Version: "
								oWord.Selection.Font.Bold = FALSE
								oWord.Selection.TypeText objProgram_OS("MaxVersion") & vbCrLf
	
'								ReportProgress objProgram_OS("Platform") 
'								ReportProgress objProgram_OS("MaxVersion")
'								ReportProgress objProgram_OS("MinVersion")
'								ReportProgress objProgram_OS("OS_REAL_NAME")
							end if
						end if
						objProgram_OS.Movenext
					loop
				End If
				objProgram.Movenext
			Loop
			objPackage.MoveNext
		Loop
End Sub

Sub PW_Packages
		WriteHeader 2,"List of Packages"
		oWord.Selection.Style = wdStyleBodyText
		oWord.Selection.TypeText VbCrLf
		oWord.Selection.Font.Bold = False

		oWord.ActiveDocument.Tables.Add oWord.Selection.Range, objPackage.Recordcount + 1, 6
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Name" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Package ID" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Manufacturer" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Language" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Description" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Source Path" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
'		oWord.Selection.TypeText "Binary Delta Replication" 
'		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = False


		If Not (objpackage.Bof) Then
			objpackage.Movefirst
		End If			

		Do Until objpackage.EOF
			oWord.Selection.TypeText ECStr(objpackage("Name")) 
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objpackage("PackageID")) 
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objpackage("Manufacturer")) 
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objpackage("Language")) 
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objpackage("Description")) 
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objpackage("PkgSourcePath")) 
			oWord.Selection.MoveRight
'			ReportProgress " PKGFlags" 
'			ReportProgress objpackage("PkgFlags")
'			If (objpackage("PkgFlags")=&h4000000) then 			
'				oWord.Selection.TypeText "x"
'			else
'				oWord.Selection.TypeText " "
'			end if
			oWord.Selection.MoveRight
			objpackage.MoveNext
		Loop

		oWord.Selection.TypeText vbCrLf
End Sub

Sub PW_Collection
		oWord.Selection.InsertBreak wdPageBreak
		WriteHeader 1,"Collection Information"
		WriteHeader 2,"List of Collections"
		oWord.Selection.Style = wdStyleBodyText
		oWord.Selection.TypeText VbCrLf
		oWord.Selection.Font.Bold = True
'		oWord.Selection.TypeText "Collection" & vbCrLf
		oWord.Selection.Font.Bold = False

		oWord.ActiveDocument.Tables.Add oWord.Selection.Range, objcollect.Recordcount + 1, 4
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Collection ID" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Collection Name" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Comment" 
		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = True
		oWord.Selection.TypeText "Last Refresh time" 
		oWord.Selection.MoveRight
'		oWord.Selection.Font.Bold = True
'		oWord.Selection.TypeText "Refresh Schedule" 
'		oWord.Selection.MoveRight
		oWord.Selection.Font.Bold = False

		If Not (objcollect.Bof) Then
			objcollect.Movefirst
		End If			


		Do Until objcollect.EOF
			oWord.Selection.TypeText ECStr(objcollect("CollectionID")) 
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objcollect("Name")) 
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objcollect("Comment")) 
			oWord.Selection.MoveRight
			oWord.Selection.TypeText ECStr(objcollect("LastRefreshTime")) 
			oWord.Selection.MoveRight
'			oWord.Selection.TypeText objcollect("RefreshSchedule") 
'			oWord.Selection.MoveRight
			objcollect.MoveNext
		Loop

		oWord.Selection.TypeText vbCrLf
End sub