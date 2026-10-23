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
set "CHROME_POLICY_KEY=HKLM\Software\Policies\Google\Chrome"
set "CHROME_POLICY_VAL=AIModeSettings"

if not exist "%LIST_FILE%" (
    echo [ERROR] Could not find %LIST_FILE% in:
    echo %CD%
    echo Make sure %LIST_FILE% is in the same folder as this script.
    pause
    exit /b 1
)

:MENU
cls
set "CHROME_STATUS=Allowed (default)"
reg query "%CHROME_POLICY_KEY%" /v %CHROME_POLICY_VAL% 2>nul | find "0x1" >nul
if !errorlevel! equ 0 set "CHROME_STATUS=Disabled by policy"

echo ============================================
echo   Generative AI Hosts Manager (Admin Mode)
echo ============================================
echo Working Directory: %CD%
echo Chrome AI Mode:    !CHROME_STATUS!
echo --------------------------------------------
echo 1. Block AI Sites + disable Chrome AI Mode
echo 2. Unblock AI Sites + restore Chrome AI Mode
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
set "MODE=block"
call :EDIT_HOSTS
if !errorlevel! neq 0 (
    echo [ERROR] Could not write the hosts file. Close any editor or security tool using it and try again.
    pause
    goto MENU
)
ipconfig /flushdns >nul

echo Disabling Chrome AI Mode button...
reg add "%CHROME_POLICY_KEY%" /v %CHROME_POLICY_VAL% /t REG_DWORD /d 1 /f >nul
if !errorlevel! neq 0 (
    echo [WARNING] Could not set the Chrome policy.
) else (
    echo Chrome policy set. Restart Chrome to apply.
)

echo.
echo [SUCCESS] AI sites have been BLOCKED.
pause
goto MENU

:UNBLOCK
echo.
echo Unblocking AI websites...
set "MODE=unblock"
call :EDIT_HOSTS
if !errorlevel! neq 0 (
    echo [ERROR] Could not write the hosts file. Close any editor or security tool using it and try again.
    pause
    goto MENU
)
ipconfig /flushdns >nul

echo Restoring Chrome AI Mode button...
reg query "%CHROME_POLICY_KEY%" /v %CHROME_POLICY_VAL% >nul 2>&1
if !errorlevel! equ 0 (
    reg delete "%CHROME_POLICY_KEY%" /v %CHROME_POLICY_VAL% /f >nul
    echo Chrome policy removed. Restart Chrome to apply.
) else (
    echo Chrome policy was not set, nothing to remove.
)

echo.
echo [SUCCESS] AI sites have been UNBLOCKED.
pause
goto MENU

:EDIT_HOSTS
:: Runs the PowerShell block at the bottom of this file (one read, one write, with retries)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText('%~f0'); $i=$s.LastIndexOf('#PS_START'); Invoke-Expression $s.Substring($i)"
exit /b %errorlevel%

:END
endlocal
exit /b 0

#PS_START
$p = $env:HOSTS_PATH
$mode = $env:MODE
$domains = Get-Content -LiteralPath $env:LIST_FILE | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
$lines = New-Object 'System.Collections.Generic.List[string]'
foreach ($l in (Get-Content -LiteralPath $p)) { $lines.Add($l) }

foreach ($d in $domains) {
    $e = [Regex]::Escape($d)
    $found = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($mode -eq 'block') {
            if ($lines[$i] -match "^\s*#\s*127\.0\.0\.1\s+$e(\s|$)") { $lines[$i] = "127.0.0.1 $d"; $found = $true }
            elseif ($lines[$i] -match "^\s*127\.0\.0\.1\s+$e(\s|$)") { $found = $true }
        } else {
            if ($lines[$i] -match "^\s*127\.0\.0\.1\s+$e(\s|$)") { $lines[$i] = "# 127.0.0.1 $d" }
        }
    }
    if ($mode -eq 'block' -and -not $found) { $lines.Add("127.0.0.1 $d") }
}

$ok = $false
for ($t = 0; $t -lt 10 -and -not $ok; $t++) {
    try { [IO.File]::WriteAllLines($p, $lines); $ok = $true }
    catch { Start-Sleep -Milliseconds 700 }
}
if (-not $ok) { exit 1 }
exit 0
