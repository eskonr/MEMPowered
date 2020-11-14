REM Copying SCCM Remote Control bits to Local Drive

XCOPY "SCCM Remote Control" "C:\Program Files (x86)\SCCM Remote Control" /s /i /y

REM Copy SCCM Remote control shortcut to All users start Menu

xcopy "%~dp0SCCM Remote Control\Remote Control.lnk" "C:\ProgramData\Microsoft\Windows\Start Menu\Programs" /Y