import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/fake/scenario.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/luck_level.dart';
import 'package:myungli_diary/core/api/gen/model/schedule.dart';
import 'package:myungli_diary/core/api/gen/model/schedule_input.dart';
import 'package:myungli_diary/core/api/gen/model/schedule_patch.dart';
import 'package:myungli_diary/core/api/gen/model/solar_term_kind.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';

/// 문자열 맵을 번들처럼 쓰는 테스트용 [AssetBundle].
class _MemoryBundle extends CachingAssetBundle {
  new(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage({
        for (final file in files.keys)
          file: [
            {'asset': file},
          ],
      })!;
    }
    final source = files[key];
    if (source == null) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
  }
}

Future<Scenario> _scenarioOf(String id) async =>
    (await loadScenarios(rootBundle)).singleWhere((s) => s.id == id);

DefaultApi _apiOf(Scenario scenario, [AssetBundle? bundle]) => DefaultApi(
  Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
    ..interceptors.add(
      FakeServerInterceptor(scenario: scenario, bundle: bundle ?? rootBundle),
    ),
);

Future<List<Schedule>> _list(DefaultApi api, String from, String to) async =>
    (await api.listSchedules(from: from, to: to)).data!.items;

Future<ProblemError> _problemOf(Future<Object?> Function() call) async {
  try {
    await call();
  } on DioException catch (e) {
    final error = appErrorFrom(e);
    if (error is ProblemError) {
      return error;
    }
    throw StateError('problem 응답이 아닙니다: $error');
  }
  throw StateError('오류가 나야 합니다.');
}

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// problem의 `errors[]`를 (위치, code) 목록으로.
List<(String, String)> _fieldsOf(ProblemError problem) => [
  for (final field in problem.fieldErrors) (field.pointer, field.code),
];

/// member 시나리오 시계(2026-10-13 서울 정오)의 UTC 시각.
final _scenarioNow = DateTime.utc(2026, 10, 13, 3);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('fake 일정 저장소', () {
    late DefaultApi api;

    setUp(() async {
      api = _apiOf(await _scenarioOf('member'));
    });

    test('처음 목록은 listSchedules fixture이고 from~to(포함)로 거른다', () async {
      final october = await _list(api, '2026-10-01', '2026-10-31');
      expect(october, hasLength(4));
      final today = await _list(api, '2026-10-13', '2026-10-13');
      expect(today.map((s) => (s.allDay, s.time)), [
        (true, null),
        (false, '09:07'),
        (false, '19:00'),
      ]);
      expect(await _list(api, '2026-10-14', '2026-10-19'), isEmpty);
      expect(await _list(api, '2026-10-20', '2026-10-20'), hasLength(1));
    });

    test('만들면 201이고 같은 범위 목록에 보이며 범위 밖 목록에는 없다', () async {
      final created = await api.createSchedule(
        scheduleInput: ScheduleInput(
          date: '2026-10-15',
          allDay: false,
          time: '08:30',
          title: '아침 산책',
          memo: '공원 한 바퀴',
        ),
      );
      expect(created.statusCode, 201);
      final schedule = created.data!;
      expect(schedule.id, matches(_uuidV4));
      expect(schedule.createdAt, _scenarioNow);
      expect(schedule.updatedAt, _scenarioNow);
      expect(created.headers.value('location'), '/v1/schedules/${schedule.id}');

      final listed = await _list(api, '2026-10-15', '2026-10-15');
      expect(listed.single, schedule);
      expect(
        (await _list(api, '2026-10-16', '2026-10-31')).map((s) => s.id),
        isNot(contains(schedule.id)),
      );
    });

    test('수정은 merge-patch이고 allDay true면 time이, 빈 memo면 memo가 사라진다', () async {
      final original = (await _list(api, '2026-10-20', '2026-10-20')).single;
      expect(original.time, '14:00');
      expect(original.memo, isNotNull);

      final retitled = await api.updateSchedule(
        id: original.id,
        schedulePatch: SchedulePatch(title: '치과'),
      );
      expect(retitled.statusCode, 200);
      expect(retitled.data!.title, '치과');
      expect(retitled.data!.time, '14:00');
      expect(retitled.data!.createdAt, original.createdAt);
      expect(retitled.data!.updatedAt, _scenarioNow);

      final allDay = await api.updateSchedule(
        id: original.id,
        schedulePatch: SchedulePatch(allDay: true, memo: ''),
      );
      expect(allDay.data!.allDay, isTrue);
      expect(allDay.data!.time, isNull);
      expect(allDay.data!.memo, isNull);

      final listed = (await _list(api, '2026-10-20', '2026-10-20')).single;
      expect(listed, allDay.data);
    });

    test('날짜를 옮기면 옛 날짜 목록에서 빠지고 새 날짜 목록에 보인다', () async {
      final original = (await _list(api, '2026-10-20', '2026-10-20')).single;
      await api.updateSchedule(
        id: original.id,
        schedulePatch: SchedulePatch(date: '2026-10-22'),
      );
      expect(await _list(api, '2026-10-20', '2026-10-20'), isEmpty);
      expect(
        (await _list(api, '2026-10-22', '2026-10-22')).single.id,
        original.id,
      );
    });

    test('요청 본문의 서버 필드(id·createdAt)는 무시한다', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
        ..interceptors.add(
          FakeServerInterceptor(
            scenario: await _scenarioOf('member'),
            bundle: rootBundle,
          ),
        );
      final original =
          (await dio.get<Map<String, Object?>>(
                '/v1/schedules',
                queryParameters: {'from': '2026-10-20', 'to': '2026-10-20'},
              )).data!['items']!
              as List<Object?>;
      final id = (original.single! as Map<String, Object?>)['id']! as String;
      final patched = await dio.patch<Map<String, Object?>>(
        '/v1/schedules/$id',
        data: {
          'id': 'other',
          'createdAt': '2000-01-01T00:00:00Z',
          'title': '치과',
        },
      );
      expect(patched.data!['id'], id);
      expect(patched.data!['createdAt'], isNot('2000-01-01T00:00:00Z'));
      expect(patched.data!['title'], '치과');
    });

    test('삭제는 204이고 목록에서 빠지며, 없는 id는 404다', () async {
      final target = (await _list(api, '2026-10-20', '2026-10-20')).single;
      final deleted = await api.deleteSchedule(id: target.id);
      expect(deleted.statusCode, 204);
      expect(await _list(api, '2026-10-20', '2026-10-20'), isEmpty);

      final again = await _problemOf(() => api.deleteSchedule(id: target.id));
      expect(again.status, 404);
      expect(again.code, 'schedule.not_found');
      final patchMissing = await _problemOf(
        () => api.updateSchedule(
          id: target.id,
          schedulePatch: SchedulePatch(title: '없음'),
        ),
      );
      expect(patchMissing.status, 404);
    });

    test('같은 Idempotency-Key로 두 번 만들면 처음 응답을 돌려주고 일정은 하나다', () async {
      final input = ScheduleInput(
        date: '2026-10-25',
        allDay: true,
        title: '등산',
      );
      final first = await api.createSchedule(
        scheduleInput: input,
        idempotencyKey: 'key-1',
      );
      final second = await api.createSchedule(
        scheduleInput: input,
        idempotencyKey: 'key-1',
      );
      expect(second.statusCode, 201);
      expect(second.data, first.data);
      expect(await _list(api, '2026-10-25', '2026-10-25'), hasLength(1));

      final other = await api.createSchedule(
        scheduleInput: input,
        idempotencyKey: 'key-2',
      );
      expect(other.data!.id, isNot(first.data!.id));
      expect(await _list(api, '2026-10-25', '2026-10-25'), hasLength(2));
    });

    test('같은 Idempotency-Key에 다른 본문이면 422 idempotency.mismatch', () async {
      await api.createSchedule(
        scheduleInput: ScheduleInput(
          date: '2026-10-25',
          allDay: true,
          title: '등산',
        ),
        idempotencyKey: 'key-1',
      );
      final mismatch = await _problemOf(
        () => api.createSchedule(
          scheduleInput: ScheduleInput(
            date: '2026-10-26',
            allDay: true,
            title: '등산',
          ),
          idempotencyKey: 'key-1',
        ),
      );
      expect(mismatch.status, 422);
      expect(mismatch.code, 'idempotency.mismatch');
    });

    test('allDay와 time의 짝이 어긋나면 422 request.inconsistent', () async {
      final timeOnAllDay = await _problemOf(
        () => api.createSchedule(
          scheduleInput: ScheduleInput(
            date: '2026-10-25',
            allDay: true,
            time: '10:00',
            title: '등산',
          ),
        ),
      );
      expect(timeOnAllDay.status, 422);
      expect(timeOnAllDay.code, 'request.inconsistent');
      expect(_fieldsOf(timeOnAllDay), [('/time', 'forbidden_by_status')]);
      final missingTime = await _problemOf(
        () => api.createSchedule(
          scheduleInput: ScheduleInput(
            date: '2026-10-25',
            allDay: false,
            title: '등산',
          ),
        ),
      );
      expect(missingTime.code, 'request.inconsistent');
      expect(_fieldsOf(missingTime), [('/time', 'required_by_status')]);
    });

    test('없는 날짜나 빈 제목은 400 request.invalid', () async {
      final badDate = await _problemOf(
        () => api.createSchedule(
          scheduleInput: ScheduleInput(
            date: '2026-02-30',
            allDay: true,
            title: '등산',
          ),
        ),
      );
      expect(badDate.status, 400);
      expect(badDate.code, 'request.invalid');
      expect(_fieldsOf(badDate), [('/date', 'format')]);
      final emptyTitle = await _problemOf(
        () => api.createSchedule(
          scheduleInput: ScheduleInput(
            date: '2026-10-25',
            allDay: true,
            title: '',
          ),
        ),
      );
      expect(emptyTitle.code, 'request.invalid');
      expect(_fieldsOf(emptyTitle), [('/title', 'minLength')]);
    });

    test('listSchedules 범위가 62일을 넘으면 422 range.too_long입니다', () async {
      expect(await _list(api, '2026-10-01', '2026-12-01'), hasLength(4));
      final tooLong = await _problemOf(
        () => api.listSchedules(from: '2026-10-01', to: '2026-12-02'),
      );
      expect(tooLong.status, 422);
      expect(tooLong.code, 'range.too_long');
      expect(_fieldsOf(tooLong), isEmpty);
      final reversed = await _problemOf(
        () => api.listSchedules(from: '2026-10-02', to: '2026-10-01'),
      );
      expect(_fieldsOf(reversed), [('to', 'minimum')]);
    });

    test('저장소는 대역 인스턴스마다 새로 시작한다', () async {
      await api.createSchedule(
        scheduleInput: ScheduleInput(
          date: '2026-10-25',
          allDay: true,
          title: '등산',
        ),
      );
      final fresh = _apiOf(await _scenarioOf('member'));
      expect(await _list(fresh, '2026-10-25', '2026-10-25'), isEmpty);
    });
  });

  group('시나리오 파일 우선', () {
    test('schedule-save-error는 만들기·고치기가 503이고 목록은 저장소가 답한다', () async {
      final api = _apiOf(await _scenarioOf('schedule-save-error'));
      final create = await _problemOf(
        () => api.createSchedule(
          scheduleInput: ScheduleInput(
            date: '2026-10-25',
            allDay: true,
            title: '등산',
          ),
        ),
      );
      expect(create.status, 503);
      final target = (await _list(api, '2026-10-20', '2026-10-20')).single;
      final update = await _problemOf(
        () => api.updateSchedule(
          id: target.id,
          schedulePatch: SchedulePatch(title: '치과'),
        ),
      );
      expect(update.status, 503);
      expect(
        (await _list(api, '2026-10-20', '2026-10-20')).single.title,
        target.title,
      );
    });

    test('시나리오의 listSchedules 오류 파일은 저장소보다 우선한다', () async {
      final bundle = _MemoryBundle({
        'fixtures/s/listSchedules.json': jsonEncode({
          'status': 503,
          'body': {
            'type': 'https://api.myungli.app/problems/service.unavailable',
            'title': 'Service unavailable',
            'status': 503,
            'code': 'service.unavailable',
            'traceId': 't',
          },
        }),
      });
      final api = _apiOf(
        Scenario(
          id: 's',
          today: CalendarDate(2026, 10, 13),
          timezone: 'Asia/Seoul',
        ),
        bundle,
      );
      final error = await _problemOf(
        () => api.listSchedules(from: '2026-10-01', to: '2026-10-31'),
      );
      expect(error.status, 503);
    });

    test('listSchedules fixture가 없으면 빈 저장소로 시작한다', () async {
      final api = _apiOf(
        Scenario(
          id: 's',
          today: CalendarDate(2026, 10, 13),
          timezone: 'Asia/Seoul',
        ),
        _MemoryBundle({}),
      );
      expect(await _list(api, '2026-10-01', '2026-10-31'), isEmpty);
    });
  });

  group('fake 일기 목록', () {
    Future<List<String>> datesOf(
      String scenarioId, {
      String? from,
      String? to,
    }) async {
      final api = _apiOf(await _scenarioOf(scenarioId));
      final list = (await api.listDiaries(from: from, to: to)).data!;
      return [for (final item in list.items) item.date];
    }

    test('fixture items를 from~to(포함)로 거르고 날짜 내림차순으로 준다', () async {
      expect(await datesOf('member'), [
        '2026-10-12',
        '2026-10-08',
        '2026-10-05',
        '2026-10-02',
      ]);
      expect(await datesOf('member', from: '2026-10-05', to: '2026-10-08'), [
        '2026-10-08',
        '2026-10-05',
      ]);
      expect(
        await datesOf('member', from: '2026-10-09', to: '2026-10-11'),
        isEmpty,
      );
      expect(
        await datesOf('member', from: '2026-09-01', to: '2026-09-30'),
        isEmpty,
      );
    });

    test('tag면 그 태그가 붙은 일기만 준다(대역은 featuredTags로 거름)', () async {
      final api = _apiOf(await _scenarioOf('member'));
      final list = (await api.listDiaries(tag: 'clash')).data!;
      expect([for (final item in list.items) item.date], ['2026-10-02']);
      final none = (await api.listDiaries(tag: 'gongmang')).data!;
      expect(none.items, isEmpty);
    });

    test(
      'limit만큼 주고 nextCursor로 다음 쪽을 이어 받으며, 마지막 쪽에는 nextCursor가 없다',
      () async {
        final api = _apiOf(await _scenarioOf('member'));
        final first = (await api.listDiaries(limit: 3)).data!;
        expect(
          [for (final item in first.items) item.date],
          ['2026-10-12', '2026-10-08', '2026-10-05'],
        );
        expect(first.nextCursor, isNotNull);

        final second = (await api.listDiaries(
          limit: 3,
          cursor: first.nextCursor,
        )).data!;
        expect([for (final item in second.items) item.date], ['2026-10-02']);
        expect(second.nextCursor, isNull);

        // limit이 없으면 기본 30이라 한 쪽으로 끝납니다.
        final all = (await api.listDiaries()).data!;
        expect(all.items, hasLength(4));
        expect(all.nextCursor, isNull);
      },
    );

    test('범위·태그로 거른 뒤 쪽을 나눈다', () async {
      final api = _apiOf(await _scenarioOf('member'));
      final page = (await api.listDiaries(
        from: '2026-10-05',
        to: '2026-10-12',
        limit: 2,
      )).data!;
      expect(
        [for (final item in page.items) item.date],
        ['2026-10-12', '2026-10-08'],
      );
      final rest = (await api.listDiaries(
        from: '2026-10-05',
        to: '2026-10-12',
        limit: 2,
        cursor: page.nextCursor,
      )).data!;
      expect([for (final item in rest.items) item.date], ['2026-10-05']);
      expect(rest.nextCursor, isNull);
    });

    test(
      'limit이 1~100 밖이거나 cursor가 대역이 준 값이 아니면 400 request.invalid',
      () async {
        final api = _apiOf(await _scenarioOf('member'));
        final low = await _problemOf(() => api.listDiaries(limit: 0));
        expect((low.status, low.code), (400, 'request.invalid'));
        expect(_fieldsOf(low), [('limit', 'minimum')]);
        final high = await _problemOf(() => api.listDiaries(limit: 101));
        expect(_fieldsOf(high), [('limit', 'maximum')]);
        final cursor = await _problemOf(() => api.listDiaries(cursor: 'bogus'));
        expect((cursor.status, cursor.code), (400, 'request.invalid'));
        expect(_fieldsOf(cursor), [('cursor', 'format')]);
      },
    );

    test('diary-written은 오늘(10-13) 일기가 목록에 있다', () async {
      expect(
        await datesOf('diary-written', from: '2026-10-13', to: '2026-10-13'),
        ['2026-10-13'],
      );
    });
  });

  group('달력 fixture', () {
    test('member는 2026-09~11 달력을 생성 클라이언트로 읽는다', () async {
      final api = _apiOf(await _scenarioOf('member'));
      final september = (await api.getCalendar(year: 2026, month: 9)).data!;
      final october = (await api.getCalendar(year: 2026, month: 10)).data!;
      final november = (await api.getCalendar(year: 2026, month: 11)).data!;
      expect(
        [september.days.length, october.days.length, november.days.length],
        [30, 31, 30],
      );

      final hallo = october.days.singleWhere((d) => d.date == '2026-10-08');
      expect(hallo.solarTerm!.kind, SolarTermKind.hallo);
      final sanggang = october.days.singleWhere((d) => d.date == '2026-10-23');
      expect(sanggang.solarTerm!.kind, SolarTermKind.sanggang);
      final ipdong = november.days.singleWhere((d) => d.date == '2026-11-07');
      expect(ipdong.solarTerm!.kind, SolarTermKind.ipdong);

      // 한국 음력 9월 초하루가 10월 11일입니다.
      final newMoon = october.days.singleWhere((d) => d.date == '2026-10-11');
      expect((newMoon.lunar.month, newMoon.lunar.day), (9, 1));
      expect(
        october.days.map((d) => d.luckLevel).toSet(),
        LuckLevel.values.toSet(),
      );
      expect(
        october.days.any(
          (d) => d.characterReason.text.segments.any((s) => s.term != null),
        ),
        isTrue,
      );
    });

    test('member 10-13은 오늘 화면(getDaily)과 일진·날의 성격이 같다', () async {
      final api = _apiOf(await _scenarioOf('member'));
      final daily = (await api.getDaily(date: '2026-10-13')).data!;
      final october = (await api.getCalendar(year: 2026, month: 10)).data!;
      final today = october.days.singleWhere((d) => d.date == '2026-10-13');
      expect(today.pillar, daily.dayPillar);
      expect(today.dayKind, daily.dayKind);
      // 생성 모델의 ==는 목록을 얕게 비교하므로 JSON으로 비교합니다.
      expect(
        jsonEncode(today.characterReason.toJson()),
        jsonEncode(daily.characterReason.toJson()),
      );
      expect(today.luckLevel, LuckLevel.good);
      expect(today.level.messageKey, 'calendar.good');
      // 엔진 규칙(rules/calendar_luck.py)의 good 기준은 2점 이상입니다.
      expect(today.score, greaterThanOrEqualTo(2));
    });

    test('calendar-error는 getCalendar가 503이다', () async {
      final api = _apiOf(await _scenarioOf('calendar-error'));
      final error = await _problemOf(
        () => api.getCalendar(year: 2026, month: 10),
      );
      expect(error.status, 503);
    });
  });
}
