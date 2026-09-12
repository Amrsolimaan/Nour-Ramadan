import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.NourRamadan"
    compileSdk = 36 // مستقر
    ndkVersion = "27.2.12479018"

    compileOptions {
        // في Kotlin DSL نستخدم isCoreLibraryDesugaringEnabled
        isCoreLibraryDesugaringEnabled = true
        
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    defaultConfig {
        applicationId = "com.NourRamadan"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        getByName("release") {
            // استخدام keystore الصحيح للإصدار
            signingConfig = signingConfigs.getByName("release")
            
            // ✅ تفعيل R8 Shrinking & Obfuscation
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            // ✅ Fix: Disable native library stripping completely
            ndk {
                debugSymbolLevel = "NONE"
            }
        }
    }
    
    packaging {
        jniLibs {
            useLegacyPackaging = true
            keepDebugSymbols += "**/*.so"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // قم بتغيير 2.0.3 إلى 2.1.4 أو 2.1.5 (الأحدث والأضمن)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("androidx.appcompat:appcompat:1.6.1")

    // ✅ PHASE 2: مكتبة adhan لحساب أوقات الصلاة ذاتياً في Kotlin
    implementation("com.batoulapps.adhan:adhan:1.2.1")

    // ✅ المرحلة 2 (تدقيق): اختبار JVM صِرف لمنطق AlarmScheduler الخالي
    // من Context/AlarmManager — لا يحتاج Robolectric أو جهاز/محاكي.
    testImplementation("junit:junit:4.13.2")
}