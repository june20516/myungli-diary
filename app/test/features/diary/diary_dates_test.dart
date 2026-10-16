import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';

import '../../support/schedule_test_server.dart';

const _october = CalendarMonth(2026, 10);

void main() {
  late ScheduleTestServer server;
  late FakeCrashReporter reporter;
  late ProviderContainer container;

  setUp(() {
    server = ScheduleTestServer();
    reporter = FakeCrashReporter();
    container = ProviderContainer(
      overrides: [
        restClientProvider.overrideWithValue(server.client()),
        crashReporterProvider.overrideWithValue(reporter),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<Set<CalendarDate>> datesOf(CalendarMonth month) async {
    final provider = diaryDatesProvider(month);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    return await container.read(provider.future);
  }

  test('보이는 격자(gridStart~gridEnd)의 일기 날짜를 limit 100으로 묻는다(A33)', () async {
    server.diaryDates = ['2026-09-30', '2026-10-12', '2026-10-13'];

    expect(await datesOf(_october), {
      CalendarDate(2026, 9, 30),
      CalendarDate(2026, 10, 12),
      CalendarDate(2026, 10, 13),
    });
    expect(server.requests.single.queryParameters, {
      'from': '2026-09-27',
      'to': '2026-11-07',
      'limit': 100,
    });
    expect(reporter.errors, isEmpty);
  });

  test('실패하면 빈 집합이고 crash 요약만 남긴다(A33)', () async {
    server.diaryFailureStatus = 503;

    expect(await datesOf(_october), isEmpty);
    expect(reporter.errors.single.status, 503);
  });

  test('연결 없음·시간 초과는 빈 집합이고 보고하지 않는다(통신 환경 탓)', () async {
    server.offline = true;
    expect(await datesOf(_october), isEmpty);

    server
      ..offline = false
      ..timeout = true;
    expect(await datesOf(const CalendarMonth(2026, 11)), isEmpty);

    expect(reporter.errors, isEmpty);
  });
}
