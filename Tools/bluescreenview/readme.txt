


BlueScreenView v1.55
Copyright (c) 2009 - 2015 Nir Sofer
Web site: http://www.nirsoft.net



Description
===========

BlueScreenView scans all your minidump files created during 'blue screen
of death' crashes, and displays the information about all crashes in one
table. For each crash, BlueScreenView displays the minidump filename, the
date/time of the crash, the basic crash information displayed in the blue
screen (Bug Check Code and 4 parameters), and the details of the driver
or module that possibly caused the crash (filename, product name, file
description, and file version).
For each crash displayed in the upper pane, you can view the details of
the device drivers loaded during the crash in the lower pane.
BlueScreenView also mark the drivers that their addresses found in the
crash stack, so you can easily locate the suspected drivers that possibly
caused the crash.



Versions History
================


* Version 1.55:
  o Added Drag & Drop support: You can now drag a single MiniDump
    file from Explorer into the main window of BlueScreenView.
  o Fixed bug: BlueScreenView failed to remember the last
    size/position of the main window if it was not located in the primary
    monitor.

* Version 1.52:
  o Added 'Google Search - Bug Check' and 'Google Search - Bug Check
    + Parameter 1' options.

* Version 1.51:
  o Added automatic secondary sorting ('Crash Time' column).
  o Added 64-bit build.

* Version 1.50:
  o The 'Crash Time' now displays more accurate date/time of the
    crash. In previous versions, the value of 'Crash Time' column was
    taken from the date/time of dump file, which actually represents that
    time that Windows loaded again, after the crash. The actual crash
    time is stored inside the dump file , and now the 'Crash Time'
    displays this value.
  o Added 'Dump File Time' column, which displays the modified time
    of the dump file.

* Version 1.47:
  o Added 'Auto Size Columns+Headers' option, which allows you to
    automatically resize the columns according to the row values and
    column headers.

* Version 1.46:
  o Fixed issue: The properties and the 'Advanced Options' windows
    opened in the wrong monitor, on multi-monitors system.

* Version 1.45:
  o You can now choose to open only a specific dump file - from the
    user interface or from command-line.
  o You can now also specify the MiniDump folder or MiniDump file as
    a single parameter, and BlueScreenView will be opened with the right
    dump file/folder, for example: BlueScreenView.exe
    C:\windows\minidump\Mini011209-01.dmp

* Version 1.40:
  o Added 'Raw Data' mode on the lower pane, which displays the
    processor registers and memory hex dump.

* Version 1.35:
  o Added 'Crash Address' column.
  o Added 3 columns that display that last 3 calls found in the stack
    (Only for 32-bit crashes)

* Version 1.32:
  o Added 'Mark Odd/Even Rows' option, under the View menu. When it's
    turned on, the odd and even rows are displayed in different color, to
    make it easier to read a single line.

* Version 1.31:
  o Added 'Google Search - Bug Check+Driver' for searching in Google
    the driver name and bug check code of the selected blue screen.

* Version 1.30:
  o Added 'Dump File Size' column.

* Version 1.29:
  o You can now send the list of blue screen crashes to stdout by
    specifying an empty filename ("") in the command-line of all save
    parameters.
    For example: bluescreenview.exe /stab "" > c:\temp\blue_screens.txt

* Version 1.28:
  o Added 'Add Header Line To CSV/Tab-Delimited File' option. When
    this option is turned on, the column names are added as the first
    line when you export to csv or tab-delimited file.

* Version 1.27:
  o Fixed issue: removed the wrong encoding from the xml string,
    which caused problems to some xml viewers.

* Version 1.26:
  o Fixed 'DumpChk' mode to work properly when DumpChk processing
    takes more than a few seconds.

* Version 1.25:
  o Added 'DumpChk' mode, which displays the output of Microsoft
    DumpChk utility (DumpChk.exe). You can set the right path and
    parameters of DumpChk in 'Advanced Options' window. By default,
    BlueScreenView tries to run DumpChk from '%programfiles%\Debugging
    Tools for Windows'
  o The default MiniDump folder is now taken from
    HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\CrashControl

* Version 1.20:
  o Added 3 new columns in the upper pane: Processors Count, Major
    Version, Minor Version.
  o Added 'Explorer Copy' option, which allows you to copy dump files
    to the clipboard and then paste them into Explorer window.

* Version 1.15:
  o Added option to view the blue screen list of multiple computers
    on your network. The computer names are specified in a simple text
    file. (See below).
  o Added Combo-Box to easily choose the MiniDump folders available
    in the hard-disks currently attached to your computer.
  o Added 'Computer Name' and 'Full Path' columns.

* Version 1.11:
  o Added /sort command-line option.

* Version 1.10:
  o Added accelerator keys for allowing you to toggle between modes
    more easily.
  o Added command-line options for saving the crash dumps list to
    text/csv/html/xml file.
  o Added command-line option for opening BlueScreenView with the
    desired MiniDump folder.
  o Fixed focus problems when opening the 'Advanced Options' window.
  o Added 'default' button to the 'Advanced Options' window.
  o Added 'processor' column - 32-bit or x64.

* Version 1.05 - Added support for x64 MiniDump files.
* Version 1.00 - First release.



BlueScreenView Features
=======================


* Automatically scans your current minidump folder and displays the
  list of all crash dumps, including crash dump date/time and crash
  details.
* Allows you to view a blue screen which is very similar to the one
  that Windows displayed during the crash.
* BlueScreenView enumerates the memory addresses inside the stack of
  the crash, and find all drivers/modules that might be involved in the
  crash.
* BlueScreenView also allows you to work with another instance of
  Windows, simply by choosing the right minidump folder (In Advanced
  Options).
* BlueScreenView automatically locate the drivers appeared in the crash
  dump, and extract their version resource information, including product
  name, file version, company, and file description.



System Requirements
===================


* BlueScreenView works with Windows XP, Windows Server 2003, Windows
  Server 2008, Windows Vista, Windows 7, and Windows 8, as long as
  Windows is configured to save minidump files during BSOD crashes. If
  your system doesn't create MiniDump files on a blue screen crash, try
  to configure it according to the following article: How to configure
  Windows to create MiniDump files on BSOD
* BlueScreenView can read the MiniDump files of both 32-bit and x64
  systems.



Using BlueScreenView
====================

BlueScreenView doesn't require any installation process or additional dll
files. In order to start using it, simply run the executable file -
BlueScreenView.exe
After running BlueScreenView, it automatically scans your MiniDump folder
and display all crash details in the upper pane.



Crashes Information Columns (Upper Pane)
========================================


* Dump File: The MiniDump filename that stores the crash data.
* Crash Time: The created time of the MiniDump filename, which also
  matches to the date/time that the crash occurred.
* Bug Check String: The crash error string. This error string is
  determined according to the Bug Check Code, and it's also displayed in
  the blue screen window of Windows.
* Bug Check Code: The bug check code, as displayed in the blue screen
  window.
* Parameter 1/2/3/4: The 4 crash parameters that are also displayed in
  the blue screen of death.
* Caused By Driver: The driver that probably caused this crash.
  BlueScreenView tries to locate the right driver or module that caused
  the blue screen by looking inside the crash stack. However, be aware
  that the driver detection mechanism is not 100% accurate, and you
  should also look in the lower pane, that display all drivers/modules
  found in the stack. These drivers/modules are marked in pink color.
* Caused By Address: Similar to 'Caused By Driver' column, but also
  display the relative address of the crash.
* File Description: The file description of the driver that probably
  caused this crash. This information is loaded from the version resource
  of the driver.
* Product Name: The product name of the driver that probably caused
  this crash. This information is loaded from the version resource of the
  driver.
* Company: The company name of the driver that probably caused this
  crash. This information is loaded from the version resource of the
  driver.
* File Version: The file version of the driver that probably caused
  this crash. This information is loaded from the version resource of the
  driver.
* Crash Address:The memory address that the crash occurred. (The
  address in the EIP/RIP processor register) In some crashes, this value
  might be identical to 'Caused By Address' value, while in others, the
  crash address is different from the driver that caused the crash.
* Stack Address 1 - 3: The last 3 addresses found in the call stack. Be
  aware that in some crashes, these values will be empty. Also, the stack
  addresses list is currently not supported for 64-bit crashes.



Drivers Information Columns (Lower Pane)
========================================


* Filename: The driver/module filename
* Address In Stack: The memory address of this driver that was found in
  the stack.
* From Address: First memory address of this driver.
* To Address: Last memory address of this driver.
* Size: Driver size in memory.
* Time Stamp: Time stamp of this driver.
* Time String: Time stamp of this driver, displayed in date/time format.
* Product Name: Product name of this driver, loaded from the version
  resource of the driver.
* File Description: File description of this driver, loaded from the
  version resource of the driver.
* File Version: File version of this driver, loaded from the version
  resource of the driver.
* Company: Company name of this driver, loaded from the version
  resource of the driver.
* Full Path: Full path of the driver filename.



Lower Pane Modes
================

Currently, the lower pane has 4 different display modes. You can change
the display mode of the lower pane from Options->Lower Pane Mode menu.
1. All Drivers: Displays all the drivers that were loaded during the
   crash that you selected in the upper pane. The drivers/module that
   their memory addresses found in the stack, are marked in pink color.
2. Only Drivers Found In Stack: Displays only the modules/drivers that
   their memory addresses found in the stack of the crash. There is very
   high chance that one of the drivers in this list is the one that
   caused the crash.
3. Blue Screen in XP Style: Displays a blue screen that looks very
   similar to the one that Windows displayed during the crash.
4. DumpChk Output: Displays the output of Microsoft DumpChk utility.
   This mode only works when Microsoft DumpChk is installed on your
   computer and BlueScreenView is configured to run it from the right
   folder (In the Advanced Options window).
   You can get DumpChk from the installation CD/DVD of Windows or with
   the installtion of Debugging Tools for Windows.



Crashes of Remote Network Computer
==================================

If you have multiple computers on your network and you have full
administrator access to them (e.g: you have access to \\ComputerName\c$),
you can also view the crashes of the other computers on your network
remotely. In order to do that, simply go to 'Advanced Options' (Ctrl+O)
and type the MiniDump folder of the remote computer, for example:
\\MyComp\c$\Windows\MiniDump.

Notice: If you fail to get full administrator access to the remote
computer, you should read the instructions in the following Blog post:
How to connect a remote Windows 7/Vista/XP computer with NirSoft
utilities.



Watching the crashes of multiple computers on your network
==========================================================

If you have a network with multiple computers, and you have full admin
access to these computers, you can view the blue screens list of all
these computers in one table, and easily detect computers with recurring
BSOD problems.

In order to use this feature, prepare a list of all computer names/IP
addresses that you want to inspect, and save it to a simple text file.
The computer names in the list can be delimited by comma, semicolon, tab
character, or Enter (CRLF).
Example for computer names list:

comp01
comp02
192.168.0.1
192.168.0.2
192.168.0.4

After you have a text file contains the computers list, you can go to
Advanced Options window (Ctrl+O), choose the second option and type the
computers list filename.



Command-Line Options
====================



/LoadFrom <Source>
Specifies the source to load from.
1 -> Load from a single MiniDump folder (/MiniDumpFolder parameter)
2 -> Load from all computers specified in the computer list file.
(/ComputersFile parameter)
3 -> Load from a single MiniDump file (/SingleDumpFile parameter)

/MiniDumpFolder <Folder>
Start BlueScreenView with the specified MiniDump folder.

/SingleDumpFile <Filename>
Start BlueScreenView with the specified MiniDump file. (For using with
/LoadFrom 3)

/ComputersFile <Filename>
Specifies the computers list filename. (When LoadFrom = 2)

/LowerPaneMode <1 - 3>
Start BlueScreenView with the specified mode. 1 = All Drivers, 2 = Only
Drivers Found In Stack, 3 = Blue Screen in XP Style.

/stext <Filename>
Save the list of blue screen crashes into a regular text file.

/stab <Filename>
Save the list of blue screen crashes into a tab-delimited text file.

/scomma <Filename>
Save the list of blue screen crashes into a comma-delimited text file
(csv).

/stabular <Filename>
Save the list of blue screen crashes into a tabular text file.

/shtml <Filename>
Save the list of blue screen crashes into HTML file (Horizontal).

/sverhtml <Filename>
Save the list of blue screen crashes into HTML file (Vertical).

/sxml <Filename>
Save the list of blue screen crashes into XML file.

/sort <column>
This command-line option can be used with other save options for sorting
by the desired column. If you don't specify this option, the list is
sorted according to the last sort that you made from the user interface.
The <column> parameter can specify the column index (0 for the first
column, 1 for the second column, and so on) or the name of the column,
like "Bug Check Code" and "Crash Time". You can specify the '~' prefix
character (e.g: "~Crash Time") if you want to sort in descending order.
You can put multiple /sort in the command-line if you want to sort by
multiple columns.

Examples:
BlueScreenView.exe /shtml "f:\temp\crashes.html" /sort 2 /sort ~1
BlueScreenView.exe /shtml "f:\temp\crashes.html" /sort "Bug Check String"
/sort "~Crash Time"

/nosort
When you specify this command-line option, the list will be saved without
any sorting.



Translating BlueScreenView to other languages
=============================================

In order to translate BlueScreenView to other language, follow the
instructions below:
1. Run BlueScreenView with /savelangfile parameter:
   BlueScreenView.exe /savelangfile
   A file named BlueScreenView_lng.ini will be created in the folder of
   BlueScreenView utility.
2. Open the created language file in Notepad or in any other text
   editor.
3. Translate all string entries to the desired language. Optionally,
   you can also add your name and/or a link to your Web site.
   (TranslatorName and TranslatorURL values) If you add this information,
   it'll be used in the 'About' window.
4. After you finish the translation, Run BlueScreenView, and all
   translated strings will be loaded from the language file.
   If you want to run BlueScreenView without the translation, simply
   rename the language file, or move it to another folder.



License
=======

This utility is released as freeware. You are allowed to freely
distribute this utility via floppy disk, CD-ROM, Internet, or in any
other way, as long as you don't charge anything for this. If you
distribute this utility, you must include all files in the distribution
package, without any modification !



Disclaimer
==========

The software is provided "AS IS" without any warranty, either expressed
or implied, including, but not limited to, the implied warranties of
merchantability and fitness for a particular purpose. The author will not
be liable for any special, incidental, consequential or indirect damages
due to loss of data or any other reason.



Feedback
========

If you have any problem, suggestion, comment, or you found a bug in my
utility, you can send a message to nirsofer@yahoo.com
