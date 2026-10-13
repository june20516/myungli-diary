import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:myungli_diary/core/api/interceptors/auth.dart';
import 'package:myungli_diary/core/api/interceptors/common_headers.dart';
import 'package:myungli_diary/core/api/token_store.dart';

export 'package:myungli_diary/core/api/interceptors/common_headers.dart'
    show AppCheckTokenSource;

/// 통신 방식. `fake`는 대역 서버(fixture), `http`는 실제 server입니다.
enum ApiMode {
  /// 대역 서버.
  fake,

  /// 실제 HTTP.
  http,
}

/// `API_MODE` dart-define(`fake`|`http`, 기본 `http`)을 읽습니다.
///
/// release 빌드에서 `fake`면 [StateError]입니다. 값을 바꿔 끼울 수 있게
/// 인자로 받으며, 기본값이 실제 환경입니다.
ApiMode apiModeFromEnvironment({
  String value = const String.fromEnvironment('API_MODE', defaultValue: 'http'),
  bool isRelease = kReleaseMode,
}) {
  final mode = switch (value) {
    'fake' => ApiMode.fake,
    'http' => ApiMode.http,
    _ => throw StateError('API_MODE는 fake 또는 http여야 합니다: $value'),
  };
  if (isRelease && mode == ApiMode.fake) {
    throw StateError('release 빌드에서는 API_MODE=fake를 쓸 수 없습니다.');
  }
  return mode;
}

/// 멱등 요청 헤더(`Idempotency-Key`)를 붙이는 옵션.
Options idempotent(String key) => Options(headers: {'Idempotency-Key': key});

/// 모든 server 요청이 거치는 [Dio]를 만듭니다.
///
/// interceptor 순서: 공통 헤더 → 인증 → 대역([ApiMode.fake]일 때만).
Dio buildDio({
  required ApiMode mode,
  required Uri baseUrl,
  required TokenStore tokens,
  required AppCheckTokenSource appCheck,
  required Locale Function() locale,
  Interceptor? fakeServer,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl.toString(),
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  dio.interceptors.addAll([
    CommonHeadersInterceptor(
      tokens: tokens,
      appCheck: appCheck,
      locale: locale,
    ),
    AuthInterceptor(dio: dio, tokens: tokens),
  ]);
  if (mode == ApiMode.fake) {
    if (fakeServer == null) {
      throw StateError('API_MODE=fake에는 fakeServer가 필요합니다.');
    }
    dio.interceptors.add(fakeServer);
  }
  return dio;
}
