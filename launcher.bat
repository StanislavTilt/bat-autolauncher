@echo off
chcp 65001 >nul
setlocal enableextensions enabledelayedexpansion

set "ROOT=%~dp0"
set "BATS=%ROOT%bats"
set "LOGDIR=%ROOT%logs"
set "MAINLOG=%LOGDIR%\launcher.log"
set "RUNNER=%ROOT%_run_one.bat"

if not exist "%BATS%" mkdir "%BATS%"
if not exist "%LOGDIR%" mkdir "%LOGDIR%"

if exist "%MAINLOG%" (
    for %%S in ("%MAINLOG%") do set "LOGSIZE=%%~zS"
    if defined LOGSIZE if !LOGSIZE! GTR 1048576 (
        if exist "%MAINLOG%.old" del /q "%MAINLOG%.old" >nul 2>&1
        move /Y "%MAINLOG%" "%MAINLOG%.old" >nul 2>&1
    )
)

echo. >> "%MAINLOG%"
echo ============================== >> "%MAINLOG%"
echo [%date% %time%] Старт BatLauncher >> "%MAINLOG%"
echo Папка bat-файлов: %BATS% >> "%MAINLOG%"

if not exist "%RUNNER%" (
    echo [%date% %time%] ОШИБКА: не найден раннер %RUNNER% >> "%MAINLOG%"
    endlocal
    exit /b 1
)

set "FOUND=0"
for %%F in ("%BATS%\*.bat" "%BATS%\*.cmd") do (
    set "NAME=%%~nF"
    if "!NAME:~0,1!"=="_" (
        echo [%date% %time%] Пропуск: %%~nxF >> "%MAINLOG%"
    ) else (
        set "FOUND=1"
        set "SUBDIR=%LOGDIR%\!NAME!"
        if not exist "!SUBDIR!" mkdir "!SUBDIR!"
        set "LOGFILE=!SUBDIR!\!NAME!.log"
        echo [%date% %time%] Запуск: %%~nxF -^> !LOGFILE! >> "%MAINLOG%"
        start "" /B cmd /c ""%RUNNER%" "%%~fF" "!LOGFILE!""
    )
)

if "!FOUND!"=="0" (
    echo [%date% %time%] В папке нет .bat/.cmd файлов >> "%MAINLOG%"
)

echo [%date% %time%] Готово >> "%MAINLOG%"
endlocal
exit /b 0
