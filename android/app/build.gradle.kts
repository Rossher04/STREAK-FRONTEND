import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de subida: android/key.properties (NO se versiona; ver key.properties.example).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.streak.streak_mobile"
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
        applicationId = "com.streak.quinielas"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // versionCode y versionName salen de `version: 1.0.0+1` en pubspec.yaml.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Un build de release sin firma no debe producir un paquete inservible: falla con un mensaje claro.
gradle.taskGraph.whenReady {
    val esRelease = allTasks.any {
        it.project == project &&
            it.name.contains("Release") &&
            (it.name.startsWith("assemble") || it.name.startsWith("bundle") || it.name.startsWith("package"))
    }
    if (esRelease) {
        // Flutter pasa los --dart-define como base64("CLAVE=valor") separados por comas.
        val defines = (project.findProperty("dart-defines") as String?)
            ?.split(",")
            ?.mapNotNull { runCatching { String(Base64.getDecoder().decode(it)) }.getOrNull() }
            ?.filter { it.contains("=") }
            ?.associate { it.substringBefore("=") to it.substringAfter("=") }
            ?: emptyMap()
        val correo = defines["SUPPORT_EMAIL"].orEmpty().trim()
        if (correo.isEmpty() || correo.contains("[") || !correo.contains("@")) {
            throw GradleException(
                "Falta --dart-define=SUPPORT_EMAIL=<correo-de-soporte> (o es un marcador). " +
                    "La app lo muestra al pedir la eliminación de cuenta y Play lo exige.",
            )
        }
        if (!defines["API_BASE_URL"].orEmpty().startsWith("https://")) {
            throw GradleException(
                "Falta --dart-define=API_BASE_URL=https://<tu-backend>/api (sin él, un release apuntaría al backend local).",
            )
        }
        if (!keystorePropertiesFile.exists()) {
            throw GradleException(
                "Falta android/key.properties. Copia android/key.properties.example a " +
                    "android/key.properties y completa storePassword, keyPassword, keyAlias y storeFile " +
                    "con los datos REALES de tu keystore de subida (no se versiona).",
            )
        }
        val faltantes = listOf("storePassword", "keyPassword", "keyAlias", "storeFile")
            .filter { keystoreProperties.getProperty(it).isNullOrBlank() || keystoreProperties.getProperty(it) == "CAMBIAR" }
        if (faltantes.isNotEmpty()) {
            throw GradleException("android/key.properties está incompleto o con valores de ejemplo: ${faltantes.joinToString()}")
        }
        val almacen = file(keystoreProperties.getProperty("storeFile"))
        if (!almacen.exists()) {
            throw GradleException("No existe el keystore indicado en key.properties (storeFile): ${almacen.absolutePath}")
        }
    }
}

flutter {
    source = "../.."
}
