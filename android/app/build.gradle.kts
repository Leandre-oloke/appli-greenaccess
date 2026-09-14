plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.greenaccess.greenaccess"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.greenaccess.greenaccess"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Patrol E2E (J6.1, CDC §7.1) — minSdk 23 satisfait déjà le minimum
        // 21 requis par le package.
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }

    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")

            // R8 — tree-shaking du code Java/Kotlin et des dépendances natives
            isMinifyEnabled = true
            // Supprime les ressources Android non référencées
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // Packaging : exclure les fichiers inutiles dans l'APK
    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/*.kotlin_module",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Patrol E2E (J6.1) — ANDROIDX_TEST_ORCHESTRATOR ci-dessus isole chaque
    // test dans son propre process instrumenté.
    androidTestUtil("androidx.test:orchestrator:1.5.1")
}
