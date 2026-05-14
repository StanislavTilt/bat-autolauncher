@echo off
chcp 65001 >nul
setlocal

set "ROOT=%~dp0"
set "CSC=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"

if not exist "%CSC%" (
    echo Не найден csc.exe ^(.NET Framework 4^). Установи .NET Framework 4.x.
    pause
    exit /b 1
)

echo [1/2] Генерация иконки bot.ico...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%gen_icon.ps1"
if errorlevel 1 (
    echo Ошибка генерации иконки.
    pause
    exit /b 1
)

echo [2/2] Компиляция BatLauncherTray.exe...
"%CSC%" /nologo /target:winexe /platform:anycpu /optimize+ /debug- ^
    /out:"%ROOT%BatLauncherTray.exe" ^
    /win32icon:"%ROOT%bot.ico" ^
    /resource:"%ROOT%bot.ico",bot.ico ^
    /reference:System.dll ^
    /reference:System.Drawing.dll ^
    /reference:System.Windows.Forms.dll ^
    "%ROOT%TrayLauncher.cs"
if errorlevel 1 (
    echo Ошибка компиляции.
    pause
    exit /b 1
)

echo.
echo Готово: %ROOT%BatLauncherTray.exe
for %%I in ("%ROOT%BatLauncherTray.exe") do echo Размер: %%~zI байт
echo.
echo Чтобы прописать его в автозагрузку, запусти install.bat.
echo.
pause
endlocal
exit /b 0
