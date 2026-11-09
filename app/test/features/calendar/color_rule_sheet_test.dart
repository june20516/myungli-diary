import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/depth_sheet_bodies.dart';
import 'package:myungli_diary/app/router/sheet_registry.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/calendar/score_row.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/elements/list_divider.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/features/calendar/application/color_rule_sheets.dart';
import 'package:myungli_diary/features/calendar/model/score_item_meta.dart';
import 'package:myungli_diary/features/calendar/presentation/color_rule_sheet.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';

import '../../support/fonts.dart';

const _scoreItemNames = {
  'yongsin_day': '용신의 날',
  'gwiin_day': '귀인의 날',
  'hap': '합',
  'gisin_day': '기신의 날',
  'chung_day_or_month': '일지나 월지와의 충',
  'chung_other': '다른 자리와의 충',
  'hyeong': '형',
};

Widget _app({
  required Map<String, String> names,
  FakeCrashReporter? crash,
  double textScale = 1,
}) => ProviderScope(
  overrides: [
    glossaryProvider.overrideWith(
      (ref) async => GlossaryNames({'score_item': names}),
    ),
    crashReporterProvider.overrideWithValue(crash ?? FakeCrashReporter()),
  ],
  child: MaterialApp(
    locale: const Locale('ko'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildTheme(brightness: Brightness.light, locale: const Locale('ko')),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: const Scaffold(body: ColorRuleSheet()),
  ),
);

void main() {
  setUpAll(loadBundledFonts);

  test('일곱 줄 상수: id와 점수(A116), 점수 0 없음', () {
    expect(
      [for (final r in ScoreItemMeta.rule) (r.id, r.score)],
      [
        ('yongsin_day', 2),
        ('gwiin_day', 2),
        ('hap', 1),
        ('gisin_day', -1),
        ('chung_day_or_month', -2),
        ('chung_other', -1),
        ('hyeong', -1),
      ],
    );
  });

  testWidgets('제목, 설명, 일곱 줄 순서와 점, 줄 사이 divider', (tester) async {
    await tester.pumpWidget(_app(names: _scoreItemNames));
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ColorRuleSheet)),
    );

    expect(find.text(l10n.colorRuleSheetSheetTitle), findsOneWidget);
    expect(find.textContaining('그 날에 들어오는 기운을'), findsOneWidget);

    final rows = tester.widgetList<ScoreRow>(find.byType(ScoreRow)).toList();
    expect([for (final r in rows) r.name], _scoreItemNames.values.toList());
    expect([for (final r in rows) r.score], [2, 2, 1, -1, -2, -1, -1]);
    expect([
      for (final r in rows) r.variant,
    ], everyElement(ScoreRowVariant.rule));
    // 줄 사이에만 divider(첫 줄 위와 끝 줄 아래 없음).
    expect(find.byType(ListDivider), findsNWidgets(6));
    // 점 개수: 2+2+1+1+2+1+1.
    expect(
      find.descendant(
        of: find.byKey(ScoreRow.dotsKey),
        matching: find.byType(DecoratedBox),
      ),
      findsNWidgets(10),
    );
  });

  testWidgets('태그는 누를 수 없는 표시', (tester) async {
    await tester.pumpWidget(_app(names: _scoreItemNames));
    await tester.pump();
    final tags = tester.widgetList<HanjaTag>(find.byType(HanjaTag));
    expect(tags.length, 7);
    expect(tags.every((tag) => tag.onTap == null), isTrue);
  });

  testWidgets('사전에 없는 항목은 줄을 그리지 않고 비치명으로 한 번만 기록', (tester) async {
    final crash = FakeCrashReporter();
    await tester.pumpWidget(
      _app(names: {..._scoreItemNames}..remove('hyeong'), crash: crash),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(ScoreRow), findsNWidgets(6));
    expect(find.text('형'), findsNothing);
    expect(crash.errors.length, 1);
    expect(crash.errors.single.toString(), contains('score_item.hyeong'));

    // 다시 그려도 같은 빈칸을 거듭 기록하지 않음.
    await tester.pumpWidget(
      _app(names: {..._scoreItemNames}..remove('hyeong'), crash: crash),
    );
    await tester.pump();
    await tester.pump();
    expect(crash.errors.length, 1);
  });

  for (final scale in [1.3, 2.0]) {
    testWidgets('글자 $scale배에서 넘치지 않음(시트 안 스크롤)', (tester) async {
      await tester.pumpWidget(_app(names: _scoreItemNames, textScale: scale));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('사전을 받기 전에도 일곱 줄 높이를 지키고 읽지 않음', (tester) async {
    await tester.pumpWidget(_app(names: _scoreItemNames));
    final contentFinder = find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Column),
    );
    final before = tester.getSize(contentFinder.first).height;
    final hidden = find.descendant(
      of: find.byType(ColorRuleSheet),
      matching: find.byType(Visibility),
    );
    expect(hidden, findsNWidgets(7));
    await tester.pump();
    await tester.pump();
    expect(hidden, findsNothing);
    expect(find.byType(ScoreRow), findsNWidgets(7));
    expect(tester.getSize(contentFinder.first).height, before);
  });

  test('sheetRegistry: color-rule-sheet는 상태도 출구도 없음', () {
    final spec = sheetRegistry[ScreenIds.colorRuleSheet]!;
    expect(spec.handledStates, isEmpty);
    expect(spec.exits, isEmpty);
  });

  test('app의 override가 실제 본문을 잇습니다', () {
    final wired = ProviderContainer(overrides: colorRuleSheetBodyOverrides);
    addTearDown(wired.dispose);
    expect(wired.read(colorRuleSheetsProvider).body(), isA<ColorRuleSheet>());
  });
}
