# ![](https://github.com/nbb1967/gf4fb/blob/main/ico/48.png) GF<sub>4</sub>FB (Google Fonts for FontBase) 

Converter of Google Fonts database into FontBase font manager format



Google Fonts is organized in the following way: if a font is updated, the new version of the font does not replace the old version, but is added to a new folder: v2, v3, v4..... So all the old versions of fonts are available through the old links, but the Google Fonts service itself links to the new versions of fonts. 

Unfortunately, the authors of FontBase font manager rarely update the static database of Google fonts in their program. Therefore, users of FontBase font manager often work with old font base and outdated versions of Google fonts. The GF4FB utility converts the Google font database to FontBase font manager format, allowing you to manually update the Google font database in program. The application queries the Google Fonts API for a complete list of Google fonts, then it converts this list to FontBase format, calculates checksums of all fonts or retrieves them from the built-in database, and generates a `google.json` file with an up-to-date Google font database for FontBase with classic font variant naming.



To update you need to:

1. Run the GF<sub>4</sub>FB utility and wait for the processing to finish

2. Save the generated `google.json` file

3. Replace the `google.json` file in the `“FontBase\resources\app\providers”` folder.

4. Delete all Google fonts in FontBase: right-click on `Google` > `Delete`.

5. Re-import Google fonts into FontBase: right-click on `Providers` > `Import Google fonts`.



> [!NOTE]
> Processing time can take from 20 seconds to 20 minutes, depending on PC performance, quality of Internet connection, dimensions of the update and share of fonts found in the built-in database.

Windows utility is created with AutoIt, is free, does not require installation.

# 
NyBumBum
