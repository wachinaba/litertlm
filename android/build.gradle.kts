plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

group = "org.rockstudio.litertlm"
version = "1.0-SNAPSHOT"

android {
    namespace = "org.rockstudio.litertlm"
    compileSdk = 36

    defaultConfig {
        minSdk = 23
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("com.google.ai.edge.litertlm:litertlm-android:0.13.0")
}