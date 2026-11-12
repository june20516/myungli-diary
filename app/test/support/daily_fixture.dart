import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

/// member 시나리오의 `getDaily` 응답 본문. fixture와 테스트가 같은 값을 보게 합니다.
Map<String, dynamic> memberDailyJson() => dailyFixtureJson('member');

/// [scenario] 시나리오의 `getDaily` 응답 본문(예 `daily-pair-virtue`, 색이 둘인 날).
Map<String, dynamic> dailyFixtureJson(String scenario) {
  final fixture = jsonDecode(
    File('fixtures/$scenario/getDaily.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return fixture['body'] as Map<String, dynamic>;
}

/// member 응답의 세 집중 시간 카드를 프로필 시간대 `America/Los_Angeles`의 엔진 값으로 바꾼 본문.
///
/// 서울 밖 시간대 응답의 시진 경계(#1064)를 보는 테스트가 씁니다. 값은 core `compose_daily`(member
/// 출생 1990-05-15 14:30 여성, 2026-10-13과 전날, 시간대 `America/Los_Angeles`, 규칙 2026.11.8)의
/// `FocusPick.grade`와 `FocusPick.hours` 그대로이고(`tool/gen_daily_fixtures.py`의 `focus_card`와 같은
/// 모양), 문장은 member 응답 그대로입니다. 진시는 08:00(-07:00)에 시작합니다. fake 시나리오
/// `member-overseas`와 같은 시간대입니다.
Map<String, dynamic> losAngelesDailyJson() {
  final json = memberDailyJson();
  final cards = json['cards'] as Map<String, dynamic>;
  for (final (field, pickBranch, hours) in _losAngelesFocusHours) {
    final card = cards[field] as Map<String, dynamic>;
    final slots = [for (final hour in hours) _losAngelesSlot(hour)];
    card['hours'] = slots;
    card['picks'] = [slots.firstWhere((slot) => slot['branch'] == pickBranch)];
  }
  return json;
}

/// 엔진 시진 한 줄: (지지, 시작, 끝, 황도길시, 그 시진의 날, 일진 천간, 일진 지지).
typedef _EngineHour = (String, String, String, bool, String, String, String);

Map<String, Object?> _losAngelesSlot(_EngineHour hour) {
  final (branch, start, end, huangdao, dayDate, stem, dayBranch) = hour;
  return {
    'branch': branch,
    'start': start,
    'end': end,
    'huangdaoLucky': huangdao,
    'dayDate': dayDate,
    'dayPillar': {'stem': stem, 'branch': dayBranch},
    'reasons': <String>[],
  };
}

/// (카드 필드, 고른 시진, 구간 시진 전부). [losAngelesDailyJson] 설명의 엔진 출력입니다.
const List<(String, String, List<_EngineHour>)> _losAngelesFocusHours = [
  (
    'focusTime',
    'shin',
    [
      (
        'jin',
        '2026-10-13T08:00:00-07:00',
        '2026-10-13T10:00:00-07:00',
        true,
        '2026-10-13',
        'gyeong',
        'shin',
      ),
      (
        'sa',
        '2026-10-13T10:00:00-07:00',
        '2026-10-13T12:00:00-07:00',
        true,
        '2026-10-13',
        'gyeong',
        'shin',
      ),
      (
        'o',
        '2026-10-13T12:00:00-07:00',
        '2026-10-13T14:00:00-07:00',
        false,
        '2026-10-13',
        'gyeong',
        'shin',
      ),
      (
        'mi',
        '2026-10-13T14:00:00-07:00',
        '2026-10-13T16:00:00-07:00',
        true,
        '2026-10-13',
        'gyeong',
        'shin',
      ),
      (
        'shin',
        '2026-10-13T16:00:00-07:00',
        '2026-10-13T18:00:00-07:00',
        false,
        '2026-10-13',
        'gyeong',
        'shin',
      ),
      (
        'yu',
        '2026-10-13T18:00:00-07:00',
        '2026-10-13T20:00:00-07:00',
        false,
        '2026-10-13',
        'gyeong',
        'shin',
      ),
      (
        'sul',
        '2026-10-13T20:00:00-07:00',
        '2026-10-13T22:00:00-07:00',
        true,
        '2026-10-13',
        'gyeong',
        'shin',
      ),
    ],
  ),
  (
    'nightFocusTime',
    'chuk',
    [
      (
        'hae',
        '2026-10-13T22:00:00-07:00',
        '2026-10-14T00:00:00-07:00',
        false,
        '2026-10-13',
        'gyeong',
        'shin',
      ),
      (
        'ja',
        '2026-10-14T00:00:00-07:00',
        '2026-10-14T02:00:00-07:00',
        true,
        '2026-10-14',
        'sin',
        'yu',
      ),
      (
        'chuk',
        '2026-10-14T02:00:00-07:00',
        '2026-10-14T04:00:00-07:00',
        false,
        '2026-10-14',
        'sin',
        'yu',
      ),
      (
        'in',
        '2026-10-14T04:00:00-07:00',
        '2026-10-14T06:00:00-07:00',
        true,
        '2026-10-14',
        'sin',
        'yu',
      ),
      (
        'myo',
        '2026-10-14T06:00:00-07:00',
        '2026-10-14T08:00:00-07:00',
        true,
        '2026-10-14',
        'sin',
        'yu',
      ),
    ],
  ),
  (
    'previousNightFocusTime',
    'chuk',
    [
      (
        'hae',
        '2026-10-12T22:00:00-07:00',
        '2026-10-13T00:00:00-07:00',
        true,
        '2026-10-12',
        'gi',
        'mi',
      ),
      (
        'ja',
        '2026-10-13T00:00:00-07:00',
        '2026-10-13T02:00:00-07:00',
        true,
        '2026-10-13',
        'gyeong',
        'shin',
      ),
      (
        'chuk',
        '2026-10-13T02:00:00-07:00',
        '2026-10-13T04:00:00-07:00',
        true,
        '2026-10-13',
        'gyeong',
        'shin',
      ),
      (
        'in',
        '2026-10-13T04:00:00-07:00',
        '2026-10-13T06:00:00-07:00',
        false,
        '2026-10-13',
        'gyeong',
        'shin',
      ),
      (
        'myo',
        '2026-10-13T06:00:00-07:00',
        '2026-10-13T08:00:00-07:00',
        false,
        '2026-10-13',
        'gyeong',
        'shin',
      ),
    ],
  ),
];

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
