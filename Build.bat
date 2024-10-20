@echo off
setlocal

REM Define the name of the zip file
set "ZIP_NAME=Flat Pack.zip"

REM Define the list of files to add to the zip (use full paths or relative paths)
set FILES="audio" "data" "img" "mod-appendix"

REM Create a temporary folder for zipping if necessary
set TEMP_ZIP_DIR=%TEMP%\zip_temp
if not exist "%TEMP_ZIP_DIR%" mkdir "%TEMP_ZIP_DIR%"

REM Copy files to the temporary folder
for %%F in (%FILES%) do (
    if exist "%%~F" (
        copy "%%~F" "%TEMP_ZIP_DIR%\"
    ) else (
        echo File not found: %%~F
    )
)

REM Use PowerShell to create a zip file from the temporary folder
powershell -command "Compress-Archive -Path '%TEMP_ZIP_DIR%\*' -DestinationPath '%CD%\%ZIP_NAME%'"

REM Clean up temporary folder
rd /s /q "%TEMP_ZIP_DIR%"

echo Zip file created: %ZIP_NAME%
pause