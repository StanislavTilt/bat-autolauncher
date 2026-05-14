@echo off
chcp 65001 >nul
setlocal

set "ROOT=%~dp0"
set "LAUNCHER=%ROOT%launcher.bat"
set "LAUNCHERVBS=%ROOT%launcher.vbs"
set "LAUNCHEREXE=%ROOT%BatLauncherTray.exe"
set "BATS=%ROOT%bats"
set "NAME=BatLauncher"

if not exist "%LAUNCHER%" (
    echo Не найден launcher.bat рядом с install.bat
    pause
    exit /b 1
)

if not exist "%BATS%" mkdir "%BATS%"

if exist "%LAUNCHEREXE%" (
    set "RUN_CMD=\"%LAUNCHEREXE%\""
    set "MODE=BatLauncherTray.exe (иконка в трее, без окна)"
) else if exist "%LAUNCHERVBS%" (
    set "RUN_CMD=wscript.exe \"%LAUNCHERVBS%\""
    set "MODE=launcher.vbs (без окна, без иконки)"
) else (
    set "RUN_CMD=\"%LAUNCHER%\""
    set "MODE=launcher.bat (видимое окно консоли)"
)

echo Добавление в автозагрузку текущего пользователя...
echo   Режим:  %MODE%
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "%NAME%" /t REG_SZ /d "%RUN_CMD%" /f >nul
if errorlevel 1 (
    echo Не удалось записать ключ реестра.
    pause
    exit /b 1
)

echo.
echo Готово.
echo   Лаунчер:    %LAUNCHER%
echo   Папка bat:  %BATS%
if exist "%LAUNCHEREXE%" echo   Трей:       %LAUNCHEREXE%
if exist "%LAUNCHERVBS%" if not exist "%LAUNCHEREXE%" echo   Обёртка:    %LAUNCHERVBS%
echo.
echo Положите свои .bat / .cmd файлы в папку bats — они будут запускаться при входе в Windows.
echo Для удаления из автозагрузки запустите: uninstall.bat
echo.
pause
endlocal
exit /b 0
