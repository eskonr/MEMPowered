Powershell script for downloading all of the Microsoft Ignite videos and PowerPoint slide decks.

Videos will become available as they are published. Some sessions don't have videos or slide decks available

---Parameters---
-director: The directory into which the videos are to be downloaded. If this is not set it will default to the folder in which the script is located.
-sessionCodes:  A comma separated list of session codes which can be used to filter the download for only specific sessions. There is no limit as to the number that may be specified.

---Notes---
* If a session does not have a slide desk or a video, no folder or associated metadata file will be created. That session will just be skipped.
* Leaving the -sessionCodes parameter blank will cause the script to download all session videos/slide decks where they exist.

To run the script, open a PowerShell window to the directory in which the script is located.
To download every thing run the following
.\Download-Resources.ps1


To download every thing into a given directory run the following
.\Download-Resources.ps1 "C:\Microsoft Ignite"

To download a set of sessions, supply the session code like this:
.\Download-Resources.ps1 -directory . -sessionCodes "KEY,TK01,TK02,BRK3016"
