plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
val releaseKeyAlias = System.getenv("ANDROID_KEY_ALIAS")
val releaseKeyPassword = System.getenv("ANDROID_KEY_PASSWORD")
val releaseStorePassword = System.getenv("ANDROID_STORE_PASSWORD")
val hasReleaseSigning = listOf(
    releaseKeystorePath,
    releaseKeyAlias,
    releaseKeyPassword,
    releaseStorePassword,
).all { !it.isNullOrBlank() }

android {
    namespace = "de.kaufmann.sitzplan"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "de.kaufmann.sitzplan"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseKeystorePath!!)
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storePassword = releaseStorePassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // Keeps local release builds convenient. GitHub Actions requires
                // stable signing secrets before publishing an APK.
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core:1.19.0")
}
