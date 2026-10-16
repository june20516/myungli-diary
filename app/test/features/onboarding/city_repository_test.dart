import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/features/onboarding/data/city_repository.dart';

/// 요청을 기록하고 정해 둔 응답을 차례로 돌려주는 어댑터. 실제 Dio처럼 304는 예외가 됩니다.
class _ScriptedAdapter implements HttpClientAdapter {
  new(this.responses);

  final List<({int status, Map<String, String> headers, String body})>
  responses;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = responses[requests.length - 1];
    return ResponseBody.fromString(
      response.body,
      response.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        for (final entry in response.headers.entries) entry.key: [entry.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const Map<String, Object> _body = {
  'dataVersion': '2026.10',
  'items': [
    {
      'id': '5128581',
      'name': 'New York City',
      'country': 'US',
      'countryName': 'United States',
      'timezone': 'America/New_York',
      'longitude': -74.006,
    },
  ],
};

CityRepository _repository(_ScriptedAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
    ..httpClientAdapter = adapter;
  return CityRepository(DefaultApi(dio));
}

void main() {
  test('같은 질의는 ETag로 다시 묻고 304면 이전 목록을 돌려줍니다', () async {
    final adapter = _ScriptedAdapter([
      (status: 200, headers: {'etag': '"v1"'}, body: jsonEncode(_body)),
      (status: 304, headers: {'etag': '"v1"'}, body: ''),
    ]);
    final repository = _repository(adapter);

    final first = await repository.search('new', language: Language.en);
    final second = await repository.search('new', language: Language.en);

    expect(first.single.id, '5128581');
    expect(second, first);
    expect(adapter.requests[0].headers['If-None-Match'], isNull);
    expect(adapter.requests[1].headers['If-None-Match'], '"v1"');
    expect(adapter.requests[0].queryParameters['q'], 'new');
    expect(adapter.requests[0].queryParameters['limit'], 20);
    expect(adapter.requests[0].queryParameters['lang'], Language.en);
  });

  test('질의나 언어가 다르면 ETag를 보내지 않습니다', () async {
    final adapter = _ScriptedAdapter([
      (status: 200, headers: {'etag': '"v1"'}, body: jsonEncode(_body)),
      (status: 200, headers: {}, body: jsonEncode(_body)),
      (status: 200, headers: {}, body: jsonEncode(_body)),
    ]);
    final repository = _repository(adapter);

    await repository.search('new', language: Language.en);
    await repository.search('newy', language: Language.en);
    await repository.search('new', language: Language.ko);

    expect(adapter.requests[1].headers['If-None-Match'], isNull);
    expect(adapter.requests[2].headers['If-None-Match'], isNull);
  });

  test('질의는 앞뒤 공백을 지우고 50자로 자릅니다', () async {
    final adapter = _ScriptedAdapter([
      (status: 200, headers: {}, body: jsonEncode(_body)),
    ]);
    await _repository(adapter).search('  ${'가' * 60}  ', language: Language.ko);

    expect(adapter.requests.single.queryParameters['q'], '가' * 50);
  });

  test('빈 질의는 요청하지 않고 빈 목록입니다', () async {
    final adapter = _ScriptedAdapter(const []);
    final result = await _repository(adapter)
        .search('   ', language: Language.ko);

    expect(result, isEmpty);
    expect(adapter.requests, isEmpty);
  });

  test('오류는 AppError입니다', () async {
    final adapter = _ScriptedAdapter([
      (
        status: 503,
        headers: {'content-type': 'application/problem+json'},
        body: jsonEncode({
          'type': 'https://api.myungli.app/problems/service.unavailable',
          'title': 'x',
          'status': 503,
          'code': 'service.unavailable',
          'traceId': 't',
        }),
      ),
    ]);
    await expectLater(
      _repository(adapter).search('new', language: Language.ko),
      throwsA(isA<AppError>()),
    );
  });
}
