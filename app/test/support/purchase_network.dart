import 'package:dio/dio.dart';

/// 연결 실패(오프라인).
DioException offlineFailure(RequestOptions options) =>
    DioException.connectionError(requestOptions: options, reason: '테스트 실패');

/// 500 problem 응답.
DioException serverFailure(RequestOptions options) => DioException.badResponse(
  statusCode: 500,
  requestOptions: options,
  response: Response<Object?>(
    requestOptions: options,
    statusCode: 500,
    headers: Headers.fromMap({
      Headers.contentTypeHeader: ['application/problem+json'],
    }),
    data: <String, Object?>{'status': 500, 'code': 'internal', 'traceId': 't'},
  ),
);

/// `listPurchases`를 처음 [failures]번 [make]한 오류로 실패시킵니다.
Interceptor listPurchasesFailing(
  int failures,
  DioException Function(RequestOptions) make,
) {
  var remaining = failures;
  return InterceptorsWrapper(
    onRequest: (options, handler) {
      if (options.path == '/v1/me/purchases' && remaining > 0) {
        remaining--;
        handler.reject(make(options), true);
      } else {
        handler.next(options);
      }
    },
  );
}

/// `restorePurchases`가 불린 뒤의 `getMe` 응답을 광고 제거 활성으로 바꿉니다.
Interceptor activeAfterRestore() {
  var restored = false;
  return InterceptorsWrapper(
    onRequest: (options, handler) {
      if (options.path == '/v1/billing/restore') {
        restored = true;
      }
      handler.next(options);
    },
    onResponse: (response, handler) {
      if (restored && response.requestOptions.path == '/v1/me') {
        (response.data! as Map<String, Object?>)['adFree'] = {
          'active': true,
          'expiresAt': '2026-11-12T03:00:00Z',
        };
      }
      handler.next(response);
    },
  );
}
