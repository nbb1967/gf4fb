#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=ico\GF4FB.ico
#AutoIt3Wrapper_Outfile=GF4FB.exe
#AutoIt3Wrapper_Res_Description=Google Font Base to FontBase Font Base Converter
#AutoIt3Wrapper_Res_Fileversion=0.9.1.5
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=y
#AutoIt3Wrapper_Res_ProductName=Google Fonts for FontBase
#AutoIt3Wrapper_Res_ProductVersion=0.9.1
#AutoIt3Wrapper_Res_CompanyName=NyBumBum
#AutoIt3Wrapper_Res_LegalCopyright=Created by NyBumBum
#AutoIt3Wrapper_Add_Constants=n
#AutoIt3Wrapper_Run_Tidy=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include <MsgBoxConstants.au3>
#include <Crypt.au3>
#include <SQLite.au3>

Opt("TrayMenuMode", 1 + 2 + 4)
Opt("TrayOnEventMode", 1)

TrayCreateItem("Exit")
TrayItemSetOnEvent(-1, "ExitScript")
TraySetClick(8)

Local $nCountLog = 0
Local $sTempLog = ""
Const $sDatatimeLog = @MDAY & "-" & @MON & "-" & @YEAR & " " & @HOUR & ":" & @MIN & ":" & @SEC & "." & @MSEC

;-----------------------SQLite----------------------------
Local $hQuery
Local $aRow
Local $bExistInSQL
Local $sDateFromSQL
Local $sMD5FromSQL

_SQLite_Startup()
If @error Then
	$sTempLog &= $sDatatimeLog & " - " & "Failed to load SQLite3.dll" & @CRLF        ;app works slowly without sql...
	$nCountLog += 1
EndIf

Local $hSQLiteDB = _SQLite_Open('md5.db') ;Open or Create
If @error Then
	$sTempLog &= $sDatatimeLog & " - " & "Failed to open a Database" & @CRLF        ;app works slowly without sql...
	$nCountLog += 1
EndIf

_SQLite_Exec(-1, "CREATE TABLE IF NOT EXISTS google_fonts (id INTEGER PRIMARY KEY, url TEXT NOT NULL UNIQUE, date TEXT NOT NULL, hash TEXT NOT NULL);")
_SQLite_Exec(-1, "CREATE INDEX IF NOT EXISTS index_urls ON google_fonts (url);")

;--------------------Download DB---------------------------
Const $sWebfontsUrl = 'https://www.googleapis.com/webfonts/v1/webfonts?key=YOUR-API-KEY&sort=alpha&capability=VF'
Local $dInputBinary = InetRead($sWebfontsUrl, 1)
If @error <> 0 Then
	MsgBox($MB_ICONERROR, "Error", "Failed to download Google font database.")
	Exit
EndIf
Local $sInputFullText = BinaryToString($dInputBinary, 4)

;---------------------Slicing-----------------------------------
Const $sRegexSliceFullText = '(\"family\"[^\}]*)'
Local $asFontsFamiliesArray = StringRegExp($sInputFullText, $sRegexSliceFullText, 3)
If @error <> 0 Then
	MsgBox($MB_ICONERROR, "Error", "Full text slicing failed")
	Exit
EndIf

;---------------------Progress-----------------------------------
Const $sRegexHTTPS = '(\"https\:)'
Local $asArrayHTTPS = StringRegExp($sInputFullText, $sRegexHTTPS, 3)
Const $sRegexMenu = '(\"menu\")'
Local $asArrayMenu = StringRegExp($sInputFullText, $sRegexMenu, 3)

Local $nGoogleFontsCount = UBound($asArrayHTTPS) - UBound($asArrayMenu)

ProgressOn("Converting font base...", "", "", 100, 100, 18)

Local $nCount = 0
Local $sPercentBefore = 0
Local $sPercentAfter

;-----------------------Parsing------------------------------
Const $sRegexFamily = '(?:\"family\"\:\s\")([^\"]*)'
Const $sRegexLastModified = '(?:\"lastModified\"\:\s\")([^\"]{1,})'
Const $sRegexExtractionVariants = '(\"[^\n]*\.[t|o]tf\")'
Const $sRegexVariant = '(?:\")(\w*)(?:\"\:)'
Const $sRegexFontUrl = '(?:\:\s\")([^\"]{1,})'
Const $sRegexOTFDetect = '(otf)$'

Local $asFamily
Local $asLastModified
Local $asExtractionVariants
Local $asTempVariant = ""
Local $sVariant = ""
Local $asFontUrl = ""

Local $bOTFDetect
Local $sExtension
Local $dData
Local $dMD5
Local $sMD5
Const $sMD5Zero = '00000000000000000000000000000000'

Local $sfonts
Local $sid
Local $sfontFamilyName
Local $sfontSubFamily
Local $sfullFontName
Local $spostScriptName
Local $sTempFonts = '    "fonts": {' & @CRLF

Local $spaths
Local $schecksum
Local $spath
Local $sfileName
Local $surl
Local $sTempPaths = '    "paths": {' & @CRLF

Local $sFullOut

;------------------------Loop Family-----------------------------
For $element In $asFontsFamiliesArray
	$asFamily = StringRegExp($element, $sRegexFamily, 1)
	If @error <> 0 Then
		MsgBox($MB_ICONERROR, "Error", "Font Family not found")
		Exit
	EndIf
	$asLastModified = StringRegExp($element, $sRegexLastModified, 1)
	If @error <> 0 Then
		$sTempLog &= $sDatatimeLog & " - " & "Last Modified for " & $asFamily[0] & " not found" & @CRLF        ;app works slowly without sql...
		$nCountLog += 1
	EndIf
	$asExtractionVariants = StringRegExp($element, $sRegexExtractionVariants, 3)
	If @error <> 0 Then
		MsgBox($MB_ICONERROR, "Error", "Variants extraction failed")
		Exit
	EndIf
	;----------------Loop in loop Variants-----------------------------
	For $variant In $asExtractionVariants
		$asTempVariant = StringRegExp($variant, $sRegexVariant, 1)
		If @error <> 0 Then
			MsgBox($MB_ICONERROR, "Error", "Font variant not found")
			Exit
		EndIf
		;-----------------------------------------------------------
		$asFontUrl = StringRegExp($variant, $sRegexFontUrl, 1)
		If @error <> 0 Then
			MsgBox($MB_ICONERROR, "Error", "Font Url not found")
			Exit
		EndIf

		;---------------------------SQL and MD5---------------------
		_SQLite_Query(-1, "SELECT EXISTS (SELECT url FROM google_fonts WHERE url = " & _SQLite_FastEscape($asFontUrl[0]) & ");", $hQuery)
		While _SQLite_FetchData($hQuery, $aRow) = $SQLITE_OK
			$bExistInSQL = $aRow[0]
		WEnd

		If $bExistInSQL = 1 Then
			_SQLite_Query(-1, "SELECT * FROM google_fonts WHERE url = " & _SQLite_FastEscape($asFontUrl[0]) & ";", $hQuery)
			While _SQLite_FetchData($hQuery, $aRow) = $SQLITE_OK
				$sDateFromSQL = $aRow[2]
				$sMD5FromSQL = $aRow[3] ;just in case
			WEnd
			If $sDateFromSQL == $asLastModified[0] Then
				$sMD5 = $sMD5FromSQL
			Else
				$dData = InetRead($asFontUrl[0], 1)
				If @error <> 0 Then
					$sTempLog &= $sDatatimeLog & " - " & "Failed to download " & $asFontUrl[0] & @CRLF
					$nCountLog += 1
					$sMD5 = $sMD5Zero
				Else
					$dMD5 = _Crypt_HashData($dData, $CALG_MD5)
					If @error <> 0 Then
						$sTempLog &= $sDatatimeLog & " - " & "Failed to calculate hash for " & $asFontUrl[0] & @CRLF
						$nCountLog += 1
						$sMD5 = $sMD5Zero
					Else
						$sMD5 = StringLower(StringTrimLeft($dMD5, 2))
						_SQLite_Exec(-1, "UPDATE google_fonts SET date = " & _SQLite_FastEscape($asLastModified[0]) & ", hash = " & _SQLite_FastEscape($sMD5) & " WHERE url = " & _SQLite_FastEscape($asFontUrl[0]) & ";")
					EndIf
				EndIf
			EndIf
		Else
			$dData = InetRead($asFontUrl[0], 1)
			If @error <> 0 Then
				$sTempLog &= $sDatatimeLog & " - " & "Failed to download " & $asFontUrl[0] & @CRLF
				$nCountLog += 1
				$sMD5 = $sMD5Zero
			Else
				$dMD5 = _Crypt_HashData($dData, $CALG_MD5)
				If @error <> 0 Then
					$sTempLog &= $sDatatimeLog & " - " & "Failed to calculate hash for " & $asFontUrl[0] & @CRLF
					$nCountLog += 1
					$sMD5 = $sMD5Zero
				Else
					$sMD5 = StringLower(StringTrimLeft($dMD5, 2))
					_SQLite_Exec(-1, "INSERT INTO google_fonts (url, date, hash) VALUES (" & _SQLite_FastEscape($asFontUrl[0]) & ", " & _SQLite_FastEscape($asLastModified[0]) & ", " & _SQLite_FastEscape($sMD5) & ");")
				EndIf
			EndIf
		EndIf

		;------------------------ttf or otf-------------------------
		$bOTFDetect = StringRegExp($asFontUrl[0], $sRegexOTFDetect)
		If $bOTFDetect Then
			$sExtension = ".otf"
		Else
			$sExtension = ".ttf"
		EndIf
		;-----------------------------------------------------------
		Switch $asTempVariant[0]
			Case "100"
				$sVariant = "Thin"
			Case "100italic"
				$sVariant = "Thin Italic"
			Case "200"
				$sVariant = "ExtraLight"
			Case "200italic"
				$sVariant = "ExtraLight Italic"
			Case "300"
				$sVariant = "Light"
			Case "300italic"
				$sVariant = "Light Italic"
			Case "regular"
				$sVariant = "Regular"
			Case "italic"
				$sVariant = "Italic"
			Case "500"
				$sVariant = "Medium"
			Case "500italic"
				$sVariant = "Medium Italic"
			Case "600"
				$sVariant = "SemiBold"
			Case "600italic"
				$sVariant = "SemiBold Italic"
			Case "700"
				$sVariant = "Bold"
			Case "700italic"
				$sVariant = "Bold Italic"
			Case "800"
				$sVariant = "ExtraBold"
			Case "800italic"
				$sVariant = "ExtraBold Italic"
			Case "900"
				$sVariant = "Black"
			Case "900italic"
				$sVariant = "Black Italic"
		EndSwitch
		;-------------------------------------------------------------
		$sfonts = '        "' & StringStripWS($asFamily[0], 8) & '-' & StringStripWS($sVariant, 8) & '": {' & @CRLF
		$sid = '            "id": "' & StringStripWS($asFamily[0], 8) & '-' & StringStripWS($sVariant, 8) & '",' & @CRLF
		$sfontFamilyName = '            "fontFamilyName": "' & StringStripWS($asFamily[0], 8) & '",' & @CRLF
		$sfontSubFamily = '            "fontSubFamily": "' & $sVariant & '",' & @CRLF
		$sfullFontName = '            "fullFontName": "' & $asFamily[0] & ' ' & $sVariant & '",' & @CRLF
		$spostScriptName = '            "postScriptName": "' & StringStripWS($asFamily[0], 8) & '-' & StringStripWS($sVariant, 8) & '"' & @CRLF

		$sTempFonts &= $sfonts & $sid & $sfontFamilyName & $sfontSubFamily & $sfullFontName & $spostScriptName & '        },' & @CRLF
		;------------------------------------------------------------
		$spaths = '        "/Providers/Google/' & StringStripWS($asFamily[0], 8) & '-' & StringStripWS($sVariant, 8) & $sExtension & '": {' & @CRLF
		$schecksum = '            "checksum": "' & $sMD5 & '",' & @CRLF
		$spath = '            "path": "/Providers/Google/' & StringStripWS($asFamily[0], 8) & '-' & StringStripWS($sVariant, 8) & $sExtension & '",' & @CRLF
		$sfileName = '            "fileName": "' & StringStripWS($asFamily[0], 8) & '-' & StringStripWS($sVariant, 8) & $sExtension & '",' & @CRLF
		$surl = '            "url": "' & $asFontUrl[0] & '"' & @CRLF

		$sTempPaths &= $spaths & $sid & $schecksum & $spath & $sfileName & $surl & '        },' & @CRLF

		;---------------------Percentage of progress-----------------------
		$nCount += 1
		$sPercentAfter = Round(($nCount / $nGoogleFontsCount) * 100)
		If $sPercentAfter <> $sPercentBefore Then
			If $sPercentAfter <> 100 Then
				ProgressSet($sPercentAfter, $sPercentAfter & " %")
			Else
				ProgressSet($sPercentAfter, $sPercentAfter & " %", "Done.")
			EndIf
		EndIf
		$sPercentBefore = $sPercentAfter

	Next

Next
;------------------------------------------------------------------
Sleep(1000)
ProgressOff()

;------------------------------Merge--------------------------------
$sFullOut = '{' & @CRLF & StringTrimRight($sTempFonts, 3) & @CRLF & '    },' & @CRLF & StringTrimRight($sTempPaths, 3) & @CRLF & '    }' & @CRLF & '}' & @CRLF
;----------------------------Save File------------------------------
Local $sPatchToGoogleJson = FileSaveDialog("Save File", @ScriptDir, "Google font base for FontBase (*.json)|All (*.*)", 18, "google.json")

Local $hOutputFile = FileOpen($sPatchToGoogleJson, 258)
FileWrite($hOutputFile, $sFullOut)
FileClose($hOutputFile)

;------------------------------Log------------------------------------
If $nCountLog <> 0 Then
	Local $sPatchToLogFile = @ScriptDir & "\log.txt"
	Local $hLogFile = FileOpen($sPatchToLogFile, 257)
	FileWrite($hLogFile, $sTempLog)
	FileClose($hLogFile)
	MsgBox($MB_ICONWARNING, "Warning", "Some errors occurred while calculating checksums. For more details, see the log file in the program folder.")
EndIf

ExitScript()

Func ExitScript()
	_SQLite_Close()
	_SQLite_Shutdown()
	Exit
EndFunc   ;==>ExitScript
