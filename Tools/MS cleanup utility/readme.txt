README FOR WINDOWS INSTALLER CLEAN UP UTILITY version 3
SEPTEMBER, 2006

WHAT IS THE WINDOWS INSTALLER CLEAN UP UTILITY?
The Windows Installer Clean Up Utility is a tool that can be used to remove Windows Installer configuration management information if a problem occurs. 

*** NOTE: The Windows Installer Clean Up Utility should not be used to remove the 2007 Microsoft Office System installation information. ***

 The Windows Installer configuration management information can become damaged if any of the following issues occur:

 - The computer's registry becomes corrupted.

 - A registry setting that is used by the Windows Installer is 
   inadvertently changed, and this change results in a problem.

 - The installation of a program that uses Windows Installer (for 
   example, Microsoft Office 2003) is interrupted.

 - There are multiple instances of a setup program running at the same time, or 
   an instance of a setup program is "blocked."


WHAT HAPPENED TO MSICU.EXE?
In the original release, there were two versions of the Windows Installer Clean Up Utility: Msicu.exe (for use in Microsoft Windows 95, Windows 98 and Windows ME), and Msicuu.exe (for use in Windows NT, Windows 2000, Windows XP, and Windows Server 2003). Msicu.exe was removed because Msicuu.exe now works with all 32-bit versions of Microsoft Windows.


WHAT IS MSIZAP.EXE?
The Windows Installer Clean Up Utility uses the Msizap.exe program file to perform cleanup operations on the Windows Installer configuration management information. Microsoft does not recommend that you run Msizap.exe manually, because Msizap.exe uses a command-line interface. Msizap.exe does not provide the same ease of use or level of protection as the Windows Installer Clean Up Utility.


WHY IS THERE NO MSIZAP.EXE IN THE EXTRACTED FILES?
There are two versions of MSIZAP.EXE: MsiZapA.exe (for use in Windows 95, Windows 98 and Windows ME), and MsiZapU.exe (for use in Windows NT, Windows 2000, Windows XP, and Windows Server 2003). The appropriate executable must be renamed MsiZap.exe in order for the Windows Installer Clean Up Utility to work correctly. The installation process renames and installs the correct version automatically.


HOW DO I INSTALL THE WINDOWS INSTALLER CLEAN UP UTILITY?
When you download the utility, choose either Install or Save (if you choose Save then run the downloaded executable from the folder in which you saved the executable). By default, the setup program installs the Windows Installer Clean Up Utility files to a folder beneath the Program Files folder. This folder is called "Windows Installer Clean Up."
All the files that are used by the utility (Msicuu.exe, Msizap.exe, and this Readme file) are copied into this folder, and a shortcut is created on the Programs menu under the Start menu.

The files may also be extracted manually from the downloaded file. However, after you do this, you must rename the appropriate MsiZap*.exe file "MsiZap.exe." (NOTE: If you use the utility on Windows 95/98/98SE/ME, rename MsiZapA.exe. Otherwise, rename MsiZapU.exe.)


HOW DO I RUN THE WINDOWS INSTALLER CLEAN UP UTILITY?
To run the Windows Installer Clean Up Utility, use either of the following methods:
 - Click 'Start', click 'All Programs' (or 'Programs' on some operating systems), and then click the shortcut for the 
   Windows Installer Clean Up Utility.
 - Find and run the Msicuu.exe file.

A dialog box will be displayed that contains a message, a list of installed products, and four buttons.

The message that is displayed is as follows:

   Continuing further will make permanent changes to your system. You may
   need to reinstall some or all applications on your system that used the
   Windows Installer technology to be installed. If you do not want to 
   proceed, please press the 'Exit' button now. Choosing 'Remove' will 
   make the permanent changes.

The list contains the titles of all the installed programs that are registered with Windows Installer. Because the Windows Installer Clean Up Utility installation also uses Windows Installer, the Windows Installer Clean Up Utility should be included in the list. Select the programs that you wish to remove. (To select multiple items in the list, hold down the SHIFT key or the CTRL key as you select the items.)

The four buttons in the dialog box are as follows:

   [Select All] - Selects all the programs in the list.

   [Clear All] - Clears the selection of all the programs in the list.

   [Remove] - Removes the Windows Installer installation information for 
      the selected program or programs.

   [Exit] - Exits the Windows Installer Clean Up Utility.

If you click 'Remove,' the following prompt is displayed:

   Warning - All items selected will be removed from the Windows Installer 
   database. In order for the items to work properly, you must individually 
   re-install all items selected. Select OK to continue removing product,
   Cancel to abort.

If you click 'OK,' all the Windows Installer information that is associated with the selected programs is removed. This includes the entries for the programs in the Add/Remove Programs tool in Control Panel. If you remove the installation information for an installed program, the program is prevented from being able to add or remove components or to repair itself. NOTE: If you remove the installation information, files or shortcuts for the programs themselves are not removed. You should reinstall the programs before you try to use them.


WHAT IF I RECEIVE AN ERROR MESSAGE?
The following table lists the Windows Installer Clean Up Utility error messages that you may receive and the cause for each message.

   Error message:                            
      This utility requires that Msizap.exe version 2 or greater reside in the same folder.                                  
   Cause:
      Msizap.exe version 2 or a later version of Msizap.exe cannot be found in the same folder as Msicuu.exe.
   ---------------------------------------------------------------------------
   Error message:                            
      You must have Administrator rights to run this utility.              
   Cause:
      To run Msicuu.exe, you must be logged on with administrator rights.
   ---------------------------------------------------------------------------
   Error message:                            
      This utility requires that the Windows Installer be installed and properly registered.
   Cause:
      Msicuu.exe uses the Windows Installer object model to identify the installed products. 
      To correct the problem, try reregistering Msi.dll.


HOW DO I REMOVE THE WINDOWS INSTALLER CLEAN UP UTILITY?
When the Windows Installer Clean Up Utility is installed, an entry for the utility is created in the Add/Remove Programs tool in Control Panel. To remove the Windows Installer Clean Up Utility, click the entry in the list of installed programs, and then click 'Remove.'
