import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/gen/model/schedule.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/features/schedule/application/schedule_providers.dart';
import 'package:myungli_diary/features/schedule/model/schedule_range.dart';
import 'package:myungli_diary/features/schedule/presentation/event_edit_screen.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_harness.dart';

final _ko = AppLocalizationsKo();

final Finder _screen = find.byKey(const ValueKey(ScreenIds.eventEdit));

/// 2026년 10월 달력 격자(09-27~11-07).
const _october = CalendarMonth(2026, 10);
final ScheduleRange _octoberGrid = (
  from: _october.gridStart,
  to: _october.gridEnd,
);

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

/// [scenario]로 띄우고 10월 격자 일정을 붙든 채 2026-10-25 새 일정 화면에서 제목을 적고 저장합니다.
Future<ProviderContainer> _createHike(
  WidgetTester tester, {
  required String scenario,
}) async {
  final container = await pumpApp(tester, scenario: scenario);
  final grid = container.listen(
    schedulesInRangeProvider(_octoberGrid),
    (_, _) {},
  );
  addTearDown(grid.close);
  unawaited(
    container
        .read(routerProvider)
        .push<void>(
          datedPathOf(ScreenIds.eventEdit, CalendarDate(2026, 10, 25)),
        ),
  );
  await settleWithIo(tester);
  await tester.enterText(
    find.descendant(
      of: find.byKey(const ValueKey(SlotIds.eventEditTitleHint)),
      matching: find.byType(EditableText),
    ),
    '등산',
  );
  await tester.pump();
  final save = find.byKey(EventEditScreen.saveKey);
  await tester.ensureVisible(save);
  await tester.tap(save);
  await settleWithIo(tester);
  return container;
}

List<String> _gridTitles(ProviderContainer container) => [
  for (final schedule
      in container.read(schedulesInRangeProvider(_octoberGrid)).value ??
          const <Schedule>[])
    schedule.title,
];

void main() {
  setUpAll(ensureTimeZonesInitialized);

  testWidgets('새 일정을 저장하면 닫히고 보이는 달 범위를 다시 받아 점이 갱신됩니다 (A34)', (tester) async {
    covers(const Covers(decisions: ['D47', 'D39']));
    final container = await _createHike(tester, scenario: 'member');

    expect(_fake(container).callCountOf('createSchedule'), 1);
    expect(_screen, findsNothing);
    expect(find.byKey(const ValueKey(ScreenIds.today)), findsOneWidget);
    expect(_gridTitles(container), contains('등산'));
  });

  testWidgets('schedule-save-error: 저장 실패 toast를 띄우고 화면과 입력이 남습니다', (
    tester,
  ) async {
    covers(const Covers(states: ['event-edit:error']));
    final container = await _createHike(
      tester,
      scenario: 'schedule-save-error',
    );

    expect(_fake(container).callCountOf('createSchedule'), 1);
    expect(find.text(_ko.eventEditSaveFailed), findsOneWidget);
    expect(_screen, findsOneWidget);
    expect(find.text('등산'), findsOneWidget);
    expect(_gridTitles(container), isNot(contains('등산')));
    // toast가 저절로 사라지게 시간을 보냅니다(테스트 끝에 timer가 남지 않게).
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('일정 편집을 연 채 로그아웃하면 member 가드로 welcome에 갑니다', (tester) async {
    final container = await pumpApp(tester, scenario: 'member');
    unawaited(
      container
          .read(routerProvider)
          .push<void>(
            datedPathOf(ScreenIds.eventEdit, CalendarDate(2026, 10, 25)),
          ),
    );
    await settleWithIo(tester);
    expect(_screen, findsOneWidget);

    await tester.runAsync(container.read(tokenStoreProvider).signOut);
    await settleWithIo(tester);

    expect(_screen, findsNothing);
    expect(find.byKey(const ValueKey(ScreenIds.welcome)), findsOneWidget);
    expect(
      container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      '/welcome',
    );
  });
}
