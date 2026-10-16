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

    test('calendar-error는 getCalendar가 503이다', () async {
      final api = _apiOf(await _scenarioOf('calendar-error'));
      final error = await _problemOf(
        () => api.getCalendar(year: 2026, month: 10),
      );
      expect(error.status, 503);
    });
  });
}
