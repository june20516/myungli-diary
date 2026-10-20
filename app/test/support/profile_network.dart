import 'dart:async';

import 'package:dio/dio.dart';

/// 프로필 요청([method] [path])을 [gate]가 끝날 때까지 붙잡고, [failures]번은 503으로 답합니다.
///
/// 기본은 프로필 저장(PATCH)입니다. `method: 'GET'`이면 프로필 받기(`getProfile`)입니다.
/// 대역 서버 바로 앞에 끼웁니다(`pumpApp`의 `network`, 또는 dio interceptor 목록의 끝 바로 앞).
final class ProfileRequestGate extends Interceptor {
  /// [failures]번 실패하고 [gate]가 끝날 때까지 붙잡는 대역을 만듭니다.
  new({
    this.failures = 0,
    this.gate,
    this.method = 'PATCH',
    this.path = '/v1/me/profile',
  });

  /// 남은 실패 수. 0이면 그대로 대역 서버로 보냅니다.
  int failures;

  /// 끝날 때까지 요청을 붙잡습니다. null이면 붙잡지 않습니다.
  final Completer<void>? gate;

  /// 붙잡을 요청의 method.
  final String method;

  /// 붙잡을 요청의 경로.
  final String path;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.method != method || options.path != path) {
      handler.next(options);
      return;
    }
    await gate?.future;
    if (failures == 0) {
      handler.next(options);
      return;
    }
    failures--;
    handler.reject(
      DioException.badResponse(
        statusCode: 503,
        requestOptions: options,
        response: Response<Object?>(
          requestOptions: options,
          statusCode: 503,
          headers: Headers.fromMap({
            Headers.contentTypeHeader: ['application/problem+json'],
          }),
          data: {
            'status': 503,
            'code': 'service.unavailable',
            'title': 'x',
            'traceId': 't',
          },
        ),
      ),
      true,
    );
  }
}
