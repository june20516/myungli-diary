import 'package:dio/dio.dart';

/// 반응 PUT을 404 `reaction.not_found` problem으로 거절하는 대역.
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
