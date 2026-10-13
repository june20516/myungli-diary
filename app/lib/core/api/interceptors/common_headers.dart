import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:myungli_diary/core/api/api_route.dart';
import 'package:myungli_diary/core/api/token_store.dart';

/// App Check 토큰을 내는 쪽입니다(Firebase 구현은 별도 task).
abstract interface class AppCheckTokenSource {
  /// 지금 쓸 App Check 토큰.
  Future<String> token();
}

/// 공통 헤더를 붙입니다.
///
/// * `Accept-Language`: access token이 없는 요청에만(bearer 요청은 프로필 언어).
/// * `X-Firebase-AppCheck`: 계약 `security`에 appCheck가 있는 operation에만
///   (생성된 `ApiRoute.requiresAppCheck`).
final class CommonHeadersInterceptor extends Interceptor {
  /// 헤더 interceptor를 만듭니다.
  new({required this.tokens, required this.appCheck, required this.locale});

  /// access token 유무를 보는 보관소.
  final TokenStore tokens;

  /// App Check 토큰 출처.
  final AppCheckTokenSource appCheck;

  /// 현재 앱 로케일.
  final Locale Function() locale;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      if (tokens.accessToken == null) {
        options.headers['Accept-Language'] = locale().languageCode;
      }
      final route = matchRoute(options.method, routePathOf(options));
      if (route?.requiresAppCheck ?? false) {
        options.headers['X-Firebase-AppCheck'] = await appCheck.token();
      }
    } on Object catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
        ),
      );
      return;
    }
    handler.next(options);
  }
}
