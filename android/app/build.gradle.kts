import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun dartDefine(key: String): String? {
    val encodedDefines = project.findProperty("dart-defines") as String? ?: return null
    return encodedDefines
        .split(",")
        .asSequence()
        .mapNotNull { encoded ->
            runCatching {
                String(Base64.getDecoder().decode(encoded))
            }.getOrNull()
        }
        .mapNotNull { decoded ->
            val separatorIndex = decoded.indexOf("=")
            if (separatorIndex == -1) {
                null
            } else {
                decoded.substring(0, separatorIndex) to decoded.substring(separatorIndex + 1)
            }
        }
        .firstOrNull { (name, _) -> name == key }
        ?.second
        ?.takeIf { it.isNotBlank() }
}

val adMobAppId =
    dartDefine("ADMOB_ANDROID_APP_ID") ?: "ca-app-pub-3940256099942544~3347511713"

val keystoreProperties = java.util.Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.lumacraft.studio"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            val storeFileProperty = keystoreProperties["storeFile"] as String?
            storeFile = storeFileProperty?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.lumacraft.studio"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["ADMOB_APP_ID"] = adMobAppId
    }

    buildTypes {
        release {
            // Signing with the release keys.
            signingConfig = signingConfigs.getByName("release")

            // Disable R8 shrinking to preserve Flutter plugin Pigeon channels.
            // Flutter plugins use Pigeon-generated platform channels that R8
            // strips as "unused" because they are registered reflectively.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

