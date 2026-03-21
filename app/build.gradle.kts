plugins {
    alias(libs.plugins.android.application)
}
android {
    namespace = "com.assemblynativeactivity"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.assemblynativeactivity"
        minSdk = 24
        targetSdk = 35
        ndk {
            abiFilters += "arm64-v8a"
        }
        externalNativeBuild {
            cmake {
                arguments += "-DANDROID_STL=none"
            }
        }
    }
    externalNativeBuild {
        cmake {
            path = file("CMakeLists.txt")
            version = "4.0.2"
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    buildToolsVersion = "36.0.0"
    ndkVersion = "29.0.13113456"
}
