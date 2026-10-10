

# llc2cutlist.ps1

Das Schnittprogramm "LosslessCut" ist gut zum verlustfreien und framegenauen Schneiden von Fernsehaufnahmen geeignet. Es kann dabei vorhandene Schnittlisten im cutlist-Format einlesen, aber noch keine solchen erzeugen. Beim Schneiden erzeugt es allerdings implizit Projektdateien mit den wesentlichen Informationen der erzeugten Schnitte.

Dieses Skript konvertiert unter Zuhilfenahme einer Konfigurationsdatei und einer cmd-Wrapper-Datei mit einem Klick alle in einem Verzeichnis vom Schnittprogramm LosslessCut erstellten *proj.llc Projektdateien in das cutlist-Format *.cutlist zum Hochladen bei cutlist.at . Die Konfigurationsdatei kann einerseits Standardwerte enthalten, die weitere Eingaben ersparen, andererseits auch zu Dialogeingaben auffordern, falls eine Cutlist mit speziellen Informationen versehen werden soll.

## OS

Windows

## Interface

CLI with options, config file

## Syntax
```
.\llc2cutlist.ps1
-InputDirectory C:\Path\to\llcfiles 
-OriginalDirectory F:\Path\to\mp4files 
[-MediaInfoPath C:\Path\to\MediaInfo.exe]
[-ConfigFile D:\Path\to\llc2cutlist\cutlist-manual.cfg]
[-Force]
```

## Voraussetzungen

Das PowerShell-Skript muss lokal ausgeführt werden dürfen. Gegebenenfalls muss eine geeignete Policy gesetzt werden.

LosslessCut zum Erzeugen von Projektdateien sollte vorhanden sein.

Das Vorhandensein resp. die Benutzung des mediainfo client (nicht der GUI-Version! Diese wird aktuell noch nicht unterstützt) ist optional zur korrekten Ermittlung der Bildrate (FPS) der Originaldatei. Eine Cutlist enthält die Schnittinformationen einerseits in Sekunden, andererseits in FPS. Mir ist allerdings aktuell kein Schnittprogramm bekannt, das nicht auch ausschließlich mit Werten in Sekunden arbeiten kann.

## Installation

Entpacke die zip-Datei an beliebiger Stelle.

Pflege die beigelegten Konfigurationsdateien nach deinen Wünschen. Die Datei "cutlist.cfg" sollte der Einfachheit halber neben dem PS1-Skript liegenbleiben. (Alle anderen Dateien können das auch, müssen es aber nicht.)

Pflege die beigelegten cmd-Dateien mit den lokal zu benutzenden Pfaden.

## Benutzung

Das Skript ist dazu gedacht, per Doppelklick auf eine den eigenen Gegebenheiten angepasste cmd-Datei ausgeführt zu werden. Es erwartet zum ersten einen Ordner mit *.llc-Projektdateien, die in *.cutlist-Dateien konvertiert werden sollen. Die ursprünglichen llc-Dateien bleiben dabei erhalten. Zum zweiten sollten zum Zeitpunkt der Konvertierung die Original-Aufnahmedateien noch zugreifbar sein, ebenfalls in einem anzugebenden Ordner. Grund: Eine Cutlist enthält zwingend die Größe der Originaldatei in Bytes. Es ist schwierig, wenn auch nicht unmöglich, diese Größeninformation ohne das Vorliegen der Originaldatei zu beschaffen.

Die zu erstellenden Cutlists lassen sich in zwei Fälle einteilen: Erstens und meistens ist neben den einmalig in die Standard-Konfigurationsdatei (per Default: cutlist.cfg neben der Skriptdatei) eingetragenen Werten keine weitere Angabe mehr erforderlich. Per cmd-Wrapper reicht dann ein einziger Doppelklick für die Konvertierung aller dieser llc-Dateien auf einmal aus. In einzelnen Fällen sind jedoch zusätzliche Informationen hilfreich, meist solche über Fehler in der Original-Aufnahme. Diese Aufnahmen bzw. deren llc-Dateien sollten in einem separaten Durchlauf mit der für interaktives Arbeiten gedachten cfg-Datei bearbeitet werden. Dazu wird das Skript mit dem dafür gedachten cmd-Wrapper aufgerufen, es fragt dann alle mit "?" gekennzeichneten cutlist-Parameter für jede llc-Datei einzeln ab. Dabei kann in der dafür vorgesehenen cfg-Datei prinzipiell jeder Parameter mit einem "?" versehen werden, alternativ mit einem Fragezeichen, gefolgt von runden Klammern mit einer Aufzählung oder einem Intervall der erlaubten Zahlenwerte.



