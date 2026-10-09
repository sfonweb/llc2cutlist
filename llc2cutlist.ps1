<#
.SYNOPSIS
    Konvertiert LosslessCut-Projektdateien (*.llc) in cutlist-Dateien (*.cutlist).

    Converts LosslessCut project files (*.llc) into cutlist files (*.cutlist).

    Version: 04.10.2026

.DESCRIPTION
    English text follows

    Dieses Skript verarbeitet alle *.llc-Dateien in einem angegebenen
    Verzeichnis und erzeugt daraus Dateien mit der Endung .cutlist.

    Die Struktur der erzeugten cutlist-Datei wird aus einer CFG-Datei
    übernommen. Werte in der CFG werden folgendermaßen behandelt:

      Wert vorhanden  -> Wert wird übernommen
      Wert leer       -> Parameter bleibt leer
      Wert "?"        -> Wert wird für diese LLC-Datei interaktiv abgefragt
      Wert "?(0|1)"   -> Wert wird abgefragt, darf nur 0 oder 1 sein
      Wert "?(0-5)"   -> Wert wird abgefragt, darf von 0 bis 5 reichen

    Die CFG wird für jede LLC-Datei erneut ausgewertet. Damit können
    unterschiedliche CFG-Dateien für unterschiedliche Anwendungsfälle
    verwendet werden.

    Die Frame Rate (FPS) kann optional automatisch aus der zugehörigen
    Original-Filmdatei über MediaInfo ermittelt werden.

    FPS-Priorität:

      1. FPS der Originaldatei über MediaInfo
      2. FramesPerSecond aus der CFG
      3. 25 FPS

    Standardmäßig wird cutlist.cfg im Verzeichnis dieses Skripts gesucht.
    Über -ConfigFile kann eine beliebige CFG-Datei angegeben werden.

    Bereits vorhandene .cutlist-Dateien werden standardmäßig NICHT
    überschrieben. Mit -Force ist ein Überschreiben möglich.

    Dieses Skript wurde unter Zuhilfenahme von KI erstellt.	


    English version:
    This script processes all *.llc files in a specified
    directory and generates files with the .cutlist extension from them.
    The structure of the generated cutlist file is derived from a CFG file.

    Values in the CFG are handled as follows:

      Value present    -> Value is adopted
      Value empty      -> Parameter remains empty
      Value “?”        -> Value is requested interactively for this LLC file
      Value “?(0|1)”   -> Value is requested; must be either 0 or 1
      Value “?(0-5)”   -> Value is prompted; must be between 0 and 5

    The CFG file is re-evaluated for each LLC file. This allows
    different CFG files to be used for different use cases.

    Optionally, the FPS can be automatically determined from the corresponding
    original movie file using MediaInfo.

    FPS determination priority:

      1. FPS of the original file via MediaInfo
      2. FramesPerSecond from the CFG
      3. 25 FPS

    By default, cutlist.cfg is searched for in the directory of this script.
    Any CFG file can be specified using -ConfigFile.

    Existing .cutlist files are NOT overwritten by default.
    Overwriting is possible with the -Force option.

    This script was created with the help of AI.


.PARAMETER InputDirectory
    Verzeichnis mit den LosslessCut-*.llc-Dateien.

.PARAMETER OriginalDirectory
    Verzeichnis mit den Original-Filmdateien.

    Wird eine Datei mit dem in der LLC angegebenen mediaFileName gefunden,
    wird deren Dateigröße als OriginalFileSizeBytes in [General] eingetragen.
    Diese Angabe ist in einer .cutlist zwingend erforderlich.

    Die Suche erfolgt auch in Unterverzeichnissen.
	
    Wenn MediaInfo vorhanden ist, wird aus dieser
    Datei zusätzlich die FPS über MediaInfo ausgelesen.

.PARAMETER ConfigFile
    Optionaler Pfad zur zu verwendenden CFG-Datei.

    Ohne Angabe wird "cutlist.cfg" im Verzeichnis dieses Skripts verwendet.

.PARAMETER MediaInfoPath
    Optionaler Pfad zu mediainfo.exe.

    Ohne Angabe wird zuerst nach "mediainfo.exe" im PATH gesucht.

    Beispiel:
        -MediaInfoPath "C:\Program Files\MediaInfo\MediaInfo.exe"

.PARAMETER Force
    Bereits vorhandene .cutlist-Dateien überschreiben.

.EXAMPLE
    .\llc2cutlist.ps1 `
        -InputDirectory "D:\LosslessCut\Projekte" `
        -OriginalDirectory "D:\Filme"

.EXAMPLE
    .\llc2cutlist.ps1 `
        -InputDirectory "D:\LosslessCut\Projekte" `
        -OriginalDirectory "D:\Filme" `
        -ConfigFile "D:\Configs\cutlist-standard.cfg"

.EXAMPLE
    .\llc2cutlist.ps1 `
        -InputDirectory "D:\LosslessCut\Projekte" `
        -OriginalDirectory "D:\Filme" `
        -ConfigFile "D:\Configs\cutlist-standard.cfg"

.EXAMPLE
    .\llc2cutlist.ps1 `
        -InputDirectory "D:\LosslessCut\Projekte" `
        -OriginalDirectory "D:\Filme_fehlerhaft" `
        -ConfigFile "D:\Configs\cutlist-manual.cfg" `
        -Force
		
.EXAMPLE
    .\Convert-LlcToCutlist.ps1 `
        -InputDirectory "D:\LosslessCut\Projekte" `
        -OriginalDirectory "D:\Filme" `
        -MediaInfoPath "C:\Program Files\MediaInfo\MediaInfo.exe"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$InputDirectory,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [string]$OriginalDirectory,

    [Parameter(Mandatory = $false)]
    [string]$ConfigFile,

    [Parameter(Mandatory = $false)]
    [string]$MediaInfoPath,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'


# ===========================================================================
# Hilfsfunktionen
# ===========================================================================

function Get-DefaultScriptDirectory {
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        return $PSScriptRoot
    }

    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        return (Split-Path -Parent $PSCommandPath)
    }

    return (Get-Location).Path
}


function Get-ConfigFilePath {
    param(
        [string]$ConfiguredPath
    )

    # Explizit angegebene CFG-Datei
    if (-not [string]::IsNullOrWhiteSpace($ConfiguredPath)) {

        if (-not (Test-Path -LiteralPath $ConfiguredPath -PathType Leaf)) {
            throw "Die angegebene CFG-Datei wurde nicht gefunden: $ConfiguredPath"
        }

        return (Resolve-Path -LiteralPath $ConfiguredPath).Path
    }

    # Standard: cutlist.cfg neben dem Skript
    $defaultPath = Join-Path `
        (Get-DefaultScriptDirectory) `
        'cutlist.cfg'

    if (-not (Test-Path -LiteralPath $defaultPath -PathType Leaf)) {
        throw @"
Keine CFG-Datei angegeben und keine Standarddatei gefunden.

Gesucht wurde:
$defaultPath

Verwende entweder eine cutlist.cfg neben dem Skript oder
gib mit -ConfigFile eine CFG-Datei an.
"@
    }

    return (Resolve-Path -LiteralPath $defaultPath).Path
}


function Parse-IniFile {
    <#
        Liest eine einfache INI-Datei.
        Unterstützt beispielsweise:

        [General]
        Application=LosslessCut
        Version=3.69.0
        FramesPerSecond=25

        Auch Werte wie

        Parameter="Wert"

        werden unterstützt. Die äußeren Anführungszeichen werden entfernt.
        Die Reihenfolge der Sektionen und Parameter wird erhalten.
    #>

    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $result = [ordered]@{}
    $currentSection = $null

    $lineNumber = 0

    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {

        $lineNumber++

        $trimmed = $line.Trim()

        # Leere Zeile
        if ($trimmed.Length -eq 0) {
            continue
        }

        # Kommentar
        if ($trimmed.StartsWith(';') -or $trimmed.StartsWith('#')) {
            continue
        }

        # Sektion
        if ($trimmed -match '^\[(.+)\]$') {

            $currentSection = $Matches[1].Trim()

            if ($currentSection.Length -eq 0) {
                throw "Leere Sektion in $Path, Zeile $lineNumber."
            }

            if (-not $result.Contains($currentSection)) {
                $result[$currentSection] = [ordered]@{}
            }

            continue
        }

        # Parameter=Value
        if ($trimmed -match '^([^=]+)=(.*)$') {

            if ($null -eq $currentSection) {
                throw @"
Parameter ausserhalb einer Sektion in $Path, Zeile ${lineNumber} :

$line
"@
            }

            $name  = $Matches[1].Trim()
            $value = $Matches[2].Trim()

            # Äußere Anführungszeichen entfernen
            if ($value.Length -ge 2) {

                if (
                    ($value.StartsWith('"') -and $value.EndsWith('"')) -or
                    ($value.StartsWith("'") -and $value.EndsWith("'"))
                ) {
                    $value = $value.Substring(1, $value.Length - 2)
                }
            }

            $result[$currentSection][$name] = $value

            continue
        }

        throw @"
Ungueltige Zeile in $Path, Zeile ${lineNumber} :

$line
"@
    }

    return $result
}


function Get-InteractiveConfigValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Section,

        [Parameter(Mandatory = $true)]
        [string]$Parameter,

        [string]$Constraint
    )

    # Keine Einschränkung: normale Eingabe
    if ([string]::IsNullOrEmpty($Constraint)) {
        $prompt = "Wert fuer [$Section] $Parameter eingeben"
        return Read-Host $prompt
    }

    # Wertebereich: z.B. 0-5
    if ($Constraint -match '^(\d+)\s*-\s*(\d+)$') {

    $min = [int]$matches[1]
    $max = [int]$matches[2]

        while ($true) {

            $prompt = "Wert fuer [$Section] $Parameter von $($matches[1]) bis $($matches[2]) eingeben"
            $inputValue = Read-Host $prompt

            $number = 0

            if (
                [int]::TryParse(
                    $inputValue,
                    [ref]$number
                )
            ) {
                if ($number -ge $min -and $number -le $max) {
                    return $inputValue
                }
            }

            Write-Host "Ungueltiger Wert. Bitte einen Wert von $($matches[1]) bis $($matches[2]) eingeben."
        }
    }

    # Auswahlliste: z.B. 0|1
    $allowedValues = $Constraint -split '\|'

    while ($true) {

        $prompt = "Wert fuer [$Section] $Parameter $($allowedValues -join ' oder ') eingeben"
        $inputValue = Read-Host $prompt

        if ($allowedValues -contains $inputValue) {
            return $inputValue
        }

        Write-Host "Ungueltiger Wert. Erlaubt sind: $($allowedValues -join ', ')"
    }
}


function Resolve-ConfigValues {
    <#
        Erstellt eine Kopie der CFG.

        Wichtig:
        Die Auflösung erfolgt für JEDE LLC-Datei erneut.
        Ein ? wird daher für jede Datei erneut abgefragt.

        Unterstützte Eingabesyntax:
            ?           Freie Eingabe
            ?(0-5)      Wertebereich
            ?(0|1)      Auswahlliste
    #>

    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config
    )

    $resolved = [ordered]@{}

    foreach ($sectionName in $Config.Keys) {

        $resolved[$sectionName] = [ordered]@{}

        foreach ($parameterName in $Config[$sectionName].Keys) {

            $value = [string]$Config[$sectionName][$parameterName]

            # Freie interaktive Eingabe
            if ($value -eq '?') {

                $value = Get-InteractiveConfigValue `
                    -Section $sectionName `
                    -Parameter $parameterName
            }

            # Interaktive Eingabe mit Einschränkung:
            # ?(...) 
            elseif ($value -match '^\?\((.*)\)$') {

                $constraint = $matches[1]

                $value = Get-InteractiveConfigValue `
                    -Section $sectionName `
                    -Parameter $parameterName `
                    -Constraint $constraint
            }

            # Leer bleibt leer.
            $resolved[$sectionName][$parameterName] = $value
        }
    }

    return $resolved
}


function Get-ConfigFramesPerSecond {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config
    )

    # Vorgabe laut Spezifikation
    $defaultFps = 25.0

    if (-not $Config.Contains('General')) {
        return $defaultFps
    }

    if (-not $Config['General'].Contains('FramesPerSecond')) {
        return $defaultFps
    }

    $candidate = [string]$Config['General']['FramesPerSecond']

    if ([string]::IsNullOrWhiteSpace($candidate)) {
        return $defaultFps
    }

    if ($candidate -eq '?') {
        $candidate = Get-InteractiveConfigValue `
            -Section 'General' `
            -Parameter 'FramesPerSecond'
    }

    $parsed = 0.0

    $success = [double]::TryParse(
        $candidate,
        [System.Globalization.NumberStyles]::Float,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref]$parsed
    )

    if ($success -and $parsed -gt 0) {
        return $parsed
    }

    Write-Warning @"
Ungueltiger Wert fuer FramesPerSecond in der CFG:
"$candidate"

Es wird der Standardwert 25 verwendet.
"@

    return $defaultFps
}

function Resolve-MediaInfoPath {
    param(
        [string]$ConfiguredPath
    )

    if (-not [string]::IsNullOrWhiteSpace($ConfiguredPath)) {

        if (-not (Test-Path -LiteralPath $ConfiguredPath -PathType Leaf)) {
            throw "Die angegebene MediaInfo-Datei wurde nicht gefunden: $ConfiguredPath"
        }

        return (Resolve-Path -LiteralPath $ConfiguredPath).Path
    }

    $command = Get-Command 'mediainfo.exe' -ErrorAction SilentlyContinue

    if ($null -eq $command) {
        $command = Get-Command 'mediainfo' -ErrorAction SilentlyContinue
    }

    if ($null -eq $command) {
        return $null
    }

    return $command.Source
}


function Get-MediaInfoFrameRate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MediaInfoExecutable,

        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    if ([string]::IsNullOrWhiteSpace($MediaInfoExecutable)) {
        return $null
    }

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        return $null
    }

    try {

        # Ausgabe:
        # FrameRate|FrameRate_Mode
        #
        # Beispiel:
        # 25.000|Constant
        # 25.000|Variable

        $result = & $MediaInfoExecutable `
            '--Inform=Video;%FrameRate%|%FrameRate_Mode%' `
            $FilePath 2>$null

        if ($LASTEXITCODE -ne 0) {
            return $null
        }

        $line = ($result | Select-Object -First 1)

        if ($null -eq $line) {
            return $null
        }

        $line = [string]$line

        if ([string]::IsNullOrWhiteSpace($line)) {
            return $null
        }

        $parts = $line.Split('|', 2)

        $fpsText = $parts[0].Trim()

        if ([string]::IsNullOrWhiteSpace($fpsText)) {
            return $null
        }

        # MediaInfo verwendet normalerweise Punkt als Dezimaltrennzeichen.
        # Zur Sicherheit wird zusätzlich ein Komma akzeptiert.
        $fpsTextInvariant = $fpsText.Replace(',', '.')

        $fps = 0.0

        $success = [double]::TryParse(
            $fpsTextInvariant,
            [System.Globalization.NumberStyles]::Float,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref]$fps
        )

        if (-not $success -or $fps -le 0) {
            return $null
        }

        $frameRateMode = ''

        if ($parts.Count -gt 1) {
            $frameRateMode = $parts[1].Trim()
        }

        return [PSCustomObject]@{
            FrameRate     = $fps
            FrameRateMode = $frameRateMode
        }
    }
    catch {
        return $null
    }
}

function Parse-LlcFile {
    <#
        Liest die von LosslessCut erzeugte JavaScript-ähnliche LLC-Datei.

        Beispiel:

        {
          version: 2,
          mediaFileName: 'film.mp4',
          cutSegments: [
            {
              start: 1164.28,
              end: 2620.64,
              name: 'Cut 0',
              selected: true,
            },
            ...
          ],
        }
    #>

    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $content = Get-Content `
        -LiteralPath $Path `
        -Raw `
        -Encoding UTF8

    # -----------------------------------------------------------------------
    # mediaFileName
    # -----------------------------------------------------------------------

    $mediaMatch = [regex]::Match(
        $content,
        "(?m)^\s*mediaFileName\s*:\s*(['""])(.*?)\1\s*,?\s*$"
    )

    if (-not $mediaMatch.Success) {
        throw "Keine mediaFileName-Angabe gefunden."
    }

    $mediaFileName = $mediaMatch.Groups[2].Value

    if ([string]::IsNullOrWhiteSpace($mediaFileName)) {
        throw "mediaFileName ist leer."
    }

    # -----------------------------------------------------------------------
    # cutSegments
    # -----------------------------------------------------------------------

    $segmentsMatch = [regex]::Match(
        $content,
        '(?s)cutSegments\s*:\s*\[(.*?)\]'
    )

    if (-not $segmentsMatch.Success) {
        throw "Kein cutSegments-Block gefunden."
    }

    $segmentsText = $segmentsMatch.Groups[1].Value

    # -----------------------------------------------------------------------
    # einzelne Segmente
    # -----------------------------------------------------------------------

    $segmentMatches = [regex]::Matches(
        $segmentsText,
        '(?s)\{\s*(.*?)\s*\}'
    )

    $segments = @()

    foreach ($segmentMatch in $segmentMatches) {

        $segmentText = $segmentMatch.Groups[1].Value

        $startMatch = [regex]::Match(
            $segmentText,
            '(?m)^\s*start\s*:\s*([-+]?(?:\d+(?:\.\d*)?|\.\d+))\s*,?\s*$'
        )

        $endMatch = [regex]::Match(
            $segmentText,
            '(?m)^\s*end\s*:\s*([-+]?(?:\d+(?:\.\d*)?|\.\d+))\s*,?\s*$'
        )

        if (-not $startMatch.Success -or -not $endMatch.Success) {
            continue
        }

        $start = [double]::Parse(
            $startMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )

        $end = [double]::Parse(
            $endMatch.Groups[1].Value,
            [System.Globalization.CultureInfo]::InvariantCulture
        )

        if ($start -lt 0) {
            throw "Ein Segment besitzt einen negativen Startwert: $start"
        }

        if ($end -lt $start) {
            throw "Segment-Ende ($end) liegt vor dem Segment-Start ($start)."
        }

        $segments += [PSCustomObject]@{
            Start = $start
            End   = $end
        }
    }

    if ($segments.Count -eq 0) {
        throw "Keine gueltigen Schnittsegmente gefunden."
    }

    return [PSCustomObject]@{
        MediaFileName = $mediaFileName
        Segments      = $segments
    }
}


function Format-Number {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Value
    )

    return $Value.ToString(
        '0.###############',
        [System.Globalization.CultureInfo]::InvariantCulture
    )
}


function Format-Integer {
    param(
        [Parameter(Mandatory = $true)]
        [long]$Value
    )

    return $Value.ToString(
        [System.Globalization.CultureInfo]::InvariantCulture
    )
}


function Find-OriginalFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory,

        [Parameter(Mandatory = $true)]
        [string]$FileName
    )

    if ([string]::IsNullOrWhiteSpace($Directory)) {
        return $null
    }

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        Write-Warning "OriginalDirectory existiert nicht: $Directory"
        return $null
    }

    # Zuerst direkt im angegebenen Verzeichnis suchen.
    $exactPath = Join-Path $Directory $FileName

    if (Test-Path -LiteralPath $exactPath -PathType Leaf) {
        return Get-Item -LiteralPath $exactPath
    }

    # Danach rekursiv suchen.
    return Get-ChildItem `
        -LiteralPath $Directory `
        -File `
        -Recurse `
        -Filter $FileName `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1
}


function Set-OrAdd-GeneralValue {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$General,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    if ($General.Contains($Name)) {
        $General[$Name] = $Value
    }
    else {
        $General[$Name] = $Value
    }
}


function Resolve-FpsForFile {
    param(
        [Parameter(Mandatory = $false)]
        [System.IO.FileInfo]$OriginalFile,

        [Parameter(Mandatory = $false)]
        [string]$MediaInfoExecutable,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config
    )

    $configFps = Get-ConfigFramesPerSecond -Config $Config

    if ($null -ne $OriginalFile) {

        if ([string]::IsNullOrWhiteSpace($MediaInfoExecutable)) {

            Write-Warning @"
MediaInfo wurde nicht gefunden.

Die FPS der Originaldatei kann deshalb nicht ausgelesen werden.
"@
        }
        else {

            $mediaInfo = Get-MediaInfoFrameRate `
                -MediaInfoExecutable $MediaInfoExecutable `
                -FilePath $OriginalFile.FullName

            if ($null -ne $mediaInfo) {

                if (
                    -not [string]::IsNullOrWhiteSpace($mediaInfo.FrameRateMode) -and
                    $mediaInfo.FrameRateMode -match '(?i)variable'
                ) {
                    Write-Warning @"
Die Originaldatei besitzt laut MediaInfo eine variable Framerate (VFR).

Verwendeter MediaInfo-FrameRate-Wert:
$($mediaInfo.FrameRate) FPS

Die Frameberechnung basiert damit auf diesem von MediaInfo gemeldeten
Framerate-Wert.
"@
                }

                return [PSCustomObject]@{
                    FramesPerSecond = [double]$mediaInfo.FrameRate
                    Source          = 'Originaldatei / MediaInfo'
                    FrameRateMode   = $mediaInfo.FrameRateMode
                }
            }

            Write-Warning @"
MediaInfo konnte keine gültige FPS aus der Originaldatei ermitteln:

$($OriginalFile.FullName)
"@
        }
    }

    if ($null -ne $configFps) {

        return [PSCustomObject]@{
            FramesPerSecond = [double]$configFps
            Source          = 'CFG'
            FrameRateMode   = ''
        }
    }

    return [PSCustomObject]@{
        FramesPerSecond = 25.0
        Source          = 'Standardwert 25 FPS'
        FrameRateMode   = ''
    }
}


function Convert-ToCutlist {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LlcPath,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [Parameter(Mandatory = $true)]
        [string]$OriginalDirectory,

        [Parameter(Mandatory = $false)]
        [string]$MediaInfoExecutable,

        [Parameter(Mandatory = $true)]
        [bool]$Force
    )

    Write-Host ""
    Write-Host "------------------------------------------------------------"
    Write-Host "Verarbeite: $(Split-Path -Leaf $LlcPath)" -ForegroundColor Cyan

    # -----------------------------------------------------------------------
    # LLC einlesen
    # -----------------------------------------------------------------------

    $llc = Parse-LlcFile -Path $LlcPath

    $mediaFileName = $llc.MediaFileName
    $segments      = $llc.Segments

    # -----------------------------------------------------------------------
    # Zielpfad
    # -----------------------------------------------------------------------

    $outputDirectory = Split-Path -Parent $LlcPath

    $outputPath = Join-Path `
        $outputDirectory `
        ($mediaFileName + '.cutlist')

    # -----------------------------------------------------------------------
    # Vorhandene Datei schützen
    # -----------------------------------------------------------------------

    if (Test-Path -LiteralPath $outputPath -PathType Leaf) {

        if (-not $Force) {

            Write-Warning @"
Die Zieldatei existiert bereits und wird NICHT ueberschrieben:

$outputPath

Verwende -Force, wenn sie ueberschrieben werden soll.
"@

            return $false
        }

        Write-Host "Vorhandene cutlist wird wegen -Force ueberschrieben." `
            -ForegroundColor Yellow
    }

    # -----------------------------------------------------------------------
    # CFG für DIESE LLC-Datei auflösen
    # -----------------------------------------------------------------------

    # Hier werden die ?-Werte abgefragt.
    # Dieser Aufruf erfolgt bewusst für jede einzelne LLC-Datei.
    $resolvedConfig = Resolve-ConfigValues -Config $Config

    # -----------------------------------------------------------------------
    # General-Sektion sicherstellen
    # -----------------------------------------------------------------------

    if (-not $resolvedConfig.Contains('General')) {
        $resolvedConfig['General'] = [ordered]@{}
    }

    $general = $resolvedConfig['General']

    # -----------------------------------------------------------------------
    # OriginalFileSizeBytes
    # -----------------------------------------------------------------------

    if (-not [string]::IsNullOrWhiteSpace($OriginalDirectory)) {

        $originalFile = Find-OriginalFile `
            -Directory $OriginalDirectory `
            -FileName $mediaFileName

        if ($null -ne $originalFile) {

            Set-OrAdd-GeneralValue `
                -General $general `
                -Name 'OriginalFileSizeBytes' `
                -Value ([string]$originalFile.Length)

            Write-Host "Originaldatei gefunden:" -ForegroundColor Green
            Write-Host "  $($originalFile.FullName)"
            Write-Host "  Groesse: $($originalFile.Length) Bytes"
        }
        else {

            Write-Warning @"
Originaldatei nicht gefunden: $mediaFileName
Die Groesse der Originaldatei in Bytes ist zwingend erforderlich
und kann hier nicht ermittelt werden.
Der Wert kann ggf. nachtraeglich in die Cutlist eingetragen werden,
ansonsten wird die Cutlist beim Hochladen abgewiesen.
"@

            # Der Parameter wird trotzdem erzeugt, wenn er in der CFG
            # vorhanden war bzw. für die Ausgabe benötigt wird.
            Set-OrAdd-GeneralValue `
                -General $general `
                -Name 'OriginalFileSizeBytes' `
                -Value ''
        }
    }
    elseif ($general.Contains('OriginalFileSizeBytes')) {

        # Kein OriginalDirectory angegeben.
        $general['OriginalFileSizeBytes'] = ''
    }

    # -----------------------------------------------------------------------
    # FPS bestimmen
    # -----------------------------------------------------------------------

    $fpsInfo = Resolve-FpsForFile `
        -OriginalFile $originalFile `
        -MediaInfoExecutable $MediaInfoExecutable `
        -Config $resolvedConfig

    $framesPerSecond = $fpsInfo.FramesPerSecond

    Set-OrAdd-GeneralValue `
        -General $general `
        -Name 'FramesPerSecond' `
        -Value (Format-Number $framesPerSecond)

    Write-Host "FramesPerSecond: $framesPerSecond" -ForegroundColor Cyan

    if (-not [string]::IsNullOrWhiteSpace($fpsInfo.FrameRateMode)) {
        Write-Host "FrameRate-Modus: $($fpsInfo.FrameRateMode)" -ForegroundColor Cyan
    }

    # -----------------------------------------------------------------------
    # Allgemeine Werte der General Section
    # -----------------------------------------------------------------------

    Set-OrAdd-GeneralValue `
        -General $general `
        -Name 'NoOfCuts' `
        -Value ([string]$segments.Count)

    Set-OrAdd-GeneralValue `
        -General $general `
        -Name 'ApplyToFile' `
        -Value $mediaFileName

    # -----------------------------------------------------------------------
    # Vorhandene Cut-Sektionen aus der temporaeren CFG entfernen
    # -----------------------------------------------------------------------

    # Cut0, Cut1, ... sind dynamische Daten aus der LLC und werden immer
    # neu erzeugt.
    $sectionsToRemove = @(
        @($resolvedConfig.Keys) |
        Where-Object {
            $_ -match '^Cut\d+$'
        }
    )

    foreach ($sectionName in $sectionsToRemove) {
        $resolvedConfig.Remove($sectionName)
    }

    # -----------------------------------------------------------------------
    # Cut-Sektionen erzeugen
    # -----------------------------------------------------------------------

    $cutSections = [ordered]@{}

    for ($i = 0; $i -lt $segments.Count; $i++) {

        $segment = $segments[$i]

        $start    = $segment.Start
        $duration = $segment.End - $segment.Start

        # Rundung auf ganze Frames.
        #
        # Beispiel:
        # 1164.28 * 25 = 29107
        # 1456.36 * 25 = 36409
        #
        $startFrame = [long][Math]::Round(
            $start * $FramesPerSecond,
            [MidpointRounding]::AwayFromZero
        )

        $durationFrames = [long][Math]::Round(
            $duration * $FramesPerSecond,
            [MidpointRounding]::AwayFromZero
        )

        $sectionName = "Cut$i"

        $cutSections[$sectionName] = [ordered]@{
            Start          = Format-Number $start
            StartFrame     = Format-Integer $startFrame
            Duration       = Format-Number $duration
            DurationFrames = Format-Integer $durationFrames
        }
    }

    # -----------------------------------------------------------------------
    # Ausgabe-Reihenfolge herstellen
    # -----------------------------------------------------------------------

    $orderedOutput = [ordered]@{}

    # General zuerst
    $orderedOutput['General'] = $general

    # Danach Cut0 ... CutN
    foreach ($cutSectionName in $cutSections.Keys) {
        $orderedOutput[$cutSectionName] = $cutSections[$cutSectionName]
    }

    # Danach alle übrigen CFG-Sektionen.
    foreach ($sectionName in $resolvedConfig.Keys) {

        if ($sectionName -eq 'General') {
            continue
        }

        if ($sectionName -match '^Cut\d+$') {
            continue
        }

        $orderedOutput[$sectionName] = $resolvedConfig[$sectionName]
    }

    # -----------------------------------------------------------------------
    # cutlist-Datei erzeugen
    # -----------------------------------------------------------------------

    $output = [System.Text.StringBuilder]::new()

    foreach ($sectionName in $orderedOutput.Keys) {

        [void]$output.AppendLine("[$sectionName]")

        foreach ($parameterName in $orderedOutput[$sectionName].Keys) {

            $value = [string]$orderedOutput[$sectionName][$parameterName]

            [void]$output.AppendLine(
                "$parameterName=$value"
            )
        }

        [void]$output.AppendLine()
    }

    # -----------------------------------------------------------------------
    # UTF-8 ohne BOM schreiben
    # -----------------------------------------------------------------------

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

    [System.IO.File]::WriteAllText(
        $outputPath,
        $output.ToString(),
        $utf8NoBom
    )

    Write-Host ""
    Write-Host "Erzeugt:" -ForegroundColor Green
    Write-Host "  $outputPath"
    Write-Host "  Schnitte: $($segments.Count)"
    Write-Host "  FPS: $FramesPerSecond"

    return $true
}


# ===========================================================================
# Hauptprogramm
# ===========================================================================

try {

    # -----------------------------------------------------------------------
    # InputDirectory prüfen
    # -----------------------------------------------------------------------

    if (-not (Test-Path -LiteralPath $InputDirectory -PathType Container)) {
        throw "Das Eingabeverzeichnis wurde nicht gefunden: $InputDirectory"
    }

    $inputDirectoryResolved =
        (Resolve-Path -LiteralPath $InputDirectory).Path

    # -----------------------------------------------------------------------
    # OriginalDirectory prüfen
    # -----------------------------------------------------------------------

    if (-not [string]::IsNullOrWhiteSpace($OriginalDirectory)) {

        if (-not (Test-Path `
            -LiteralPath $OriginalDirectory `
            -PathType Container)) {

            throw @"
Das angegebene OriginalDirectory wurde nicht gefunden:

$OriginalDirectory
"@
        }

        $OriginalDirectory =
            (Resolve-Path -LiteralPath $OriginalDirectory).Path
    }

    # -----------------------------------------------------------------------
    # CFG bestimmen
    # -----------------------------------------------------------------------

    $configPath = Get-ConfigFilePath `
        -ConfiguredPath $ConfigFile

    Write-Host ""
    Write-Host "Konfiguration:" -ForegroundColor Cyan
    Write-Host "  $configPath"

    # -----------------------------------------------------------------------
    # CFG lesen
    # -----------------------------------------------------------------------

    $config = Parse-IniFile -Path $configPath

    # -----------------------------------------------------------------------
    # MediaInfo ermitteln
    # -----------------------------------------------------------------------

    $mediaInfoExecutable = Resolve-MediaInfoPath `
        -ConfiguredPath $MediaInfoPath

    if (-not [string]::IsNullOrWhiteSpace($mediaInfoExecutable)) {

        Write-Host "MediaInfo:" -ForegroundColor Cyan
        Write-Host "  $mediaInfoExecutable"
    }
    else {

        Write-Warning @"
MediaInfo wurde nicht gefunden.

Die FPS kann damit nicht aus der Originaldatei ausgelesen werden.
Das Skript verwendet stattdessen die CFG bzw. 25 FPS.

Installiere optional MediaInfo und stelle sicher, dass
"mediainfo.exe" im PATH liegt oder verwende -MediaInfoPath.
"@
    }

    # -----------------------------------------------------------------------
    # LLC-Dateien finden
    # -----------------------------------------------------------------------

    $llcFiles = @(
        Get-ChildItem `
            -LiteralPath $inputDirectoryResolved `
            -File `
            -Filter '*.llc' |
        Sort-Object Name
    )

    if ($llcFiles.Count -eq 0) {

        Write-Warning @"
Keine .llc-Dateien gefunden in:

$inputDirectoryResolved
"@

        exit 0
    }

    Write-Host ""
    Write-Host "$($llcFiles.Count) LLC-Datei(en) gefunden." `
        -ForegroundColor Cyan

    if ($Force) {
        Write-Host "Ueberschreiben vorhandener Dateien: JA" `
            -ForegroundColor Yellow
    }
    else {
        Write-Host "Ueberschreiben vorhandener Dateien: NEIN" `
            -ForegroundColor Green
    }

    # -----------------------------------------------------------------------
    # Verarbeitung
    # -----------------------------------------------------------------------

    $successCount = 0
    $skippedCount = 0
    $errorCount   = 0

    foreach ($llcFile in $llcFiles) {

        try {

            $result = Convert-ToCutlist `
                -LlcPath $llcFile.FullName `
                -Config $config `
                -OriginalDirectory $OriginalDirectory `
				-MediaInfoExecutable $mediaInfoExecutable `
                -Force ([bool]$Force)

            if ($result) {
                $successCount++
            }
            else {
                $skippedCount++
            }
        }
        catch {

            $errorCount++

            Write-Error @"
Fehler bei '$($llcFile.Name)':

$($_.Exception.Message)
"@
        }
    }

    # -----------------------------------------------------------------------
    # Zusammenfassung
    # -----------------------------------------------------------------------

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "Verarbeitung abgeschlossen."
    Write-Host "============================================================"
    Write-Host "Erfolgreich:       $successCount"
    Write-Host "Uebersprungen:     $skippedCount"
    Write-Host "Fehler:            $errorCount"
    Write-Host "============================================================"

    if ($errorCount -gt 0) {
        exit 1
    }

    exit 0
}
catch {

    Write-Error $_.Exception.Message
    exit 1
}
