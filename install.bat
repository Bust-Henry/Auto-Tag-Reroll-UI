@echo off

echo Installing Auto Tag Reroll UI...

if not exist "%APPDATA%\Balatro\Mods\" (
    echo Creating Mods folder...
    mkdir "%APPDATA%\Balatro\Mods\"
)

copy /Y "AutoTagRerollUI.lua" "%APPDATA%\Balatro\Mods\"

echo.
echo Installation complete!
echo.
echo Press any key to exit...
pause 