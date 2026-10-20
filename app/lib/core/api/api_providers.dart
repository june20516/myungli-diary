import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/platform/app_check.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';

/// 통신 방식.
final apiModeProvider = Provider<ApiMode>((ref) => apiModeFromEnvironment());

/// server 주소.
final baseUrlProvider = Provider<Uri>((ref) => baseUrlFromEnvironment());

/// 기기 로케일(플랫폼 값). fake 모드 시작 코드와 테스트는 이 값을 덮습니다.
final deviceLocaleProvider = Provider<Locale>(
  (ref) => PlatformDispatcher.instance.locale,
);

/// 프로필 사본의 언어(`Profile.language`). 사본이 없으면 null입니다.
///
/// 기본은 null이고, 사본을 보는 연결은 조립 지점인 app 계층(`profileLanguageOverrides`)이
/// override로 더합니다. core가 feature를 알지 않게 하려는 것입니다
/// (`profileTimezoneProvider`와 같음).
final profileLanguageProvider = Provider<Language?>((ref) => null);

/// 앱 로케일(결정 A60): 프로필 사본의 언어, 사본이 없으면 기기 로케일입니다.
///
/// 국가 코드는 언어를 바꿔도 기기 값을 둡니다. 기기 지역 판정(D29·D58,
/// `deviceRegionIsKoreaProvider`)이 앱 언어가 아니라 기기 지역을 따르게 하려는 것입니다.
final localeProvider = Provider<Locale>((ref) {
  final device = ref.watch(deviceLocaleProvider);
  final language = ref.watch(profileLanguageProvider);
  if (language == null) {
    return device;
  }
  return Locale(language.value, device.countryCode);
});

/// 보안 저장소.
final secureStoreProvider = Provider<SecureStore>(
  (ref) => const FlutterSecureStore(),
);

/// 토큰 보관소.
final tokenStoreProvider = Provider<TokenStore>((ref) {
  final store = TokenStore(ref.watch(secureStoreProvider));
  ref.onDispose(store.dispose);
  return store;
});

/// App Check. 기본은 대역이고, Firebase adapter는 override로 끼웁니다.
final appCheckProvider = Provider<AppCheck>((ref) => const FakeAppCheck());

/// 대역 서버 interceptor. fake 모드에서만 쓰며 대역 서버 task가 override합니다.
final fakeServerProvider = Provider<Interceptor?>((ref) => null);

/// 모든 요청이 거치는 Dio.
final dioProvider = Provider<Dio>((ref) {
  final dio = buildDio(
    mode: ref.watch(apiModeProvider),
    baseUrl: ref.watch(baseUrlProvider),
    tokens: ref.watch(tokenStoreProvider),
    appCheck: ref.watch(appCheckProvider),
    locale: () => ref.read(localeProvider),
    fakeServer: ref.watch(fakeServerProvider),
  );
  ref.onDispose(dio.close);
  return dio;
});

/// 생성 REST 클라이언트.
final restClientProvider = Provider<DefaultApi>(
  (ref) => DefaultApi(ref.watch(dioProvider)),
);
