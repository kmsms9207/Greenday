plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_application_1"
    compileSdk = flutter.compileSdkVersion
    
    // 1. NDK 버전을 Firebase 플러그인이 요구하는 버전으로 명시적으로 지정합니다.
    ndkVersion = "27.0.12077973" 

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // defaultConfig 블록은 sourceSets 블록 위 또는 아래 등 android { } 내부에 있으면 됩니다.
    // 위치는 크게 중요하지 않습니다.
    defaultConfig {
        applicationId = "com.example.flutter_application_1"
        // 2. minSdkVersion을 flutter.minSdkVersion 대신 23으로 직접 지정합니다.
        minSdkVersion(23) 
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// 3. dependencies 블록이 없다면 추가하고, 있다면 내용을 확인합니다.
//    google-services 플러그인을 사용하려면 firebase-bom 의존성이 필요합니다.
dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.1.2")) // 최신 버전 확인 권장
    // implementation("com.google.firebase:firebase-analytics") // 필요한 다른 Firebase 라이브러리 추가
}
