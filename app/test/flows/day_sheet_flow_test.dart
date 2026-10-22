import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/calendar/event_row.dart';
import 'package:myungli_diary/design/components/diary/tag_chip.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/features/calendar/application/day_sheets.dart';
import 'package:myungli_diary/features/diary/presentation/diary_page_list.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_harness.dart';
import '../support/onboarding_steps.dart' show pumpUntil, pumpUntilScreen;

final _ko = AppLocalizationsKo();

/// 그날 시트 안에서만 찾습니다(아래 오늘 화면에도 같은 컴포넌트가 있음).
Finder _inSheet(Finder finder) => find.descendant(
  of: find.byKey(const Key(ScreenIds.daySheet)),
  matching: finder,
);

/// [scenario]로 앱을 띄우고 오늘 화면에서 [date]의 그날 시트를 엽니다.
///
/// [beforeOpen]은 시트를 열기 직전에 불립니다(요청을 붙잡는 interceptor를 끼울 때). 응답을
/// 붙잡았으면 [allowOngoing]을 true로 줍니다(skeleton이 계속 숨 쉼).
Future<ProviderContainer> _openDaySheet(
  WidgetTester tester,
  CalendarDate date, {
  String scenario = 'member',
  void Function(ProviderContainer container)? beforeOpen,
  bool allowOngoing = false,
}) async {
  final container = await pumpApp(tester, scenario: scenario);
  await settleWithIo(tester);
  beforeOpen?.call(container);
  final context = tester.element(find.byKey(const ValueKey(ScreenIds.today)));
  unawaited(container.read(daySheetsProvider).open(context, date));
  await settleWithIo(tester, allowOngoing: allowOngoing);
  expect(find.byKey(const Key(ScreenIds.daySheet)), findsOneWidget);
  return container;
}

/// 대역 서버 앞에 [interceptor]를 끼웁니다(대역 서버는 항상 마지막).
void _insertBeforeFake(ProviderContainer container, Interceptor interceptor) {
  final interceptors = container.read(dioProvider).interceptors;
  interceptors.insert(interceptors.length - 1, interceptor);
}

/// `/v1/calendar/` 요청을 [gate]가 끝날 때까지 붙잡습니다.
final class _CalendarHold extends Interceptor {
  final gate = Completer<void>();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.path.startsWith('/v1/calendar/')) {
      await gate.future;
    }
    handler.next(options);
  }
}

void main() {
  testWidgets('member: 오늘 시트의 성격·일정, 일정 누름 → event-edit', (tester) async {
    covers(const Covers(exits: ['day-sheet>event-edit']));
    final container = await _openDaySheet(tester, CalendarDate(2026, 10, 13));

    expect(_inSheet(find.byType(DayCharacter)), findsOneWidget);
    final titles = [
      for (final row in tester.widgetList<EventRow>(
        _inSheet(find.byType(EventRow)),
      ))
        row.title,
    ];
    expect(titles, ['엄마 생신', '팀 주간 회의', '요가 수업']);

    await tester.tap(_inSheet(find.widgetWithText(EventRow, '팀 주간 회의')));
    await settleWithIo(tester);
    expect(
      container.read(routerProvider).state.uri.path,
      pathOf(ScreenIds.eventEdit),
    );
  });

  testWidgets('member: 일정 없는 날은 빈 문장, 일정 추가 → 그날 event-edit', (tester) async {
    covers(
      const Covers(
        states: ['day-sheet:empty'],
        exits: ['day-sheet>event-edit'],
      ),
    );
    final container = await _openDaySheet(tester, CalendarDate(2026, 10, 14));

    expect(find.text(_ko.daySheetEventEmpty), findsOneWidget);
    await tester.tap(find.text(_ko.daySheetEventAdd));
    await settleWithIo(tester);
    expect(
      container.read(routerProvider).state.uri.toString(),
      '/event-edit?date=2026-10-14',
    );
  });

  testWidgets('member: 일기 쓰기 → 새 일기 저장, 돌아오면 그날 일기 줄과 새 일기 쓰기', (tester) async {
    covers(const Covers(exits: ['day-sheet>diary-edit'], decisions: ['D49']));
    final container = await _openDaySheet(tester, CalendarDate(2026, 10, 13));
    expect(
      find.descendant(
        of: find.byKey(const Key(ScreenIds.daySheet)),
        matching: find.byType(DiarySummaryRow),
      ),
      findsNothing,
    );

    final entry = find.bySemanticsIdentifier(SlotIds.daySheetDiaryWriteCta);
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await pumpUntil(tester, () => find.byType(TextField).evaluate().isNotEmpty);
    await settleWithIo(tester);
    expect(
      container.read(routerProvider).state.uri.toString(),
      '/diary-edit?date=2026-10-13',
    );

    await tester.enterText(find.byType(TextField), '시트에서 쓴 일기');
    await tester.pump();
    await tester.tap(find.text(_ko.diaryEditSave));
    await pumpUntil(
      tester,
      () => find.text(_ko.diaryEditSavedTags).evaluate().isNotEmpty,
    );
    await pumpUntilScreen(tester, ScreenIds.diaryView);
    await settleWithIo(tester, allowOngoing: true);
    // toast가 사라질 때까지 둡니다.
    await tester.pump(const Duration(seconds: 3));
    await settleWithIo(tester);

    container.read(routerProvider).pop();
    final sheetRows = find.descendant(
      of: find.byKey(const Key(ScreenIds.daySheet)),
      matching: find.byType(DiarySummaryRow),
    );
    await pumpUntil(tester, () => sheetRows.evaluate().isNotEmpty);
    expect(sheetRows, findsOneWidget);
    expect(
      find.descendant(
        of: find.bySemanticsIdentifier(SlotIds.daySheetDiaryOpen),
        matching: find.text(_ko.daySheetDiaryOpen(1)),
      ),
      findsOneWidget,
    );
    expect(find.text(_ko.daySheetDiaryWriteCtaWritten), findsOneWidget);
  });

  testWidgets('diary-written: 지난 날 일기 줄 → 그 일기의 diary-view', (tester) async {
    covers(const Covers(exits: ['day-sheet>diary-view']));
    final container = await _openDaySheet(
      tester,
      CalendarDate(2026, 10, 12),
      scenario: 'diary-written',
    );

    // 뒤의 오늘 화면에도 오늘 일기 줄이 있어 시트 안으로 좁힙니다.
    final row = find.descendant(
      of: find.byKey(const Key(ScreenIds.daySheet)),
      matching: find.byType(DiarySummaryRow),
    );
    expect(row, findsOneWidget);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await settleWithIo(tester);
    expect(find.byKey(const ValueKey(ScreenIds.diaryView)), findsOneWidget);
    expect(
      container.read(routerProvider).state.uri.toString(),
      '/diary-view?id=7b1c2a54-3d0e-4f6a-9b21-5e8f40c1a001',
    );
  });

  testWidgets('diary-written: 일기 줄의 대표 태그 칩은 표시만이라 tag-diary로 가지 않습니다', (
    tester,
  ) async {
    final container = await _openDaySheet(
      tester,
      CalendarDate(2026, 10, 12),
      scenario: 'diary-written',
    );
    final chip = find.descendant(
      of: find.descendant(
        of: find.byKey(const Key(ScreenIds.daySheet)),
        matching: find.byType(DiarySummaryRow),
      ),
      matching: find.byType(TagChip),
    );
    await pumpUntil(tester, () => chip.evaluate().isNotEmpty);
    expect(tester.widget<TagChip>(chip).onTap, isNull);

    // 표시용 칩이라 누름은 줄로 내려가 그 일기 보기입니다(목록의 같은 태그 칩과 같음).
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await settleWithIo(tester);
    expect(find.byKey(const ValueKey(ScreenIds.tagDiary)), findsNothing);
    expect(
      container.read(routerProvider).state.uri.toString(),
      '/diary-view?id=7b1c2a54-3d0e-4f6a-9b21-5e8f40c1a001',
    );
  });

  testWidgets('member: 미래 날은 일기 입구가 없습니다(D49)', (tester) async {
    covers(const Covers(decisions: ['D49']));
    await _openDaySheet(tester, CalendarDate(2026, 10, 20));

    expect(find.bySemanticsIdentifier(SlotIds.daySheetDiaryOpen), findsNothing);
    expect(
      find.bySemanticsIdentifier(SlotIds.daySheetDiaryWriteCta),
      findsNothing,
    );
  });

  testWidgets('member: 이유 문장의 용어 칩 → 풀이 시트가 위로 쌓입니다', (tester) async {
    covers(const Covers(exits: ['day-sheet>explain-sheet']));
    await _openDaySheet(tester, CalendarDate(2026, 10, 12));

    await tester.tap(_inSheet(find.byType(TermToken)));
    await settleWithIo(tester);
    final explain = find.byKey(const Key(ScreenIds.explainSheet));
    expect(explain, findsOneWidget);
    expect(find.byKey(const Key(ScreenIds.daySheet)), findsOneWidget);
    // day-sheet의 깊이는 explain까지라 근거 보기가 없고 근거 시트로 가지 않습니다.
    expect(
      find.descendant(of: explain, matching: find.byType(DepthLink)),
      findsNothing,
    );
    expect(find.byKey(const Key(ScreenIds.evidenceSheet)), findsNothing);
  });

  testWidgets('today: 용어 칩 → 풀이 시트에는 근거 보기가 그대로 있습니다', (tester) async {
    await pumpApp(tester, scenario: 'member');
    await settleWithIo(tester);

    await tester.tap(find.byType(TermToken).first);
    await settleWithIo(tester);
    final explain = find.byKey(const Key(ScreenIds.explainSheet));
    expect(explain, findsOneWidget);
    expect(
      find.descendant(of: explain, matching: find.byType(DepthLink)),
      findsOneWidget,
    );
  });

  testWidgets('loading: 달 길흉을 기다리는 동안 skeleton, 오면 내용', (tester) async {
    covers(const Covers(states: ['day-sheet:loading']));
    final hold = _CalendarHold();
    await _openDaySheet(
      tester,
      CalendarDate(2026, 10, 13),
      beforeOpen: (container) => _insertBeforeFake(container, hold),
      allowOngoing: true,
    );

    expect(
      _inSheet(find.byKey(const ValueKey('screen-state.loading'))),
      findsOneWidget,
    );
    expect(_inSheet(find.byType(DayCharacter)), findsNothing);

    hold.gate.complete();
    await settleWithIo(tester);
    expect(_inSheet(find.byType(DayCharacter)), findsOneWidget);
  });

  testWidgets('calendar-error: 오류 화면과 다시 시도', (tester) async {
    covers(const Covers(states: ['day-sheet:error']));
    await _openDaySheet(
      tester,
      CalendarDate(2026, 10, 13),
      scenario: 'calendar-error',
    );

    expect(_inSheet(find.byType(ErrorState)), findsOneWidget);
    expect(_inSheet(find.byType(DayCharacter)), findsNothing);
    await tester.tap(_inSheet(find.text(_ko.actionRetry)));
    await settleWithIo(tester);
    expect(_inSheet(find.byType(ErrorState)), findsOneWidget);
  });
}
