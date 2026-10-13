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
        true,
      );
      return;
    }
    if (scenario.delay > Duration.zero) {
      await Future<void>.delayed(scenario.delay);
    }
    final route = matchRoute(options.method, routePathOf(options));
    if (route == null) {
      _respond(
        options,
        handler,
        _problem(
          404,
          'route.not_found',
          'Route not found',
          '${options.method} ${routePathOf(options)}',
        ),
      );
      return;
    }
    _operationCounts[route.operationId] = callCountOf(route.operationId) + 1;
    final fixture = await _findFixture(route, routePathOf(options));
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

  final _operationCounts = <String, int>{};

  /// [operationId]로 지금까지 들어온(오프라인이 아닌) 요청 수. 테스트용입니다.
  @visibleForTesting
  int callCountOf(String operationId) => _operationCounts[operationId] ?? 0;

  /// fixture 파일 경로별 지금까지의 호출 수(`sequence` 순서용).
  final _callCounts = <String, int>{};

  Future<_Fixture?> _findFixture(ApiRoute route, String path) async {
    final parameters = route.pathParametersOf(path) ?? const {};
    final names = [
      if (parameters.isNotEmpty)
        '${route.operationId}__${parameters.values.join('-')}.json',
      '${route.operationId}.json',
    ];
    for (final scenarioId in scenario.lineage) {
      for (final name in names) {
        final key = 'fixtures/$scenarioId/$name';
        final source = await _tryLoad(key);
        if (source != null) {
          final responses = _parseFixture(source, key);
          final count = _callCounts[key] ?? 0;
          _callCounts[key] = count + 1;
          // 목록을 넘으면 마지막 응답을 되풀이합니다.
          return responses[count < responses.length
              ? count
              : responses.length - 1];
        }
      }
    }
    return null;
  }

  Future<Set<String>>? _assetKeys;

  /// 번들 manifest에 없는 key면 null이고, 있는 key의 읽기 오류는 그대로 던집니다.
  Future<String?> _tryLoad(String key) async {
    final keys = await (_assetKeys ??= _loadAssetKeys());
    return keys.contains(key) ? await bundle.loadString(key) : null;
  }

  Future<Set<String>> _loadAssetKeys() async {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    return manifest.listAssets().toSet();
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
      handler.resolve(response, true);
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

/// fixture 파일을 응답 목록으로 읽습니다. 단일 형식이면 하나짜리 목록입니다.
List<_Fixture> _parseFixture(String source, String name) {
  final json = jsonDecode(source);
  if (json is Map<String, Object?> && json.containsKey('sequence')) {
    final sequence = json['sequence'];
    if (json.length != 1 || sequence is! List<Object?> || sequence.isEmpty) {
      throw FormatException(
        'sequence는 비어 있지 않은 배열이어야 하고 다른 키와 함께 쓸 수 없습니다: $name',
      );
    }
    return [for (final item in sequence) _parseResponse(item, name)];
  }
  return [_parseResponse(json, name)];
}

_Fixture _parseResponse(Object? json, String name) {
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
