@echo off
REM Get SHA-1 and SHA-256 fingerprints for Android app signing
REM This script helps Windows developers quickly retrieve fingerprints for Google Sign-In configuration

setlocal enabledelayedexpansion

REM Colors
set RED=[91m
set GREEN=[92m
set YELLOW=[93m
set BLUE=[94m
set NC=[0m

echo.
echo %BLUE%=== Android Signing Fingerprints Extractor ===%NC%
echo.

if "%1"=="--help" goto show_help
if "%1"=="-h" goto show_help
if "%1"=="" goto extract_debug
if "%1"=="debug" goto extract_debug
if "%1"=="release" goto extract_release
if "%1"=="custom" goto extract_custom

echo %RED%Unknown command: %1%NC%
echo.
goto show_help

:extract_debug
echo %BLUE%Extracting debug keystore fingerprints...%NC%
echo.

set KEYSTORE=%USERPROFILE%\.android\debug.keystore

if not exist "%KEYSTORE%" (
    echo %RED%Error: Debug keystore not found at %KEYSTORE%%NC%
    echo %YELLOW%Have you run Flutter/Android yet? Try running: flutter run%NC%
    exit /b 1
)

echo %GREEN%Found keystore at: %KEYSTORE%%NC%
echo.

call :extract_fingerprints "%KEYSTORE%" androiddebugkey android android
goto end

:extract_release
echo %BLUE%Extracting release keystore fingerprints...%NC%
echo.

set /p KEYSTORE="Enter path to release keystore: "
set /p ALIAS="Enter keystore alias [my-key-alias]: "
if "!ALIAS!"=="" set ALIAS=my-key-alias

set /p STOREPASS="Enter keystore password: "
set /p KEYPASS="Enter key password (press Enter if same as store password): "
if "!KEYPASS!"=="" set KEYPASS=!STOREPASS!

call :extract_fingerprints "!KEYSTORE!" "!ALIAS!" "!KEYPASS!" "!STOREPASS!"
goto end

:extract_custom
if "%2"=="" (
    echo %RED%Error: custom mode requires keystore path and alias%NC%
    goto show_help
)
if "%3"=="" (
    echo %RED%Error: custom mode requires keystore path and alias%NC%
    goto show_help
)

set /p STOREPASS="Enter keystore password [android]: "
if "!STOREPASS!"=="" set STOREPASS=android

set /p KEYPASS="Enter key password [android]: "
if "!KEYPASS!"=="" set KEYPASS=android

call :extract_fingerprints "%2" "%3" "!KEYPASS!" "!STOREPASS!"
goto end

:extract_fingerprints
setlocal enabledelayedexpansion
set KEYSTORE=%~1
set ALIAS=%~2
set KEYPASS=%~3
set STOREPASS=%~4

if not exist "!KEYSTORE!" (
    echo %RED%Error: Keystore not found at !KEYSTORE!%NC%
    exit /b 1
)

REM Use keytool to get fingerprints
REM This requires keytool to be in PATH (comes with Java)

for /f "tokens=*" %%A in ('keytool -list -v -keystore "!KEYSTORE!" -alias "!ALIAS!" -storepass "!STOREPASS!" -keypass "!KEYPASS!" 2^>nul ^| findstr "SHA" 2^>nul') do (
    set LINE=%%A
    if "!LINE:SHA1=!" neq "!LINE!" (
        set SHA1_LINE=!LINE!
    )
    if "!LINE:SHA-256=!" neq "!LINE!" (
        set SHA256_LINE=!LINE!
    )
)

if "!SHA1_LINE!"=="" (
    echo %RED%Error: Could not extract fingerprints from keystore%NC%
    echo %YELLOW%Check alias, passwords, or file permissions%NC%
    exit /b 1
)

echo %YELLOW%Keystore: !KEYSTORE!%NC%
echo %YELLOW%Alias: !ALIAS!%NC%
echo %YELLOW%Certificate fingerprints:%NC%
echo.
echo %GREEN%SHA-1:%NC%
echo   !SHA1_LINE!
echo.
echo %GREEN%SHA-256:%NC%
echo   !SHA256_LINE!
echo.

endlocal
exit /b 0

:show_help
echo %BLUE%Usage:%NC%
echo   %0                              - Extract from debug keystore
echo   %0 release                      - Extract from release keystore
echo   %0 custom PATH ALIAS            - Extract from custom keystore
echo   %0 --help                       - Show this help message
echo.
echo %BLUE%Examples:%NC%
echo   - Get debug fingerprints
echo     %0
echo.
echo   - Get release fingerprints
echo     %0 release
echo.
echo   - Get fingerprints from custom keystore
echo     %0 custom .\my-release-key.keystore my-key-alias
echo.
echo %BLUE%Default values:%NC%
echo   Debug keystore: %USERPROFILE%\.android\debug.keystore
echo   Debug alias: androiddebugkey
echo   Passwords: android
echo.

:end
if "%1"=="debug" (
    echo.
    echo %BLUE%=== Next Steps ===%NC%
    echo 1. Copy the SHA-1 and SHA-256 fingerprints above
    echo 2. Go to Firebase Console ^> Your Project ^> Project Settings
    echo 3. Add/Update your Android app with these fingerprints
    echo 4. Download google-services.json and place it at android\app\
    echo 5. Run flutter run to build with the new configuration
    echo.
    echo For more details, see: docs\GOOGLE_SIGNIN_SETUP.md
    echo.
)

endlocal
