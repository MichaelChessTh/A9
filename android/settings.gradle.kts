pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.4.2") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.1.10" apply false
    // Toolchain resolver: allows Gradle to auto-provision the JDK toolchain
    // required by plugins like flutter_callkit_incoming that need Java 17.
    id("org.gradle.toolchains.foojay-resolver-convention") version "0.9.0"
}

include(":app")
