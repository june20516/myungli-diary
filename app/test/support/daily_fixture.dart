import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

/// member 시나리오의 `getDaily` 응답 본문. fixture와 테스트가 같은 값을 보게 합니다.
Map<String, dynamic> memberDailyJson() {
  final fixture = jsonDecode(
    File('fixtures/member/getDaily.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return fixture['body'] as Map<String, dynamic>;
}

/// `/v1/daily/{date}`만 답하는 대역 서버. 대역 서버(fixture) 없이 Dio 하나로 쓸 때 씁니다.
///
/// 요청 경로를 [paths]에 남기고, [offline]이면 연결 오류로, 아니면 [body]로 답합니다.
/// [hold]가 있으면 그것이 끝날 때까지 응답을 붙잡습니다.
final class ScriptedDailyServer extends Interceptor {
  /// 받은 요청 경로.
  final paths = <String>[];

  /// true면 연결 오류로 끊습니다.
  bool offline = false;

  /// 응답 본문.
  final Map<String, dynamic> body = memberDailyJson();

  /// 설정되어 있으면 이 Future가 끝날 때까지 응답하지 않습니다.
  Completer<void>? hold;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 반응(`/slots/…/reaction`) 같은 다른 요청은 대역 서버로 보냅니다.
    final isDaily =
        options.method == 'GET' && options.path.startsWith('/v1/daily/');
    if (!isDaily) {
      handler.next(options);
      return;
    }
    paths.add(options.path);
    final pending = hold;
    if (pending != null) {
      await pending.future;
    }
    if (offline) {
      handler.reject(
        DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
        true,
      );
      return;
    }
    handler.resolve(
      Response<Object?>(
        requestOptions: options,
        statusCode: 200,
        headers: Headers.fromMap({
          Headers.contentTypeHeader: ['application/json'],
        }),
        data: body,
      ),
      true,
    );
  }
}
