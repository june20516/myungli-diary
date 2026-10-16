import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/features/calc_basis/data/lunar_date_repository.dart';

/// 요청을 기록하고 정해 둔 응답 하나를 돌려주는 어댑터.
class _ScriptedAdapter implements HttpClientAdapter {
  new({required this.status, required this.body});

  final int status;
  final String body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final contentType = status < 400
        ? 'application/json'
        : 'application/problem+json';
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

LunarDateRepository _repository(_ScriptedAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
    ..httpClientAdapter = adapter;
  return LunarDateRepository(DefaultApi(dio), () async => 'install-1');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('음력 날짜·윤달·설치 id를 보내고 응답의 양력 날짜를 돌려줍니다', () async {
    final adapter = _ScriptedAdapter(
      status: 200,
      body: jsonEncode({'solarDate': '1990-05-15', 'monthHasLeap': false}),
    );

    final solar = await _repository(adapter).toSolar(
      LunarOrSolarDate(year: 1990, month: 4, day: 21),
      isLeapMonth: true,
    );

    expect(solar, DateTime(1990, 5, 15));
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/v1/lunar-date');
    expect(jsonDecode(request.data as String), {
      'installationId': 'install-1',
      'date': {'year': 1990, 'month': 4, 'day': 21},
      'isLeapMonth': true,
    });
  });

  test('없는 음력 날짜(422)는 AppError입니다', () async {
    final adapter = _ScriptedAdapter(
      status: 422,
      body: jsonEncode({
        'type': 'https://api.myungli.app/problems/validation',
        'title': 'Invalid',
        'status': 422,
        'code': 'date.invalid',
        'traceId': 't',
      }),
    );

    await expectLater(
      _repository(adapter).toSolar(
        LunarOrSolarDate(year: 1990, month: 2, day: 30),
        isLeapMonth: false,
      ),
      throwsA(isA<AppError>()),
    );
  });

  test('양력 날짜 형식이 아니면 UnexpectedError입니다', () async {
    final adapter = _ScriptedAdapter(
      status: 200,
      body: jsonEncode({'solarDate': '1990/05/15', 'monthHasLeap': false}),
    );

    await expectLater(
      _repository(adapter).toSolar(
        LunarOrSolarDate(year: 1990, month: 4, day: 21),
        isLeapMonth: false,
      ),
      throwsA(isA<UnexpectedError>()),
    );
  });

  test('fake 서버 new-user 시나리오는 fixture의 양력 날짜로 답합니다', () async {
    final scenario = (await loadScenarios(rootBundle))
        .firstWhere((s) => s.id == 'new-user');
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
      ..interceptors.add(
        FakeServerInterceptor(scenario: scenario, bundle: rootBundle),
      );

    final solar =
        await LunarDateRepository(
          DefaultApi(dio),
          () async => 'install-1',
        ).toSolar(
          LunarOrSolarDate(year: 1990, month: 4, day: 21),
          isLeapMonth: false,
        );

    expect(solar, DateTime(1990, 5, 15));
  });
}
