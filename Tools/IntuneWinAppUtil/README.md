# Microsoft Intune App Wrapping Tool for macOS
Manage macOS line-of-business apps with Intune

[Version 1.1](https://github.com/msintuneappsdk/intune-app-wrapping-tool-mac/releases/tag/v1.1)

[See release notes for more information.](https://github.com/msintuneappsdk/intune-app-wrapping-tool-mac/releases)

Use the Microsoft Intune App Wrapping Tool for macOS to pre-process macOS line-of-business apps. The wrapping tool converts application installation files into the .intunemac format. The wrapping tool also detects the parameters required by the mobile device management (MDM) agent to determine the application installation state. After you use this tool on your apps, you will be able to upload and assign the apps in the Microsoft Intune console. 

Before you install and the use Microsoft Intune App Wrapping Tool for macOS you **must**:
* Review the [Microsoft License Terms for Microsoft Intune App Wrapping Tool for macOS](https://github.com/msintuneappsdk/intune-app-wrapping-tool-mac/blob/master/LicenseTerms/Microsoft%20Software%20License%20Terms%20Intune%20App%20Wrapping%20Tool%20for%20macOS%20-%20English.pdf). Print and retain a copy of the license terms for your records. By downloading and using Microsoft Intune App Wrapping Tool for macOS, you agree to such license terms. If you do not accept them, do not use the software.
* Review the [Microsoft Intune Privacy Statement](https://docs.microsoft.com/legal/intune/microsoft-intune-privacy-statement) for information on the privacy policy of the Intune App Wrapping Tool for macOS.

Sample commands to use for the Microsoft Intune App Wrapping Tool for macOS:
* IntuneAppUtil -h
  * This will show usage information for the tool.

* IntuneAppUtil -c <source_file> -o <output_file> [-i] <package bundle Id> [-n] <package bundle version> [-v]
  * This will generate the .intunemac file from the .pkg line-of-business app file.

* IntuneAppUtil -r <filename.intunemac> [-v]
  * This will extract the detected parameters and version for the created .intunemac file.

Command-line parameters available
* -h  Help
* -r  Outputs the detection.xml file of the provided .intunemac file to stdout. The output contains the detection parameters and version of IntuneAppUtil used to create the .intunemac file.
* -c  <source_file>
    Converts the provided input filename. Only pkg file is supported.
* -o  <output_file>    Used in conjunction with -c parameter to specify the output path
* -v  Verbose: Produces additional progress output and error diagnostics.
* -i  <package bundle Id>
    Used in conjunction with -c parameter to specify the package bundle Id. Optional.
* -n  <package bundle version>
    Used in conjunction with -c parameter to specify the package bnndle version. Optional.

If no valid application information can be found, this tool will use package bundle Id and package bundle version to build app detection data. You can use "-i" and "-n" parameters to override them.

Note: After you download IntuneAppUtil to your Mac device, you may need to assign read and execute permission to it.
