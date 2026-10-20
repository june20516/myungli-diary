import 'dart:async';

import 'package:dio/dio.dart';

/// [options] 요청을 503 `service.unavailable` problem 응답으로 끊는 오류.
DioException serviceUnavailable(RequestOptions options) =>
    DioException.badResponse(
      statusCode: 503,
      requestOptions: options,
      response: Response<Object?>(
        requestOptions: options,
        statusCode: 503,
        data: {
          'type': 'about:blank',
          'title': 'Unavailable',
          'status': 503,
          'code': 'service.unavailable',
          'traceId': 'test',
        },
        headers: Headers.fromMap({
          Headers.contentTypeHeader: ['application/problem+json'],
        }),
      ),
    );

/// 나의 사주(`/v1/chart`) 요청 대역. 대역 서버 바로 앞에 끼웁니다.
///
/// 요청 수를 [requests]로 세고, [hold]면 [gate]가 끝날 때까지 붙잡고(끝내지 않으면 계속 받는 중),
/// [fail]이면 503으로 답합니다.
final class ChartNetwork extends Interceptor {
  /// 요청을 붙잡을지.
  bool hold = false;

  /// 503으로 답할지.
  bool fail = false;

  /// 지금까지 받은 요청 수.
  int requests = 0;

  /// [hold]가 풀리는 시점.
  final Completer<void> gate = Completer<void>();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.path != '/v1/chart') {
      handler.next(options);
      return;
    }
    requests++;
    if (hold) await gate.future;
    if (fail) {
      handler.reject(serviceUnavailable(options), true);
      return;
    }
    handler.next(options);
  }
}
