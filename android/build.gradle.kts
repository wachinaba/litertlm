plugins {
    id("com.android.library")
}

group = "org.rockstudio.litertlm"
version = "1.0-SNAPSHOT"

val prefixCacheAar = file("libs/litertlm-android-prefix-cache.aar")
val extractedPrefixCacheAar = layout.buildDirectory.dir("prefix-cache-aar")
val extractPrefixCacheAar =
    if (prefixCacheAar.exists()) {
        tasks.register<Sync>("extractPrefixCacheAar") {
            from(zipTree(prefixCacheAar)) {
                include("classes.jar", "jni/**")
            }
            into(extractedPrefixCacheAar)
        }
    } else {
        null
    }

android {
    namespace = "org.rockstudio.litertlm"
    compileSdk = 36

    defaultConfig {
        minSdk = 23
        consumerProguardFiles("consumer-rules.pro")

        externalNativeBuild {
            cmake {
                arguments += "-DANDROID_STL=c++_shared"
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    if (prefixCacheAar.exists()) {
        sourceSets.getByName("main").jniLibs.srcDir(
            extractedPrefixCacheAar.map { it.dir("jni") },
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

extractPrefixCacheAar?.let { extractTask ->
    tasks.named("preBuild").configure {
        dependsOn(extractTask)
    }
}

dependencies {
    if (prefixCacheAar.exists()) {
        implementation(
            files(extractedPrefixCacheAar.map { it.file("classes.jar") }),
        )
        implementation("com.google.code.gson:gson:2.13.2")
        implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    } else {
        implementation("com.google.ai.edge.litertlm:litertlm-android:0.16.1")
    }
}
