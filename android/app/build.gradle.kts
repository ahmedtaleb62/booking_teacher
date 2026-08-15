import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Load signing properties from android/key.properties (never commit this file)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.hessati.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias     = keystoreProperties["keyAlias"]     as String
                keyPassword  = keystoreProperties["keyPassword"]  as String
                storeFile    = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        applicationId = "com.hessati.app"
        minSdk = 26  // jitsi_meet_flutter_sdk 13.x requires API 26+
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Jitsi SDK 13.x bundles its own react-native-video, which pulls in a copy of
// media3-exoplayer-rtsp that collides with the one video_player_android brings
// in. RTSP streaming isn't used anywhere in this app (lesson videos are plain
// HTTP files, calls go over WebRTC) — safe to drop from the classpath.
configurations.all {
    exclude(group = "androidx.media3", module = "media3-exoplayer-rtsp")
}

// Disable ART baseline profile merging — Gradle 8.14 never writes metadata.bin
// for the large React Native AAR that Jitsi SDK bundles (react-android-0.75.4)
afterEvaluate {
    tasks.matching { it.name.contains("ArtProfile") }.configureEach {
        enabled = false
    }
    // Skip AAR metadata check — consistently hangs/corrupts on Jitsi's react-android AAR
    tasks.matching { it.name.contains("checkRelease") && it.name.contains("AarMetadata") }.configureEach {
        enabled = false
    }
}
