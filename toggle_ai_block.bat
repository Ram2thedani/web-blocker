@echo off
setlocal enabledelayedexpansion

:: Check for Administrator privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] This script must be run as Administrator!
    echo Right-click the .bat file and select "Run as administrator".
    pause
    exit /b 1
)

set "HOSTS_PATH=%SystemRoot%\System32\drivers\etc\hosts"
set "LIST_FILE=ai_sites.txt"
set "TEMP_HOSTS=%SystemRoot%\System32\drivers\etc\hosts.tmp"

if not exist "%LIST_FILE%" (
    echo [ERROR] Could not find %LIST_FILE% in the current directory!
    echo Please create %LIST_FILE% with domain names listed one per line.
    pause
    exit /b 1
)

echo ============================================
echo   Generative AI Hosts Manager
echo ============================================
echo 1. Block AI Sites (Uncomment / Add)
echo 2. Unblock AI Sites (Comment out)
echo 3. Exit
echo ============================================
set /p CHOICE="Choose an option (1-3): "

if "%CHOICE%"=="1" goto BLOCK
if "%CHOICE%"=="2" goto UNBLOCK
if "%CHOICE%"=="3" goto END
echo Invalid choice.
pause
exit /b 1

:BLOCK
echo.
echo Blocking AI websites...

:: Process each line in ai_sites.txt
for /f "usebackq tokens=* delims=" %%A in ("%LIST_FILE%") do (
    set "DOMAIN=%%A"
    :: Strip whitespace and skip empty lines or existing comments in txt
    if not "!DOMAIN!"=="" (
        call :BLOCK_DOMAIN "!DOMAIN!"
    )
)

:: Flush DNS cache
ipconfig /flushdns >nul
echo.
echo [SUCCESS] AI sites have been BLOCKED.
pause
goto END

:UNBLOCK
echo.
echo Unblocking AI websites...

for /f "usebackq tokens=* delims=" %%A in ("%LIST_FILE%") do (
    set "DOMAIN=%%A"
    if not "!DOMAIN!"=="" (
        call :UNBLOCK_DOMAIN "!DOMAIN!"
    )
)

:: Flush DNS cache
ipconfig /flushdns >nul
echo.
echo [SUCCESS] AI sites have been UNBLOCKED.
pause
goto END


:BLOCK_DOMAIN
set "DOM=%~1"
findstr /i /c:"%DOM%" "%HOSTS_PATH%" >nul
if %errorlevel% equ 0 (
    :: Entry exists; if it starts with #, uncomment it
    powershell -Command "(Get-Content '%HOSTS_PATH%') | ForEach-Object { if ($_ -match '^\s*#\s*127\.0\.0\.1\s+%DOM%') { '127.0.0.1 %DOM%' } else { $_ } } | Set-Content '%HOSTS_PATH%'"
) else (
    :: Entry does not exist; append it
    echo 127.0.0.1 %DOM%>>"%HOSTS_PATH%"
)
exit /b 0


:UNBLOCK_DOMAIN
set "DOM=%~1"
powershell -Command "(Get-Content '%HOSTS_PATH%') | ForEach-Object { if ($_ -match '^\s*127\.0\.0\.1\s+%DOM%') { '# 127.0.0.1 %DOM%' } else { $_ } } | Set-Content '%HOSTS_PATH%'"
exit /b 0


:END
exit /b 0
