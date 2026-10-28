// Firebase 프로젝트 `myungli-diary-staging`(staging)의 앱 설정입니다(결정 A93).
// 값은 `firebase apps:sdkconfig`로 받은 공개 값이고 앱 바이너리에 그대로 들어갑니다.
// 네이티브 설정 파일(google-services.json, GoogleService-Info.plist)은 쓰지 않고
// Dart에서 초기화합니다.

import 'package:firebase_core/firebase_core.dart';

/// staging Android 앱.
const FirebaseOptions firebaseStagingAndroid = FirebaseOptions(
  apiKey: 'AIzaSyDXCzseswwtFPNiKEN4bh-YFXqpxteAw_U',
  appId: '1:1056563158649:android:aaa25cb08a8f754db03ea8',
  messagingSenderId: '1056563158649',
  projectId: 'myungli-diary-staging',
  storageBucket: 'myungli-diary-staging.firebasestorage.app',
);

/// staging iOS 앱.
const FirebaseOptions firebaseStagingIos = FirebaseOptions(
  apiKey: 'AIzaSyDHfl7dUfrOEjQ2R7YbtjV1FegsCTxNdKQ',
  appId: '1:1056563158649:ios:d84bab9d85d4c603b03ea8',
  messagingSenderId: '1056563158649',
  projectId: 'myungli-diary-staging',
  storageBucket: 'myungli-diary-staging.firebasestorage.app',
  iosBundleId: 'app.myungli.diary',
);
