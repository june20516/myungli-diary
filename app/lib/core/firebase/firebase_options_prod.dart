// Firebase 프로젝트 `myungli-diary`(prod)의 앱 설정입니다(결정 A93).
// 값은 `firebase apps:sdkconfig`로 받은 공개 값이고 앱 바이너리에 그대로 들어갑니다.
// 네이티브 설정 파일(google-services.json, GoogleService-Info.plist)은 쓰지 않고
// Dart에서 초기화합니다.

import 'package:firebase_core/firebase_core.dart';

/// prod Android 앱.
const FirebaseOptions firebaseProdAndroid = FirebaseOptions(
  apiKey: 'AIzaSyBUZkUOgB8K7NfYVKWW-Z_qO0AnFm_Jj4A',
  appId: '1:21526308173:android:dd6fe025dc59b0753a4304',
  messagingSenderId: '21526308173',
  projectId: 'myungli-diary',
  storageBucket: 'myungli-diary.firebasestorage.app',
);

/// prod iOS 앱.
const FirebaseOptions firebaseProdIos = FirebaseOptions(
  apiKey: 'AIzaSyBf8kXKaZyuzsLcr27l--0sPg9ctraSjdc',
  appId: '1:21526308173:ios:5ef83ecb38d4c7ca3a4304',
  messagingSenderId: '21526308173',
  projectId: 'myungli-diary',
  storageBucket: 'myungli-diary.firebasestorage.app',
  iosBundleId: 'app.myungli.diary',
);
