import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/api_route.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/api/http_client.dart';

/// 현재 시나리오. 앱 시작 코드가 `loadScenarios`로 고른 값을 override합니다.
final scenarioProvider = Provider<Scenario>(
  (ref) => throw UnimplementedError('scenarioProvider를 override하세요.'),
);

/// fake 모드에서만 대역 interceptor를 돌려줍니다.
///
/// 연결: `fakeServerProvider.overrideWith(
///   (ref) => ref.watch(fakeServerInterceptorProvider))`.
final fakeServerInterceptorProvider = Provider<Interceptor?>((ref) {
  if (ref.watch(apiModeProvider) != ApiMode.fake) {
    return null;
  }
  return FakeServerInterceptor(
    scenario: ref.watch(scenarioProvider),
    bundle: rootBundle,
  );
});

const _problemType = 'https://api.myungli.app/problems';
const _fakeTraceId = 'fake-server';

/// 요청을 `fixtures/<시나리오>/` JSON으로 답하는 대역 서버입니다.
///
/// 생성 클라이언트와 직렬화는 실제와 같이 거치고 네트워크 어댑터만 건너뜁니다.
/// fixture 찾는 순서: 매개변수 파일(`<operationId>__<값>.json`) → 기본 파일
/// (`<operationId>.json`)을 [Scenario.lineage] 시나리오마다 차례로 봅니다.
final class FakeServerInterceptor extends Interceptor {
  /// [scenario]의 fixture를 [bundle]에서 읽습니다.
  new({required this.scenario, required this.bundle});

  /// 시나리오.
  final Scenario scenario;

  /// fixture를 읽는 번들.
  final AssetBundle bundle;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (scenario.offline) {
      handler.reject(
        DioException.connectionError(
          requestOptions: options,
          reason: '대역 서버: ${scenario.id} 시나리오는 오프라인입니다.',
        ),
      );
      return;
    }
    if (scenario.delay > Duration.zero) {
      await Future<void>.delayed(scenario.delay);
    }
    final route = matchRoute(options.method, options.uri.path);
    if (route == null) {
      _respond(
        options,
        handler,
        _problem(
          404,
          'route.not_found',
          'Route not found',
          '${options.method} ${options.uri.path}',
        ),
      );
      return;
    }
    final fixture = await _findFixture(route, options.uri.path);
    _respond(
      options,
      handler,
      fixture ??
          _problem(
            501,
            'not_implemented',
            'Not implemented',
            '${scenario.id} 시나리오에 ${route.operationId} fixture가 없습니다.',
          ),
    );
  }

  Future<_Fixture?> _findFixture(ApiRoute route, String path) async {
    final parameters = route.pathParametersOf(path) ?? const {};
    final names = [
      if (parameters.isNotEmpty)
        '${route.operationId}__${parameters.values.join('-')}.json',
      '${route.operationId}.json',
    ];
    for (final scenarioId in scenario.lineage) {
      for (final name in names) {
        final source = await _tryLoad('fixtures/$scenarioId/$name');
        if (source != null) {
          return _parseFixture(source, '$scenarioId/$name');
        }
      }
    }
    return null;
  }

  Future<String?> _tryLoad(String key) async {
    try {
      return await bundle.loadString(key);
      // 없는 asset은 번들이 FlutterError로 알립니다.
      // ignore: avoid_catching_errors
    } on FlutterError {
      return null;
    }
  }

  void _respond(
    RequestOptions options,
    RequestInterceptorHandler handler,
    _Fixture fixture,
  ) {
    final response = Response<Object?>(
      requestOptions: options,
      statusCode: fixture.status,
      data: fixture.body,
      headers: Headers.fromMap({
        for (final entry in fixture.headers.entries) entry.key: [entry.value],
      }),
    );
    if (fixture.status >= 400) {
      handler.reject(
        DioException.badResponse(
          statusCode: fixture.status,
          requestOptions: options,
          response: response,
        ),
        true,
      );
    } else {
      handler.resolve(response);
    }
  }

  _Fixture _problem(int status, String code, String title, String detail) {
    return _Fixture(
      status: status,
      headers: const {Headers.contentTypeHeader: _problemMediaType},
      body: <String, Object?>{
        'type': '$_problemType/$code',
        'title': title,
        'status': status,
        'code': code,
        'traceId': _fakeTraceId,
        'detail': detail,
      },
    );
  }
}

const _jsonMediaType = 'application/json';
const _problemMediaType = 'application/problem+json';

/// fixture 파일 하나: `{ "status", "headers"(선택), "body"(선택) }`.
final class _Fixture {
  const new({required this.status, required this.headers, required this.body});

  final int status;
  final Map<String, String> headers;
  final Object? body;
}

_Fixture _parseFixture(String source, String name) {
  final json = jsonDecode(source);
  if (json is! Map<String, Object?> || json['status'] is! int) {
    throw FormatException('fixture에 정수 status가 필요합니다: $name');
  }
  final status = json['status']! as int;
  final rawHeaders = json['headers'];
  final headers =
      <String, String>{
          if (rawHeaders is Map<String, Object?>)
            for (final entry in rawHeaders.entries)
              entry.key.toLowerCase(): '${entry.value}',
        }
        // 계약 응답 종류에 맞춘 기본 Content-Type: 2xx는 json, 4xx·5xx는 problem+json.
        ..putIfAbsent(
          Headers.contentTypeHeader,
          () => status >= 400 ? _problemMediaType : _jsonMediaType,
        );
  return _Fixture(status: status, headers: headers, body: json['body']);
}
