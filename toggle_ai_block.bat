@echo off
:: Re-launch script with Admin rights and preserve the original directory
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    pushd "%~dp0"
    setlocal enabledelayedexpansion

set "HOSTS_PATH=%SystemRoot%\System32\drivers\etc\hosts"
set "LIST_FILE=ai_sites.txt"

if not exist "%LIST_FILE%" (
    echo [ERROR] Could not find %LIST_FILE% in:
    echo %CD%
    echo Make sure %LIST_FILE% is in the same folder as this script.
    pause
    exit /b 1
)

:MENU
cls
echo ============================================
echo   Generative AI Hosts Manager (Admin Mode)
echo ============================================
echo Working Directory: %CD%
echo --------------------------------------------
echo 1. Block AI Sites (Uncomment / Add)
echo 2. Unblock AI Sites (Comment out)
echo 3. Exit
echo ============================================
set /p CHOICE="Choose an option (1-3): "

if "%CHOICE%"=="1" goto BLOCK
if "%CHOICE%"=="2" goto UNBLOCK
if "%CHOICE%"=="3" goto END
goto MENU

:BLOCK
echo.
echo Blocking AI websites...
for /f "usebackq tokens=* delims=" %%A in ("%LIST_FILE%") do (
    set "DOMAIN=%%A"
    if not "!DOMAIN!"=="" call :BLOCK_DOMAIN "!DOMAIN!"
)
ipconfig /flushdns >nul
echo.
echo [SUCCESS] AI sites have been BLOCKED.
pause
goto MENU

:UNBLOCK
echo.
echo Unblocking AI websites...
for /f "usebackq tokens=* delims=" %%A in ("%LIST_FILE%") do (
    set "DOMAIN=%%A"
    if not "!DOMAIN!"=="" call :UNBLOCK_DOMAIN "!DOMAIN!"
)
ipconfig /flushdns >nul
echo.
echo [SUCCESS] AI sites have been UNBLOCKED.
pause
goto MENU

:BLOCK_DOMAIN
set "DOM=%~1"
findstr /i /c:"%DOM%" "%HOSTS_PATH%" >nul
if %errorlevel% equ 0 (
    powershell -Command "$p='%HOSTS_PATH%'; $d='%DOM%'; $c=[System.IO.File]::ReadAllLines($p); $nc=foreach($l in $c){if($l -match '^\s*#\s*127\.0\.0\.1\s+'+[Regex]::Escape($d)){'127.0.0.1 '+$d}else{$l}}; [System.IO.File]::WriteAllLines($p, $nc)"
) else (
    echo 127.0.0.1 %DOM%>>"%HOSTS_PATH%"
)
exit /b 0

:UNBLOCK_DOMAIN
set "DOM=%~1"
powershell -Command "$p='%HOSTS_PATH%'; $d='%DOM%'; $c=[System.IO.File]::ReadAllLines($p); $nc=foreach($l in $c){if($l -match '^\s*127\.0\.0\.1\s+'+[Regex]::Escape($d)){'# 127.0.0.1 '+$d}else{$l}}; [System.IO.File]::WriteAllLines($p, $nc)"
exit /b 0

:END
endlocal
exit /b 0