@echo off
echo Getting SHA1 fingerprint...
echo.

if not exist "android\upload-keystore.jks" (
    echo Error: keystore file not found!
    echo Please create keystore first using create_keystore_simple.bat
    pause
    exit /b 1
)

echo Enter your keystore password:
keytool -list -v -keystore android\upload-keystore.jks -alias upload

echo.
echo Copy the SHA1 fingerprint above and use it in Google Play Console
pause