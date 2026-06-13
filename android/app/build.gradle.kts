plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")

    // Firebase / FCM
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.taskio"

    compileSdk = flutter.compileSdkVersion

    ndkVersion = "29.0.13113456"

    defaultConfig {
        applicationId = "com.example.taskio"

        // Для Firebase, Supabase и современных Android-уведомлений лучше явно 23
        minSdk = flutter.minSdkVersion

        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName

        multiDexEnabled = true
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
            // Для диплома/теста можно оставить debug-подпись.
            // Для публикации в Google Play потом нужно будет заменить на release signing.
            signingConfig = signingConfigs.getByName("debug")

            isMinifyEnabled = false
            isShrinkResources = false
        }

        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Поддержка Java 8+ API
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    // Нужен для multiDexEnabled
    implementation("androidx.multidex:multidex:2.0.1")
}
