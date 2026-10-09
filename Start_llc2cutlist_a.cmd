REM cmd zum Start des PowerShell-Skripts llc2cutlist
REM Das Aufrufbeispiel zeigt Optionen für automatische Verarbeitung
REM mit einer Default–Konfiguration cutlist.cfg neben dem Skript
D:
cd \Path\to\llc2cutlist
PowerShell -File .\llc2cutlist.ps1 -InputDirectory C:\Path\to\llcfiles -OriginalDirectory F:\Path\to\mp4files -MediaInfoPath C:\Path\to\MediaInfo.exe
pause
REM Optional kann hier die persönliche URL zu cutlist.at eingetragen und dann direkt aufgerufen werden.
REM Wenn das nicht gewünscht ist, die folgende Zeile auskommentieren.
start http://cutlist.at/<FRED>/profile
