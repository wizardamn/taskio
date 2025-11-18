plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.taskio"

    // Используем переменную из Flutter для компиляции
    compileSdk = flutter.compileSdkVersion

    // Рекомендуемая стабильная версия NDK
    ndkVersion = "29.0.13113456"

    defaultConfig {
        applicationId = "com.example.taskio"
        minSdk = 23 // Требование Firebase/Supabase
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        getByName("release") {
            // В релизе обычно не используется debug-подпись, но оставлю как было
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Для поддержки Java 8+ API (desugaring)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}