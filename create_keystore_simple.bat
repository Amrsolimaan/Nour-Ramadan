@echo off
echo Creating new keystore for Nour Ramadan app...
echo.

keytool -genkey -v -keystore android\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

echo.
echo Keystore created successfully!
echo Now run get_sha1.bat to get the SHA1 fingerprint
pause