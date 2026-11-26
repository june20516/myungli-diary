import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/model/me.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/features/diary/application/diary_providers.dart';

import '../support/schedule_test_server.dart';

/// 서로 붙이지 않은 두 계정(#1345의 카카오 A, LINE B).
const _accountA = '0b3f6a9e-6c1d-4f43-9a52-3c1e7d2b8a10';
const _accountB = '5d2c8e1f-3a4b-4c6d-8e9f-0a1b2c3d4e5f';

final _today = CalendarDate(2026, 10, 13);

Me _me(String accountId) => Me.fromJson({
  'accountId': accountId,
  'status': 'active',
  'consentRequired': false,
  'requiredConsents': <Object?>[],
  'hasProfile': true,
  'adFree': {'active': false},
  'insight': {'active': false},
});

/// 지금 로그인한 계정의 내 정보. null이면 로그아웃입니다.
final class _SignedIn extends Notifier<Me?> {
  @override
  Me? build() => null;

  // ignore: use_setters_to_change_properties, 테스트가 호출하는 설정 함수
  void set(Me? me) => state = me;
}

final _signedInProvider = NotifierProvider<_SignedIn, Me?>(_SignedIn.new);

void main() {
  late ScheduleTestServer server;
  late ProviderContainer container;

  setUp(() {
    server = ScheduleTestServer();
    container = ProviderContainer(
      overrides: [
        ...entryOverrides,
        meProvider.overrideWith((ref) => ref.watch(_signedInProvider)),
        restClientProvider.overrideWithValue(server.client()),
        crashReporterProvider.overrideWithValue(FakeCrashReporter()),
      ],
    );
    addTearDown(container.dispose);
  });

  /// 로그아웃한 뒤 [next] 계정으로 로그인합니다. 그 계정의 server 일기는 [diaryDates]입니다.
  void switchTo(String next, {required List<String> diaryDates}) {
    final signedIn = container.read(_signedInProvider.notifier)..set(null);
    server.diaryDates = diaryDates;
    signedIn.set(_me(next));
  }

  // 오늘 화면(todayContentProvider, autoDispose 아님)은 오늘 일기 목록을 계정이 바뀌어도
  // 붙들고 있습니다. 붙든 채로 계정을 바꿔도 새 계정의 목록을 다시 받아야 합니다(#1345 1).
  test('붙든 그날 일기 목록은 다른 계정으로 로그인하면 새 계정 것으로 다시 받는다', () async {
    container.read(_signedInProvider.notifier).set(_me(_accountB));
    server.diaryDates = ['2026-10-13'];
    final held = container.listen(diariesOnProvider(_today), (_, _) {});
    addTearDown(held.close);
    expect(
      await container.read(diariesOnProvider(_today).future),
      hasLength(1),
    );

    switchTo(_accountA, diaryDates: const []);

    expect(await container.read(diariesOnProvider(_today).future), isEmpty);
  });

  test('붙든 달력 일기 도장도 다른 계정으로 로그인하면 새 계정 것으로 다시 받는다', () async {
    const october = CalendarMonth(2026, 10);
    container.read(_signedInProvider.notifier).set(_me(_accountB));
    server.diaryDates = ['2026-10-12'];
    final held = container.listen(diaryDatesProvider(october), (_, _) {});
    addTearDown(held.close);
    expect(await container.read(diaryDatesProvider(october).future), {
      CalendarDate(2026, 10, 12),
    });

    switchTo(_accountA, diaryDates: const []);

    expect(await container.read(diaryDatesProvider(october).future), isEmpty);
  });
}
