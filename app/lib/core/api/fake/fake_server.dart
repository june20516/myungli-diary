import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/api_route.dart';
import 'package:myungli_diary/core/api/fake/fake_diary_list.dart';
import 'package:myungli_diary/core/api/fake/fake_problem.dart';
import 'package:myungli_diary/core/api/fake/fake_schedule_store.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:myungli_diary/core/clock/clock.dart';

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
    _requestBodies.putIfAbsent(route.operationId, () => []).add(options.data);
    _requestHeaders.putIfAbsent(route.operationId, () => []).add({
      for (final entry in options.headers.entries)
        entry.key.toLowerCase(): '${entry.value}',
    });
    final path = routePathOf(options);
    final fixture = await _findFixture(route, path);
    final stored = await _answerFromScheduleStore(
      route,
      path,
      options,
      fixture,
    );
    _respond(
      options,
      handler,
      stored ??
          _filteredDiaryList(route, options, fixture) ??
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

  final _requestBodies = <String, List<Object?>>{};

  /// [operationId]로 들어온 요청 본문을 받은 순서대로 돌려줍니다. 테스트용입니다.
  @visibleForTesting
  List<Object?> requestBodiesOf(String operationId) =>
      List.unmodifiable(_requestBodies[operationId] ?? const []);

  final _requestHeaders = <String, List<Map<String, String>>>{};

  /// [operationId]로 들어온 요청 헤더를 받은 순서대로 돌려줍니다. 이름은 소문자입니다. 테스트용입니다.
  @visibleForTesting
  List<Map<String, String>> requestHeadersOf(String operationId) =>
      List.unmodifiable(_requestHeaders[operationId] ?? const []);

  Future<FakeScheduleStore>? _scheduleStore;

  /// 일정 operation이면 대역 일정 저장소로 답합니다. 그 밖의 operation이면 null입니다.
  ///
  /// 시나리오가 그 operation의 파일을 따로 두면(오류 시나리오) 파일이 우선이라 null을
  /// 돌려줍니다. `listSchedules` 파일은 200이면 저장소의 처음 목록이고, 그 밖의 status면
  /// 파일이 답합니다.
  Future<_Fixture?> _answerFromScheduleStore(
    ApiRoute route,
    String path,
    RequestOptions options,
    _Fixture? fixture,
  ) async {
    final operationId = route.operationId;
    if (!_scheduleOperations.contains(operationId)) {
      return null;
    }
    final fileWins = operationId == 'listSchedules'
        ? fixture != null && fixture.status != 200
        : fixture != null;
    if (fileWins) {
      return null;
    }
    final store = await (_scheduleStore ??= _loadScheduleStore());
    final id = route.pathParametersOf(path)?['id'];
    try {
      switch (operationId) {
        case 'listSchedules':
          final query = options.queryParameters;
          return _ok(200, store.list(from: query['from'], to: query['to']));
        case 'createSchedule':
          final schedule = store.create(
            options.data,
            idempotencyKey: _headerOf(options, 'idempotency-key'),
          );
          return _ok(
            201,
            schedule,
            headers: {'location': '/v1/schedules/${schedule['id']}'},
          );
        case 'updateSchedule':
          return _ok(200, store.update(id!, options.data));
        default:
          store.delete(id!);
          return const _Fixture(status: 204, headers: {}, body: null);
      }
    } on FakeProblem catch (problem) {
      return _problemOf(problem);
    }
  }

  /// `listDiaries`의 200 fixture를 요청의 `from`·`to`로 걸러 답합니다. 그 밖이면 null입니다.
  _Fixture? _filteredDiaryList(
    ApiRoute route,
    RequestOptions options,
    _Fixture? fixture,
  ) {
    final body = fixture?.body;
    if (route.operationId != 'listDiaries' ||
        fixture == null ||
        fixture.status != 200 ||
        body is! Map<String, Object?>) {
      return null;
    }
    try {
      return _Fixture(
        status: 200,
        headers: fixture.headers,
        body: filterDiaryList(
          body,
          from: options.queryParameters['from'],
          to: options.queryParameters['to'],
        ),
      );
    } on FakeProblem catch (problem) {
      return _problemOf(problem);
    }
  }

  _Fixture _problemOf(FakeProblem problem) => _problem(
    problem.status,
    problem.code,
    problem.title,
    problem.detail,
    errors: problem.errors,
  );

  /// 시나리오의 `listSchedules` 파일(첫 응답이 200일 때 그 `items`)로 저장소를 시작합니다.
  /// 파일이 없으면 빈 저장소입니다. 시각은 시나리오 시계(오늘 현지 정오)입니다.
  Future<FakeScheduleStore> _loadScheduleStore() async {
    final found = await findFixtureSource(const ['listSchedules.json']);
    final first = found == null
        ? null
        : _parseFixture(found.source, found.key).first;
    final body = first?.status == 200 ? first!.body : null;
    final items = body is Map<String, Object?> ? body['items'] : null;
    final clock = noonClockOn(scenario.today, scenario.timezone);
    return FakeScheduleStore(
      seed: [
        if (items is List<Object?>)
          for (final item in items) Map<String, Object?>.from(item! as Map),
      ],
      nowUtc: clock.nowUtc,
    );
  }

  /// fixture 파일 경로별 지금까지의 호출 수(`sequence` 순서용).
  final _callCounts = <String, int>{};

  Future<_Fixture?> _findFixture(ApiRoute route, String path) async {
    final parameters = route.pathParametersOf(path) ?? const {};
    final found = await findFixtureSource([
      if (parameters.isNotEmpty)
        '${route.operationId}__${parameters.values.join('-')}.json',
      '${route.operationId}.json',
    ]);
    if (found == null) {
      return null;
    }
    final responses = _parseFixture(found.source, found.key);
    final count = _callCounts[found.key] ?? 0;
    _callCounts[found.key] = count + 1;
    // 목록을 넘으면 마지막 응답을 되풀이합니다.
    return responses[count < responses.length ? count : responses.length - 1];
  }

  /// [names] 순서(바깥은 [Scenario.lineage] 순서)로 처음 찾은 fixture 파일의 key와 본문.
  ///
  /// 없으면 null입니다. 요청 응답과 앱 시작 코드(토큰 심기)가 같은 조회를 씁니다.
  Future<({String key, String source})?> findFixtureSource(
    List<String> names,
  ) async {
    for (final scenarioId in scenario.lineage) {
      for (final name in names) {
        final key = 'fixtures/$scenarioId/$name';
        final source = await _tryLoad(key);
        if (source != null) {
          return (key: key, source: source);
        }
      }
    }
    return null;
  }

  Future<Set<String>>? _assetKeys;

  /// 번들 manifest에 없는 key면 null이고, 있는 key의 읽기 오류는 그대로 던집니다.
  Future<String?> _tryLoad(String key) async {
    final Set<String> keys;
    try {
      keys = await (_assetKeys ??= _loadAssetKeys());
    } on Object {
      // 실패한 Future를 붙들어 두면 이후 요청이 모두 같은 오류로 끝나므로 다시 읽게 합니다.
      _assetKeys = null;
      rethrow;
    }
    // 번들이 읽은 Future를 붙들어 두지 않게 합니다. fixture는 개발·테스트에서만 읽고,
    // widget 테스트에서는 이전 테스트의 가짜 시계에 묶인 Future가 다음 테스트를 멈춥니다.
    return keys.contains(key)
        ? await bundle.loadString(key, cache: false)
        : null;
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

  _Fixture _problem(
    int status,
    String code,
    String title,
    String detail, {
    List<FakeFieldError> errors = const [],
  }) {
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
        if (errors.isNotEmpty)
          'errors': [
            for (final error in errors)
              {'field': error.field, 'code': error.code},
          ],
      },
    );
  }
}

/// 대역 일정 저장소가 답하는 operation.
const _scheduleOperations = {
  'listSchedules',
  'createSchedule',
  'updateSchedule',
  'deleteSchedule',
};

_Fixture _ok(
  int status,
  Map<String, Object?> body, {
  Map<String, String> headers = const {},
}) => _Fixture(
  status: status,
  headers: {Headers.contentTypeHeader: _jsonMediaType, ...headers},
  body: body,
);

/// 요청 헤더 [name](소문자)의 값. 없으면 null입니다.
String? _headerOf(RequestOptions options, String name) {
  for (final entry in options.headers.entries) {
    if (entry.key.toLowerCase() == name && entry.value != null) {
      return '${entry.value}';
    }
  }
  return null;
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
