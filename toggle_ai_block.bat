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

:: Google Chrome Registry Keys
set "CHROME_POLICY_KEY=HKLM\Software\Policies\Google\Chrome"
set "CHROME_POLICY_VAL=AIModeSettings"
set "CHROME_INCOGNITO_VAL=IncognitoModeAvailability"
set "CHROME_PROFILE_VAL=BrowserAddPersonEnabled"
set "CHROME_SIGNIN_VAL=BrowserSignin"
set "CHROME_GUEST_VAL=BrowserGuestModeEnabled"

:: VS Code User Settings Path
set "VSCODE_SETTINGS=%APPDATA%\Code\User\settings.json"

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
echo 1. Block AI Sites + Chrome/VS Code/Extension Restrictions
echo 2. Unblock AI Sites + Restore Defaults
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

echo Applying Chrome restrictions (Incognito, Profiles, Sign-in, Guest, AI Mode)...
reg add "%CHROME_POLICY_KEY%" /v %CHROME_POLICY_VAL% /t REG_DWORD /d 1 /f >nul
reg add "%CHROME_POLICY_KEY%" /v %CHROME_INCOGNITO_VAL% /t REG_DWORD /d 1 /f >nul
reg add "%CHROME_POLICY_KEY%" /v %CHROME_PROFILE_VAL% /t REG_DWORD /d 0 /f >nul
reg add "%CHROME_POLICY_KEY%" /v %CHROME_SIGNIN_VAL% /t REG_DWORD /d 0 /f >nul
reg add "%CHROME_POLICY_KEY%" /v %CHROME_GUEST_VAL% /t REG_DWORD /d 0 /f >nul

echo Restricting Chrome Extensions (block new installs, keep current ones, lock chrome://extensions)...
reg add "%CHROME_POLICY_KEY%\ExtensionInstallBlocklist" /v "1" /t REG_SZ /d "*" /f >nul
reg add "%CHROME_POLICY_KEY%\ExtensionInstallTypeBlocklist" /v "1" /t REG_SZ /d "development" /f >nul
reg add "%CHROME_POLICY_KEY%" /v "BlockExternalExtensions" /t REG_DWORD /d 1 /f >nul
reg add "%CHROME_POLICY_KEY%\URLBlocklist" /v "1" /t REG_SZ /d "chrome://extensions" /f >nul
reg add "%CHROME_POLICY_KEY%\URLBlocklist" /v "2" /t REG_SZ /d "google.com/ai" /f >nul
reg add "%CHROME_POLICY_KEY%\URLBlocklist" /v "3" /t REG_SZ /d "google.com/search?udm=50" /f >nul

:: Allowlist every extension currently installed in the Default profile so it keeps running
reg delete "%CHROME_POLICY_KEY%\ExtensionInstallAllowlist" /f >nul 2>&1
set /a EXT_N=0
for /d %%P in ("%LOCALAPPDATA%\Google\Chrome\User Data\Default\Extensions\*") do (
    if /i not "%%~nxP"=="Temp" (
        set /a EXT_N+=1
        reg add "%CHROME_POLICY_KEY%\ExtensionInstallAllowlist" /v "!EXT_N!" /t REG_SZ /d "%%~nxP" /f >nul
    )
)
echo Allowlisted !EXT_N! installed extension(s).

echo Disabling VS Code opening localhost links in built-in browser...
call :TOGGLE_VSCODE_BROWSER block

echo.
echo [SUCCESS] AI sites blocked and restrictions applied.
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

echo Restoring Chrome default settings...
reg query "%CHROME_POLICY_KEY%" /v %CHROME_POLICY_VAL% >nul 2>&1
if !errorlevel! equ 0 reg delete "%CHROME_POLICY_KEY%" /v %CHROME_POLICY_VAL% /f >nul

reg query "%CHROME_POLICY_KEY%" /v %CHROME_INCOGNITO_VAL% >nul 2>&1
if !errorlevel! equ 0 reg delete "%CHROME_POLICY_KEY%" /v %CHROME_INCOGNITO_VAL% /f >nul

reg query "%CHROME_POLICY_KEY%" /v %CHROME_PROFILE_VAL% >nul 2>&1
if !errorlevel! equ 0 reg delete "%CHROME_POLICY_KEY%" /v %CHROME_PROFILE_VAL% /f >nul

reg query "%CHROME_POLICY_KEY%" /v %CHROME_SIGNIN_VAL% >nul 2>&1
if !errorlevel! equ 0 reg delete "%CHROME_POLICY_KEY%" /v %CHROME_SIGNIN_VAL% /f >nul

reg query "%CHROME_POLICY_KEY%" /v %CHROME_GUEST_VAL% >nul 2>&1
if !errorlevel! equ 0 reg delete "%CHROME_POLICY_KEY%" /v %CHROME_GUEST_VAL% /f >nul

echo Restoring Chrome Extension policies...
reg delete "%CHROME_POLICY_KEY%\ExtensionInstallBlocklist" /f >nul 2>&1
reg delete "%CHROME_POLICY_KEY%\ExtensionInstallTypeBlocklist" /f >nul 2>&1
reg delete "%CHROME_POLICY_KEY%\URLBlocklist" /f >nul 2>&1
reg delete "%CHROME_POLICY_KEY%\ExtensionInstallAllowlist" /f >nul 2>&1

reg query "%CHROME_POLICY_KEY%" /v "BlockExternalExtensions" >nul 2>&1
if !errorlevel! equ 0 reg delete "%CHROME_POLICY_KEY%" /v "BlockExternalExtensions" /f >nul

reg query "%CHROME_POLICY_KEY%" /v "ExtensionSettings" >nul 2>&1
if !errorlevel! equ 0 reg delete "%CHROME_POLICY_KEY%" /v "ExtensionSettings" /f >nul

echo Restoring VS Code localhost link settings...
call :TOGGLE_VSCODE_BROWSER unblock

echo.
echo [SUCCESS] AI sites unblocked and settings restored.
pause
goto MENU

:EDIT_HOSTS
:: Runs the PowerShell block at the bottom of this file (one read, one write, with retries)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText('%~f0'); $i=$s.LastIndexOf('#PS_START'); Invoke-Expression $s.Substring($i)"
exit /b %errorlevel%

:TOGGLE_VSCODE_BROWSER
:: Safely modifies VS Code settings.json to disable/enable workbench.browser.openLocalhostLinks
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$settingsPath = [System.Environment]::ExpandEnvironmentVariables('%VSCODE_SETTINGS%');" ^
    "$action = '%1';" ^
    "if (-not (Test-Path (Split-Path $settingsPath))) { New-Item -ItemType Directory -Force -Path (Split-Path $settingsPath) | Out-Null }" ^
    "if (-not (Test-Path $settingsPath)) { Set-Content -Path $settingsPath -Value '{}' }" ^
    "try { $json = Get-Content -Raw $settingsPath | ConvertFrom-Json -ErrorAction Stop } catch { $json = [PSCustomObject]@{} }" ^
    "if ($action -eq 'block') {" ^
    "    $json | Add-Member -NotePropertyName 'workbench.browser.openLocalhostLinks' -NotePropertyValue $false -Force;" ^
    "} else {" ^
    "    if ($json.PSObject.Properties['workbench.browser.openLocalhostLinks']) { $json.PSObject.Properties.Remove('workbench.browser.openLocalhostLinks') }" ^
    "}" ^
    "$json | ConvertTo-Json -Depth 32 | Set-Content -Path $settingsPath"
exit /b 0

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
