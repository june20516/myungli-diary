import 'package:dio/dio.dart';

/// 반응 PUT을 404 `reaction.not_found` problem으로 거절하는 대역.
///
/// 다른 테스트들(`_DailyHold` 등)처럼 `dio.interceptors`의 맨 끝(대역 서버) 바로 앞에 끼워
/// 대역 서버보다 먼저 요청을 받게 합니다.
final class ReactionNotFoundInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method != 'PUT' || !options.path.contains('/reaction')) {
      handler.next(options);
      return;
    }
    handler.reject(
      DioException.badResponse(
        statusCode: 404,
        requestOptions: options,
        response: Response<Object?>(
          requestOptions: options,
          statusCode: 404,
          data: {
            'type': 'about:blank',
            'title': 'Not found',
            'status': 404,
            'code': 'reaction.not_found',
            'traceId': 'test',
          },
          headers: Headers.fromMap({
            Headers.contentTypeHeader: ['application/problem+json'],
          }),
        ),
      ),
      true,
    );
  }
}
