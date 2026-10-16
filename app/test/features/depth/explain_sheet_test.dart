import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/api/gen/model/segment.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
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
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';

import '../../support/daily_fixture.dart';
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

/// 총운 첫 문장(`daily.fortune.head`)의 오늘 그런 이유.
const _headReason = '오늘 들어오는 기운이 내 사주를 돕는 쪽이라 그래요.';

/// member 오늘 응답에서 총운 첫 문장에만 [_headReason]을 둔 그날 응답.
Daily _daily() {
  final json = memberDailyJson();
  final fortune = Map<String, dynamic>.of(
    json['fortune'] as Map<String, dynamic>,
  );
  fortune['head'] = {
    ...fortune['head'] as Map<String, dynamic>,
    'todayReason': {
      'segments': [
        {'text': _headReason},
      ],
    },
  };
  return Daily.fromJson({...json, 'fortune': fortune});
}

/// 정해 둔 오늘 응답을 돌려주는 대역.
final class _StubDaily extends DailyController {
  @override
  Future<DailyView> build() async => DailyView(
    date: CalendarDate(2026, 10, 13),
    daily: _daily(),
    stale: false,
    cacheKey: null,
  );
}

Widget _app(
  Widget home, {
  required Future<GlossaryNames> Function() glossary,
  FakeCrashReporter? crash,
}) => ProviderScope(
  overrides: [
    glossaryProvider.overrideWith((ref) => glossary()),
    dailyControllerProvider.overrideWith(_StubDaily.new),
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
    testWidgets(
      '사전에 뜻이 있으면 제목 아래 뜻을 그리고, 눌린 슬롯이 오늘 응답에 없으면 오늘 그런 이유 자리는 없습니다',
      (tester) async {
        final names = GlossaryNames(
          _names.values,
          meanings: {
            'ten_god.siksin': RenderedText(
              segments: [Segment(text: '내 안의 것을 밖으로 내는 기운이에요.')],
            ),
          },
        );
        await tester.pumpWidget(_app(_sheet, glossary: () async => names));
        await tester.pumpAndSettle();

        expect(find.text('식신'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key(SlotIds.explainSheetTermMeaning)),
            matching: find.text('내 안의 것을 밖으로 내는 기운이에요.', findRichText: true),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key(SlotIds.explainSheetTodayReason)),
          findsNothing,
        );
      },
    );

    testWidgets('사전에 뜻이 없는 용어는 뜻 자리가 없습니다', (tester) async {
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

    testWidgets('사전에 한자가 있으면 제목 옆에 한자를 그립니다', (tester) async {
      final handle = tester.ensureSemantics();
      final names = GlossaryNames(
        _names.values,
        hanja: const {'ten_god.siksin': '食神'},
      );
      await tester.pumpWidget(_app(_sheet, glossary: () async => names));
      await tester.pumpAndSettle();

      final title = tester.getRect(find.text('식신'));
      final hanja = tester.getRect(find.text('食神'));
      expect(hanja.left, greaterThan(title.right), reason: '제목과 같은 줄 끝');
      expect(hanja.bottom, closeTo(title.bottom, 8));
      // 스크린리더는 제목과 한자를 한 덩어리로 읽습니다.
      expect(find.bySemanticsLabel('식신 食神'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('한자가 없는 용어는 제목만입니다', (tester) async {
      final names = GlossaryNames(
        _names.values,
        hanja: const {'ten_god.jeongjae': '正財', 'ten_god.siksin': ''},
      );
      await tester.pumpWidget(_app(_sheet, glossary: () async => names));
      await tester.pumpAndSettle();

      expect(find.text('식신'), findsOneWidget);
      expect(find.byKey(ExplainSheetBody.hanjaKey), findsNothing);
    });

    testWidgets('오늘 화면에서 연 용어는 그 슬롯의 todayReason을 오늘 그런 이유로 그립니다', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const ExplainSheet(
            termId: 'ten_god.siksin',
            sourceSlotId: 'daily.fortune.head',
          ),
          glossary: () async => _names,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key(SlotIds.explainSheetTodayReason)),
          matching: find.text(_headReason, findRichText: true),
        ),
        findsOneWidget,
      );
    });

    testWidgets('todayReason이 없거나 day-sheet에서 열면 그 자리가 없습니다', (tester) async {
      // 가이드 질문 슬롯에는 todayReason이 없습니다.
      await tester.pumpWidget(
        _app(
          const ExplainSheet(
            termId: 'ten_god.siksin',
            sourceSlotId: 'daily.guide',
          ),
          glossary: () async => _names,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('식신'), findsOneWidget);
      expect(
        find.byKey(const Key(SlotIds.explainSheetTodayReason)),
        findsNothing,
      );

      // 그날 시트(day-sheet)는 근거 슬롯 없이 엽니다.
      await tester.pumpWidget(
        _app(
          const ExplainSheet(termId: 'ten_god.siksin'),
          glossary: () async => _names,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('식신'), findsOneWidget);
      expect(
        find.byKey(const Key(SlotIds.explainSheetTodayReason)),
        findsNothing,
      );
    });

    testWidgets('근거 보기를 누르면 눌린 슬롯의 근거 시트가 열립니다', (tester) async {
      await tester.pumpWidget(_app(_sheet, glossary: () async => _names));
      await tester.pumpAndSettle();

      await tester.tap(depthLinkTarget());
      await tester.pumpAndSettle();

      expect(find.text('근거 a.b'), findsOneWidget);
    });

    testWidgets('근거 슬롯 없이 열면(그날 시트) 근거 보기가 없습니다', (tester) async {
      await tester.pumpWidget(
        _app(
          const ExplainSheet(termId: 'ten_god.siksin'),
          glossary: () async => _names,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('식신'), findsOneWidget);
      expect(find.byType(DepthLink), findsNothing);
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

    testWidgets('제목 줄에 한자가 들어가지 않으면 한자는 제목 아래 줄로 갑니다', (tester) async {
      await tester.pumpWidget(
        _app(
          const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 120,
              child: ExplainSheetBody(title: '천을귀인 천을귀인', hanja: '天乙貴人'),
            ),
          ),
          glossary: () async => _names,
        ),
      );

      final title = tester.getRect(find.text('천을귀인 천을귀인'));
      final hanja = tester.getRect(find.text('天乙貴人'));
      expect(hanja.top, greaterThanOrEqualTo(title.bottom));
      expect(hanja.left, title.left);
    });

    testWidgets('onEvidence가 null이면 근거 링크를 그리지 않습니다', (tester) async {
      await tester.pumpWidget(
        _app(const ExplainSheetBody(title: '식신'), glossary: () async => _names),
      );

      expect(find.text('식신'), findsOneWidget);
      expect(find.byType(DepthLink), findsNothing);
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
