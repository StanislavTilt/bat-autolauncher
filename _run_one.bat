@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "TARGET=%~1"
set "LOG=%~2"

if "%TARGET%"=="" exit /b 2
if "%LOG%"=="" exit /b 2

if exist "%LOG%" (
    for %%S in ("%LOG%") do set "LOGSIZE=%%~zS"
    if defined LOGSIZE if !LOGSIZE! GTR 1048576 (
        if exist "%LOG%.old" del /q "%LOG%.old" >nul 2>&1
        move /Y "%LOG%" "%LOG%.old" >nul 2>&1
    )
)

echo. >> "%LOG%"
echo ====================================================== >> "%LOG%"
echo [%date% %time%] START %TARGET% >> "%LOG%"
echo ====================================================== >> "%LOG%"

< nul call "%TARGET%" >> "%LOG%" 2>&1
set "EC=%errorlevel%"

echo. >> "%LOG%"
if "%EC%"=="0" (
    echo [%date% %time%] EXIT OK code=%EC% >> "%LOG%"
) else (
    echo [%date% %time%] EXIT FAIL code=%EC% >> "%LOG%"
)

endlocal & exit /b %EC%
