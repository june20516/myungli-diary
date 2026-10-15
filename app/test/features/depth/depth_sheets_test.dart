import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/frame/sheet.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/features/depth/presentation/depth_sheets.dart';
import 'package:myungli_diary/features/depth/presentation/evidence_sheet.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

const _sheets = DepthSheets(
  explainBody: _explain,
  evidenceBody: _evidence,
  shareBody: _share,
);

/// 시트 높이가 최대치까지 차도록 긴 본문을 만듭니다.
Widget _tall(String label) => SizedBox(height: 4000, child: Text(label));

Widget _explain(String termId, String sourceSlotId) =>
    _tall('풀이 $termId $sourceSlotId');
Widget _evidence(String slotId) => _tall('근거 $slotId');
Widget _share() => _tall('공유');

Future<void> _pumpHost(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(400, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: _navigatorKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ko'),
      theme: buildTheme(
        brightness: Brightness.light,
        locale: const Locale('ko'),
      ),
      home: const SizedBox.expand(),
    ),
  );
}

BuildContext get _context => _navigatorKey.currentContext!;

double _frameHeight(WidgetTester tester) =>
    tester.getSize(find.byType(MyungliSheetFrame).last).height;

void main() {
  group('DepthSheets', () {
    testWidgets('openExplain은 half로 열리고 id가 Key와 Semantics에 붙습니다', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpHost(tester);
      unawaited(
        _sheets.openExplain(_context, termId: 'term.x', sourceSlotId: 'a.b'),
      );
      await tester.pumpAndSettle();

      expect(find.text('풀이 term.x a.b'), findsOneWidget);
      expect(_frameHeight(tester), closeTo(900 * sheetHalfFraction, 0.01));
      expect(find.byKey(const Key(ScreenIds.explainSheet)), findsOneWidget);
      expect(
        find.bySemanticsIdentifier(ScreenIds.explainSheet),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('openExplain은 시트 이름을 스크린리더에 알립니다(제목이 없는 loading·error에도)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpHost(tester);
      unawaited(
        _sheets.openExplain(_context, termId: 'term.x', sourceSlotId: 'a.b'),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(AppLocalizationsKo().depthExplain),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('openEvidence는 full로 열리고 id가 붙습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpHost(tester);
      unawaited(_sheets.openEvidence(_context, slotId: 'daily.fortune.head'));
      await tester.pumpAndSettle();

      expect(find.text('근거 daily.fortune.head'), findsOneWidget);
      expect(_frameHeight(tester), closeTo(900 - sheetFullTopGap, 0.01));
      expect(find.byKey(const Key(ScreenIds.evidenceSheet)), findsOneWidget);
      expect(
        find.bySemanticsIdentifier(ScreenIds.evidenceSheet),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('openSharePreview는 half로 열리고 id가 붙습니다', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpHost(tester);
      unawaited(_sheets.openSharePreview(_context));
      await tester.pumpAndSettle();

      expect(find.text('공유'), findsOneWidget);
      expect(_frameHeight(tester), closeTo(900 * sheetHalfFraction, 0.01));
      expect(find.byKey(const Key(ScreenIds.sharePreview)), findsOneWidget);
      expect(
        find.bySemanticsIdentifier(ScreenIds.sharePreview),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('explain 위에서 openEvidence를 부르면 겹치고 닫으면 explain으로 돌아옵니다', (
      tester,
    ) async {
      await _pumpHost(tester);
      unawaited(_sheets.openExplain(_context, termId: 't', sourceSlotId: 's'));
      await tester.pumpAndSettle();

      final explainContext = tester.element(find.text('풀이 t s'));
      unawaited(_sheets.openEvidence(explainContext, slotId: 's'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key(ScreenIds.explainSheet)), findsOneWidget);
      expect(find.byKey(const Key(ScreenIds.evidenceSheet)), findsOneWidget);

      _navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key(ScreenIds.evidenceSheet)), findsNothing);
      expect(find.byKey(const Key(ScreenIds.explainSheet)), findsOneWidget);
    });

    testWidgets('depthSheetsProvider의 근거 본문은 그 슬롯의 EvidenceSheet입니다', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final body = container.read(depthSheetsProvider).evidenceBody('s.t');
      expect(body, isA<EvidenceSheet>());
      expect((body as EvidenceSheet).slotId, 's.t');
    });

    testWidgets('openEvidence는 시트 이름(근거 시트 제목)을 스크린리더에 알립니다', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpHost(tester);
      unawaited(_sheets.openEvidence(_context, slotId: 's'));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(AppLocalizationsKo().evidenceSheetTitle),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
