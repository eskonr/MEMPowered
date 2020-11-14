using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace FrontendHelpdeskLauncher
{
    class Program
    {
        //Ensure input is non-malicious and run command
        private static void checkAndRunCommand(string ComputerName, string AppCommand, string appParams)
        {
            if (!Regex.Match(ComputerName, @"[0-9A-Za-z@._-]+").Success)
            {
                Console.WriteLine("ComputerName input is malformed.");
                return;
            }
        
            appParams = string.Format(appParams, ComputerName);
            Process.Start(AppCommand, appParams);
        }

        static void Main(string[] args)
        {
            string prefix = "cmfrontend://";

            // Verify input is in URI format.
            if (args.Length == 0 || !args[0].StartsWith(prefix))
            {
                Console.WriteLine("Syntax: " + prefix + "ApplicationName/ComputerName");
                return;
            }

            // Parse input, failing if data is missing.
            string appName = Regex.Match(args[0], @"(?<=://).+?(?=:|/|\Z)").Value;
            string computerName = Regex.Match(args[0], @"[^/]+(?=/$|$)").Value;
            if (string.IsNullOrWhiteSpace(appName) || string.IsNullOrWhiteSpace(computerName) || appName == computerName)
            {
                Console.WriteLine("Syntax: " + prefix + "ApplicationName/ComputerName");
                return;
            }

            // based on application name specified in input, run appropriate function.
            switch (appName.ToUpperInvariant())
            {
                case "REMOTEDESKTOP":
                    checkAndRunCommand(computerName, "mstsc.exe", "/v:{0}");
                    break;
                case "REMOTECONSOLE":
                    checkAndRunCommand(computerName, "powershell.exe", "-noExit -command Enter-PSSession -ComputerName {0}");
                    break;
                case "REMOTEASSISTANCE":
                    checkAndRunCommand(computerName, "msra.exe", "/offerra {0}");
                    break;
                case "REMOTECONTROL":
                    string cmConsolePath = Environment.GetEnvironmentVariable("SMS_ADMIN_UI_PATH");
                    string cmRemoteControlPath = cmConsolePath + "\\CmRcViewer.exe";
                    if (!string.IsNullOrWhiteSpace(cmConsolePath) && File.Exists(cmRemoteControlPath))
                        checkAndRunCommand(computerName, cmRemoteControlPath, "{0}");
                    break;
                case "SYSTEMINFO":
                    checkAndRunCommand(computerName, "msinfo32.exe", "/computer {0}");
                    break;
                case "COMPUTERMANAGER":
                    checkAndRunCommand(computerName, "mmc.exe", "compmgmt.msc /computer:\\\\{0}");
                    break;
                case "OPENLOGS":
                    checkAndRunCommand(computerName, "explorer.exe", "\\\\{0}\\admin$\\ccm\\logs");
                    break;
                default:
                    Console.WriteLine("Invalid ApplicationName.");
                    break;
            }
        }
    }
}
