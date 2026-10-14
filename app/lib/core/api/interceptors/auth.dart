import 'dart:async';

import 'package:dio/dio.dart';
import 'package:myungli_diary/core/api/api_route.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/refresh_request.dart';
import 'package:myungli_diary/core/api/token_store.dart';

/// 요청 extra: 이 요청은 인증 interceptor를 건너뜁니다(refresh 자체, 무한 루프 방지).
const skipAuthExtra = 'skipAuth';

/// 요청 extra: bearer는 붙이되 refresh·재시도·로그아웃 처리는 하지 않습니다.
///
/// 새 로그인이 이전 세션의 refresh token을 폐기하는 요청처럼, 실패해도 로컬 세션을 건드리면
/// 안 되는 요청에 씁니다.
const skipAuthRecoveryExtra = 'skipAuthRecovery';

/// 요청 extra: 이미 한 번 다시 보낸 요청입니다.
const _retriedExtra = 'authRetried';

const _tokenExpiredCode = 'auth.token_expired';
const _refreshReusedCode = 'auth.refresh_reused';
const _consentRequiredCode = 'consent.required';

/// bearer를 붙이고, 401 `auth.token_expired`면 refresh 후 원 요청을 한 번 다시 보냅니다.
///
/// 403 `consent.required`면 [AuthEvent.consentRequired]를 알리고 원 요청은 그 오류로 끝냅니다.
/// 그 밖(5xx, `auth.provider_unavailable` 포함)은 로그아웃하지 않고 그대로 돌려줍니다.
///
/// refresh는 진행 중인 Future를 공유해 동시에 한 번만 보냅니다.
/// `QueuedInterceptor`는 401이 아닌 요청까지 줄 세우므로 쓰지 않습니다.
final class AuthInterceptor extends Interceptor {
  /// [dio]는 재시도와 refresh 요청을 보내는 같은 인스턴스입니다.
  new({required this.dio, required this.tokens});

  /// 재시도·refresh에 쓰는 Dio.
  final Dio dio;

  /// 토큰 보관소.
  final TokenStore tokens;

  Future<DioException?>? _inflightRefresh;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthExtra] == true) {
      handler.next(options);
      return;
    }
    // 앱을 다시 실행한 직후: access token은 없고 refresh token만 있습니다.
    if (options.extra[skipAuthRecoveryExtra] != true &&
        tokens.accessToken == null &&
        _requiresBearer(options) &&
        await tokens.refreshToken() != null &&
        // 읽는 사이 다른 요청의 refresh가 끝났을 수 있습니다.
        tokens.accessToken == null) {
      final failure = await (_inflightRefresh ??= _refresh());
      if (failure != null) {
        handler.reject(failure.copyWith(requestOptions: options));
        return;
      }
    }
    final accessToken = tokens.accessToken;
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    } else {
      options.headers.remove('Authorization');
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode == 403 &&
        _problemCodeOf(err) == _consentRequiredCode) {
      tokens.notifyConsentRequired();
      handler.next(err);
      return;
    }
    final currentToken = tokens.accessToken;
    if (err.response?.statusCode != 401 ||
        options.extra[skipAuthExtra] == true ||
        options.extra[skipAuthRecoveryExtra] == true ||
        options.extra[_retriedExtra] == true ||
        _problemCodeOf(err) != _tokenExpiredCode ||
        // 로그아웃된 뒤 늦게 온 401은 다시 보내지 않습니다.
        currentToken == null) {
      handler.next(err);
      return;
    }

    // 다른 요청의 refresh가 이미 끝났다면 새 토큰으로 다시 보내기만 합니다.
    if (_bearerOf(options) == currentToken) {
      final failure = await (_inflightRefresh ??= _refresh());
      if (failure != null) {
        handler.reject(failure.copyWith(requestOptions: options));
        return;
      }
    }
    await _retry(options, handler);
  }

  Future<void> _retry(
    RequestOptions options,
    ErrorInterceptorHandler handler,
  ) async {
    options.extra[_retriedExtra] = true;
    try {
      handler.resolve(await dio.fetch<Object?>(options));
    } on DioException catch (e) {
      handler.reject(e);
    }
  }

  /// refresh를 한 번 보냅니다. 성공이면 null, 실패면 원 요청에 돌려줄 오류입니다.
  Future<DioException?> _refresh() async {
    try {
      final refreshToken = await tokens.refreshToken();
      if (refreshToken == null) {
        await tokens.signOut();
        return _unauthorized();
      }
      final response = await DefaultApi(dio).refreshToken(
        refreshRequest: RefreshRequest(refreshToken: refreshToken),
        extra: {skipAuthExtra: true},
      );
      final pair = response.data;
      if (pair == null) {
        return DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'refresh 응답 본문이 없습니다.',
        );
      }
      await tokens.save(pair);
      return null;
    } on DioException catch (e) {
      // 거부(401·재사용)일 때만 로그아웃합니다. 네트워크·시간 초과·5xx는
      // refresh token을 남기고 그 오류를 그대로 돌려줍니다.
      if (e.response?.statusCode == 401 ||
          _problemCodeOf(e) == _refreshReusedCode) {
        await tokens.signOut();
      }
      return e;
    } finally {
      _inflightRefresh = null;
    }
  }

  /// refresh token이 없을 때 돌려주는 401 problem 오류.
  DioException _unauthorized() {
    final requestOptions = RequestOptions(path: '/v1/auth/refresh');
    return DioException.badResponse(
      statusCode: 401,
      requestOptions: requestOptions,
      response: Response<Object?>(
        requestOptions: requestOptions,
        statusCode: 401,
        headers: Headers.fromMap({
          Headers.contentTypeHeader: ['application/problem+json'],
        }),
        data: {
          'status': 401,
          'code': 'auth.refresh_missing',
          'title': 'refresh token이 없습니다.',
        },
      ),
    );
  }

  /// 계약상 bearer가 필요한 operation인지(`security`에 bearerAuth).
  bool _requiresBearer(RequestOptions options) {
    // 계약에 없는 경로는 안전하게 bearer가 필요하다고 봅니다.
    return matchRoute(options.method, routePathOf(options))?.requiresBearer ??
        true;
  }

  String? _bearerOf(RequestOptions options) {
    final header = options.headers['Authorization'];
    if (header is String && header.startsWith('Bearer ')) {
      return header.substring('Bearer '.length);
    }
    return null;
  }

  String? _problemCodeOf(DioException e) {
    final error = appErrorFrom(e);
    return error is ProblemError ? error.code : null;
  }
}
