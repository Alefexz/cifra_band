import java.util.Properties

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

// Keep secrets outside the repo; invalid Play configuration must not block direct.
val playKeys = Properties()
val playKeysPath = System.getenv("CIFRABAND_PLAY_KEY_PROPERTIES")
val playKeyLoad = runCatching {
    require(!playKeysPath.isNullOrBlank()) { "Set CIFRABAND_PLAY_KEY_PROPERTIES to your external properties file." }
    file(playKeysPath!!).inputStream().use { playKeys.load(it) }
    for (name in listOf("storeFile", "storePassword", "keyAlias", "keyPassword")) {
        require(!playKeys.getProperty(name).isNullOrBlank()) { "Missing Play signing property: $name" }
    }
    require(file(playKeys.getProperty("storeFile")).isFile) { "Play upload keystore not found." }
}
val unsignedPlayTest = providers.gradleProperty("allowUnsignedPlayTest").orNull == "true" ||
    System.getenv("CIFRABAND_UNSIGNED_PLAY_TEST") == "true"

android {
    namespace = "br.com.cifraband.cifra_band"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true 
    }

    // Atualizado para a sintaxe nova do Kotlin, removendo o aviso amarelo!
    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "br.com.cifraband.cifra_band"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "distribution"
    signingConfigs {
        if (playKeyLoad.isSuccess && !unsignedPlayTest) {
            create("playUpload") {
                storeFile = file(playKeys.getProperty("storeFile"))
                storePassword = playKeys.getProperty("storePassword")
                keyAlias = playKeys.getProperty("keyAlias")
                keyPassword = playKeys.getProperty("keyPassword")
            }
        }
    }
    productFlavors {
        create("direct") {
            dimension = "distribution"
            signingConfig = signingConfigs.getByName("debug")
        }
        create("play") {
            dimension = "distribution"
            if (playKeyLoad.isSuccess && !unsignedPlayTest) {
                signingConfig = signingConfigs.getByName("playUpload")
            }
        }
    }
    buildTypes {
        release {
            // Flavor-specific signing. Play never inherits the direct beta key.
            signingConfig = null
        }
    }
}

// Native-assets CMake tasks can otherwise share pre-build dependencies between
// flavors. An explicitly selected channel configures only its own variants.
val requestedTasks = gradle.startParameter.taskNames.joinToString(" ").lowercase()
val directRequested = requestedTasks.contains("direct")
val playRequested = requestedTasks.contains("play")
androidComponents {
    beforeVariants(selector().all()) { variant ->
        val channel = variant.productFlavors.firstOrNull { it.first == "distribution" }?.second
        if (directRequested && !playRequested && channel == "play") variant.enable = false
        if (playRequested && !directRequested && channel == "direct") variant.enable = false
    }
}

gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name in listOf("packagePlayRelease", "packagePlayReleaseBundle", "signPlayReleaseBundle") }) {
        if (unsignedPlayTest) {
            logger.warn("UNSIGNED PLAY TEST ARTIFACT: inspection only, not publishable.")
        } else if (playKeyLoad.isFailure) {
            throw GradleException("Play release signing is not configured. See docs/PLAY_SIGNING.md. " +
                playKeyLoad.exceptionOrNull()?.message)
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    "playImplementation"("com.google.android.play:app-update:2.1.0")
    // ⚠️ A CORREÇÃO: Atualizado para a versão 2.1.4 exigida pelas notificações
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.core:core-ktx:1.17.0")
}
