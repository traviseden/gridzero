import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// Keep key material and passwords local. Relative storeFile paths are relative
// to android/, not app/. No fallback to a debug key for Release builds.
val signingFile = rootProject.file("Signing.local.properties")
val privateSigning = Properties().apply {
    if (signingFile.exists()) signingFile.inputStream().use { load(it) }
}
if (signingFile.exists()) {
    for (key in listOf("storeFile", "storePassword", "keyAlias", "keyPassword")) {
        require(!privateSigning.getProperty(key).isNullOrBlank()) {
            "Missing $key in android/Signing.local.properties"
        }
    }
    require(rootProject.file(privateSigning.getProperty("storeFile")).isFile) {
        "Signing keystore not found; check storeFile in android/Signing.local.properties"
    }
}

android {
    namespace = "win.gridzero.android"
    compileSdk = 36
    defaultConfig {
        applicationId = "win.gridzero.android"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    signingConfigs {
        if (signingFile.exists()) {
            create("localRelease") {
                storeFile = rootProject.file(privateSigning.getProperty("storeFile"))
                storePassword = privateSigning.getProperty("storePassword")
                keyAlias = privateSigning.getProperty("keyAlias")
                keyPassword = privateSigning.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            // Without local signing, Gradle can compile an unsigned release for
            // CI. tools/android.sh refuses to ship it to a phone.
            if (signingFile.exists()) signingConfig = signingConfigs.getByName("localRelease")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    sourceSets.getByName("main").assets.srcDir(rootProject.file("../Sources/GridZeroCore/Resources"))
    testOptions { unitTests.isReturnDefaultValues = true }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test:core:1.6.1")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
}
