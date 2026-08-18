plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.hyperbudget.hyper_budget_flutter"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            val keystoreFile = file("${projectDir}/upload-keystore.jks")
            storeFile = keystoreFile
            // Passwords are read from local.properties (NOT hardcoded) to avoid leaking secrets.
            // Add these lines to android/local.properties:
            //   KEYSTORE_PASSWORD=your_store_password
            //   KEY_ALIAS=upload
            //   KEY_PASSWORD=your_key_password
            val localProps = java.util.Properties().apply {
                file("${projectDir}/local.properties").inputStream().use { load(it) }
            }
            storePassword = localProps.getProperty("KEYSTORE_PASSWORD")
            keyAlias = localProps.getProperty("KEY_ALIAS") ?: "upload"
            keyPassword = localProps.getProperty("KEY_PASSWORD")
        }
    }

    defaultConfig {
        applicationId = "com.hyperbudget.hyper_budget_flutter"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            isDebuggable = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
