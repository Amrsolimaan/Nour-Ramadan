@echo off
echo Building release APK and App Bundle...
echo.

echo Cleaning previous builds...
flutter clean

echo Getting dependencies...
flutter pub get

echo Building App Bundle for Google Play...
flutter build appbundle --release

echo.
echo Build completed!
echo App Bundle location: build\app\outputs\bundle\release\app-release.aab
echo.
pause