import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/api/default_api.dart';
import 'package:myungli_diary/core/api/gen/model/schedule_input.dart';
import 'package:myungli_diary/core/api/gen/model/schedule_patch.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/features/schedule/data/schedule_repository.dart';
import 'package:myungli_diary/features/schedule/model/schedule_gone.dart';

import '../../../support/schedule_test_server.dart';

void main() {
  late ScheduleTestServer server;
  late ScheduleRepository repository;

  setUp(() {
    server = ScheduleTestServer();
    repository = ScheduleRepository(server.client());
  });

  test('list는 from~to(포함)를 보내고 그 범위 일정을 돌려준다', () async {
    final items = await repository.list(
      CalendarDate(2026, 10, 13),
      CalendarDate(2026, 10, 13),
    );

    expect(items.map((s) => s.id), ['all-day', 'morning', 'evening']);
    final request = server.requests.single;
    expect(request.queryParameters, {'from': '2026-10-13', 'to': '2026-10-13'});
  });

  test('create는 Idempotency-Key를 싣고 만든 일정을 돌려준다', () async {
    final created = await repository.create(
      ScheduleInput(date: '2026-10-14', allDay: true, title: '산책'),
      idempotencyKey: 'key-1',
    );

    expect(created.title, '산책');
    final request = server.requestsOf('POST', '/v1/schedules').single;
    expect(request.headers['Idempotency-Key'], 'key-1');
  });

  test('update는 보낸 필드만 바꾼다', () async {
    final updated = await repository.update(
      'morning',
      SchedulePatch(title: '회고'),
    );

    expect(updated.title, '회고');
    expect(updated.time, '09:07');
  });

  test('delete는 그 일정을 지운다', () async {
    await repository.delete('morning');

    final left = await repository.list(
      CalendarDate(2026, 10, 13),
      CalendarDate(2026, 10, 13),
    );
    expect(left.map((s) => s.id), isNot(contains('morning')));
  });

  test('updateSchedule 404 schedule.not_found는 ScheduleGone입니다(A41)', () async {
    await expectLater(
      repository.update('missing', SchedulePatch(title: '없음')),
      throwsA(isA<ScheduleGone>()),
    );
    await expectLater(
      repository.delete('missing'),
      throwsA(isA<ScheduleGone>()),
    );
  });

  test('code가 다른 404는 ScheduleGone이 아닙니다', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://schedule.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException.badResponse(
              statusCode: 404,
              requestOptions: options,
              response: Response<Object?>(
                requestOptions: options,
                statusCode: 404,
                data: {
                  'type': 'about:blank',
                  'title': 'Not found',
                  'status': 404,
                  'code': 'route.not_found',
                  'traceId': 'test',
                },
                headers: Headers.fromMap({
                  Headers.contentTypeHeader: ['application/problem+json'],
                }),
              ),
            ),
          ),
        ),
      );
    final other = ScheduleRepository(DefaultApi(dio));

    for (final call in [
      () => other.update('x', SchedulePatch(title: '없음')),
      () => other.delete('x'),
    ]) {
      await expectLater(
        call(),
        throwsA(
          isA<ProblemError>()
              .having((e) => e.status, 'status', 404)
              .having((e) => e.code, 'code', 'route.not_found'),
        ),
      );
    }
  });

  test('그 밖의 실패는 appErrorFrom이 분류한 AppError다', () async {
    server.offline = true;

    await expectLater(
      repository.list(CalendarDate(2026, 10, 13), CalendarDate(2026, 10, 13)),
      throwsA(isA<OfflineError>()),
    );

    server.offline = false;
    await expectLater(
      repository.list(CalendarDate(2026, 10, 1), CalendarDate(2026, 12, 31)),
      throwsA(
        isA<ProblemError>()
            .having((e) => e.status, 'status', 422)
            .having((e) => e.code, 'code', 'range.too_long'),
      ),
    );
  });
}
