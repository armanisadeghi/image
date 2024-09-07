@echo off
setlocal

REM Define the source and destination folders
set "SOURCE_FOLDER=%~dp0"
set "DESTINATION_FOLDER=%~dp0..\App\ComfyUI\pysssss-workflows"


REM Create the destination folder if it doesn't exist
if not exist "%DESTINATION_FOLDER%" (
    mkdir "%DESTINATION_FOLDER%"
)

REM Copy all files and folders from the source to the destination, replacing any existing files
echo Syncing files from "%SOURCE_FOLDER%" to "%DESTINATION_FOLDER%"...
xcopy /e /i /y "%SOURCE_FOLDER%" "%DESTINATION_FOLDER%"

REM Notify the user that the sync is complete
REM Delete the Sync prompts.bat file from the destination folder if it exists
if exist "%DESTINATION_FOLDER%\0-COPY workflows to ComfyUI.bat" (
    del "%DESTINATION_FOLDER%\0-COPY workflows to ComfyUI.bat"
)
if exist "%DESTINATION_FOLDER%\1-OPEN folder in ComfyUI.bat" (
    del "%DESTINATION_FOLDER%\1-OPEN folder in ComfyUI.bat"
)
echo WORKFLOW sync completed...
pause

endlocal
