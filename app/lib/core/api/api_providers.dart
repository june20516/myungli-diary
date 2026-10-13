import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/api/token_store.dart';
import 'package:myungli_diary/core/storage/secure_store.dart';

/// 통신 방식.
final apiModeProvider = Provider<ApiMode>((ref) => apiModeFromEnvironment());

/// server 주소.
final baseUrlProvider = Provider<Uri>(
  (ref) => Uri.parse(
    const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    ),
  ),
);

/// 앱 로케일. 앱이 사용자 설정으로 덮어씁니다.
final localeProvider = Provider<Locale>(
  (ref) => PlatformDispatcher.instance.locale,
);

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

/// App Check 토큰 출처. Firebase 연동 전까지는 override해야 합니다.
final appCheckProvider = Provider<AppCheckTokenSource>(
  (ref) => throw UnimplementedError('appCheckProvider를 override하세요.'),
);

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
