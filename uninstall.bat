@echo off
chcp 65001 >nul
setlocal

set "NAME=BatLauncher"

echo Удаление из автозагрузки...
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "%NAME%" /f >nul 2>&1
if errorlevel 1 (
    echo Запись не найдена или уже удалена.
) else (
    echo Удалено.
)

echo.
pause
endlocal
exit /b 0
