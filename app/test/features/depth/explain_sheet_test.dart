import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/design/components/depth/explain_sheet_body.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/theme/app_theme.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/depth/presentation/explain_sheet.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/data/glossary_repository.dart';

import '../../support/depth_link_finders.dart';

final _ko = AppLocalizationsKo();

const _names = GlossaryNames({
  'ten_god': {'siksin': '식신'},
});

final _depthSheets = DepthSheets(
  explainBody: (termId, sourceSlotId) =>
      ExplainSheet(termId: termId, sourceSlotId: sourceSlotId),
  evidenceBody: (slotId) => Text('근거 $slotId'),
  shareBody: SizedBox.shrink,
);

Widget _app(
  Widget home, {
  required Future<GlossaryNames> Function() glossary,
  FakeCrashReporter? crash,
}) => ProviderScope(
  overrides: [
    glossaryProvider.overrideWith((ref) => glossary()),
    depthSheetsProvider.overrideWithValue(_depthSheets),
    crashReporterProvider.overrideWithValue(crash ?? FakeCrashReporter()),
  ],
  child: MaterialApp(
    locale: const Locale('ko'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildTheme(brightness: Brightness.light, locale: const Locale('ko')),
    home: Scaffold(body: SizedBox(height: 400, child: home)),
  ),
);

const _sheet = ExplainSheet(termId: 'ten_god.siksin', sourceSlotId: 'a.b');

void main() {
  group('ExplainSheet', () {
    testWidgets('제목은 사전의 용어 이름이고 뜻·이유 자리는 없습니다(A22)', (tester) async {
      await tester.pumpWidget(_app(_sheet, glossary: () async => _names));
      await tester.pumpAndSettle();

      expect(find.text('식신'), findsOneWidget);
      expect(
        find.byKey(const Key(SlotIds.explainSheetTermMeaning)),
        findsNothing,
      );
      expect(
        find.byKey(const Key(SlotIds.explainSheetTodayReason)),
        findsNothing,
      );
      final link = tester.widget<DepthLink>(find.byType(DepthLink));
      expect(link.variant, DepthLinkVariant.block);
      expect(link.label, _ko.depthLinkEvidence);
    });

    testWidgets('근거 보기를 누르면 눌린 슬롯의 근거 시트가 열립니다', (tester) async {
      await tester.pumpWidget(_app(_sheet, glossary: () async => _names));
      await tester.pumpAndSettle();

      await tester.tap(depthLinkTarget());
      await tester.pumpAndSettle();

      expect(find.text('근거 a.b'), findsOneWidget);
    });

    testWidgets('loading: 사전을 받는 동안 skeleton이고 끝나면 내용입니다', (tester) async {
      final completer = Completer<GlossaryNames>();
      await tester.pumpWidget(_app(_sheet, glossary: () => completer.future));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(const ValueKey('screen-state.loading')),
        findsOneWidget,
      );
      expect(find.byType(DepthLink), findsNothing);

      completer.complete(_names);
      await tester.pumpAndSettle();
      expect(find.text('식신'), findsOneWidget);
    });

    testWidgets('사전을 다시 받는 동안에는 이전 이름을 그대로 보입니다(stale-while-revalidate)', (
      tester,
    ) async {
      var attempts = 0;
      final refetch = Completer<GlossaryNames>();
      await tester.pumpWidget(
        _app(
          _sheet,
          glossary: () =>
              ++attempts == 1 ? Future.value(_names) : refetch.future,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('식신'), findsOneWidget);

      ProviderScope.containerOf(tester.element(find.byType(ExplainSheet)))
          .invalidate(glossaryProvider);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('식신'), findsOneWidget);
      expect(find.byKey(const ValueKey('screen-state.loading')), findsNothing);

      refetch.complete(
        const GlossaryNames({
          'ten_god': {'siksin': '식신(새 이름)'},
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('식신(새 이름)'), findsOneWidget);
    });

    testWidgets('error: 실패하면 오류 화면, 다시 시도하면 내용입니다', (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        _app(
          _sheet,
          glossary: () async {
            if (++attempts == 1) throw const OfflineError();
            return _names;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsOneWidget);
      await tester.tap(find.text(_ko.actionRetry));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsNothing);
      expect(find.text('식신'), findsOneWidget);
    });

    testWidgets('사전에 없는 용어는 오류 화면이고 보고에는 오류 요약만 남습니다(D64)', (tester) async {
      final crash = FakeCrashReporter();
      await tester.pumpWidget(
        _app(
          const ExplainSheet(termId: 'ten_god.nope', sourceSlotId: 'a.b'),
          glossary: () async => _names,
          crash: crash,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.byType(DepthLink), findsNothing);
      expect(crash.errors, hasLength(1));
      expect(crash.errors.single.errorType, 'UnexpectedError');
    });
  });

  group('ExplainSheetBody', () {
    RenderedText text(String value) =>
        RenderedText(segments: [Segment(text: value)]);

    Widget body({RenderedText? meaning, RenderedText? todayReason}) => _app(
      ExplainSheetBody(
        title: '식신',
        meaning: meaning,
        todayReason: todayReason,
        onEvidence: () {},
      ),
      glossary: () async => _names,
    );

    testWidgets('뜻과 이유를 주면 제목 아래에 순서대로 그립니다', (tester) async {
      await tester.pumpWidget(
        body(meaning: text('내가 낸 것이 흐르는 기운'), todayReason: text('오늘 월지와 닿아요')),
      );

      expect(
        find.byKey(const Key(SlotIds.explainSheetTermMeaning)),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key(SlotIds.explainSheetTodayReason)),
        findsOneWidget,
      );
      final title = tester.getTopLeft(find.text('식신')).dy;
      final meaning = tester.getTopLeft(find.textContaining('흐르는')).dy;
      final reason = tester.getTopLeft(find.textContaining('월지')).dy;
      final link = tester.getTopLeft(find.byType(DepthLink)).dy;
      expect(title < meaning && meaning < reason && reason < link, isTrue);
    });

    testWidgets('null인 자리는 그리지 않습니다', (tester) async {
      await tester.pumpWidget(body(meaning: text('뜻만 있어요')));

      expect(
        find.byKey(const Key(SlotIds.explainSheetTermMeaning)),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key(SlotIds.explainSheetTodayReason)),
        findsNothing,
      );
    });
  });
}
