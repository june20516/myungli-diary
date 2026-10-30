// config/auth.json(A81)에서 iOS 빌드 설정(ios/Flutter/Auth.xcconfig)을 만드는 순수 함수입니다.
// 도구(tool/gen_native_config.dart)와 계약 테스트가 함께 씁니다.

import 'dart:convert';
import 'dart:io';

/// 로그인 제공자 공개 식별자 파일(app 기준 경로).
const authConfigPath = 'config/auth.json';

/// 환경(staging, prod)마다 다른 값 파일(app 기준 경로, A97). 실행·빌드 명령에
/// `config/auth.json` 다음에 `--dart-define-from-file`로 붙입니다.
String envConfigPath(String env) => 'config/env/$env.json';

/// `config/auth.json`의 키: 환경과 상관없는 로그인 제공자 공개 식별자(A81).
const providerIdentifierKeys = {
  'KAKAO_NATIVE_APP_KEY',
  'LINE_CHANNEL_ID',
  'GOOGLE_IOS_CLIENT_ID',
  'GOOGLE_SERVER_CLIENT_ID',
  'APPLE_SERVICES_ID',
};

/// 환경 파일의 키: server 주소와 그 주소를 따르는 값(A97).
const environmentKeys = {
  'API_BASE_URL',
  'FIREBASE_ENV',
  'APP_LINK_HOST',
  'APPLE_REDIRECT_URI',
};

/// 생성하는 iOS 빌드 설정 파일(app 기준 경로).
const authXcconfigPath = 'ios/Flutter/Auth.xcconfig';

/// Google iOS client id가 비었을 때 넣는 URL scheme. 어떤 복귀 링크와도 맞지 않습니다.
const _googleUnconfigured = 'google-unconfigured';

/// 카카오 앱 키가 비었을 때 넣는 값. URL scheme이 Android와 같은 `kakao-unconfigured`가
/// 되어 어떤 복귀 링크와도 맞지 않습니다.
const _kakaoUnconfigured = '-unconfigured';

const _googleClientSuffix = '.apps.googleusercontent.com';

/// [file](auth.json)을 읽어 키 → 값으로 돌려줍니다. 값은 모두 문자열이어야 합니다.
Map<String, String> readAuthConfigJson(File file) {
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw FormatException('${file.path}는 JSON 객체여야 합니다');
  }
  return {
    for (final MapEntry(:key, :value) in decoded.entries)
      if (value is String)
        key: value
      else
        key: throw FormatException('${file.path}의 $key 값은 문자열이어야 합니다'),
  };
}

/// Google iOS client id([iosClientId])의 reversed client id(iOS URL scheme).
///
/// `123-abc.apps.googleusercontent.com` →
/// `com.googleusercontent.apps.123-abc`. 비면 `google-unconfigured`입니다.
String googleReversedClientId(String iosClientId) {
  final id = iosClientId.trim();
  if (id.isEmpty) return _googleUnconfigured;
  final prefix = id.endsWith(_googleClientSuffix)
      ? id.substring(0, id.length - _googleClientSuffix.length)
      : id;
  return 'com.googleusercontent.apps.$prefix';
}

/// [config]로 `Auth.xcconfig` 내용을 만듭니다. Info.plist URL scheme은
/// `kakao$(KAKAO_NATIVE_APP_KEY)`와 `$(GOOGLE_REVERSED_CLIENT_ID)`입니다.
String renderAuthXcconfig(Map<String, String> config) {
  final key = (config['KAKAO_NATIVE_APP_KEY'] ?? '').trim();
  final kakaoKey = key.isEmpty ? _kakaoUnconfigured : key;
  final reversed = googleReversedClientId(config['GOOGLE_IOS_CLIENT_ID'] ?? '');
  return '// 생성 코드: dart run tool/gen_native_config.dart. 손으로 고치지 않습니다.\n'
      '// 출처: config/auth.json(결정 A81)\n'
      'KAKAO_NATIVE_APP_KEY=$kakaoKey\n'
      'GOOGLE_REVERSED_CLIENT_ID=$reversed\n';
}
