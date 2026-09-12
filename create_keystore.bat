@echo off
echo إنشاء keystore جديد...
echo.
echo يرجى إدخال المعلومات التالية:
echo.

set /p STORE_PASSWORD="كلمة مرور المتجر (Store Password): "
set /p KEY_PASSWORD="كلمة مرور المفتاح (Key Password): "
set /p KEY_ALIAS="اسم المفتاح (Key Alias) [افتراضي: upload]: "
if "%KEY_ALIAS%"=="" set KEY_ALIAS=upload

set /p FIRST_LAST_NAME="الاسم الأول والأخير: "
set /p ORG_UNIT="وحدة المؤسسة: "
set /p ORG="اسم المؤسسة: "
set /p CITY="المدينة: "
set /p STATE="المحافظة: "
set /p COUNTRY="رمز البلد (مثل SA): "

echo.
echo إنشاء keystore...

keytool -genkey -v -keystore android\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias %KEY_ALIAS% -storepass %STORE_PASSWORD% -keypass %KEY_PASSWORD% -dname "CN=%FIRST_LAST_NAME%, OU=%ORG_UNIT%, O=%ORG%, L=%CITY%, S=%STATE%, C=%COUNTRY%"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ تم إنشاء keystore بنجاح!
    echo.
    echo الآن قم بتحديث ملف android\key.properties بالمعلومات التالية:
    echo storePassword=%STORE_PASSWORD%
    echo keyPassword=%KEY_PASSWORD%
    echo keyAlias=%KEY_ALIAS%
    echo storeFile=upload-keystore.jks
    echo.
    echo احفظ هذه المعلومات في مكان آمن!
) else (
    echo ❌ فشل في إنشاء keystore
)

pause