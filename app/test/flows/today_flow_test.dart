import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/rendering/offscreen_renderer.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/share_button.dart';
import 'package:myungli_diary/design/components/calendar/event_row.dart';
import 'package:myungli_diary/design/components/depth/evidence_lock_panel.dart';
import 'package:myungli_diary/design/components/depth/evidence_sheet_body.dart';
import 'package:myungli_diary/design/components/depth/weighing_note.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/components/today/color_pair_sheet_body.dart';
import 'package:myungli_diary/design/components/today/date_header.dart';
import 'package:myungli_diary/design/components/today/lucky_card.dart';
import 'package:myungli_diary/design/components/today/tag_sentence_list.dart';
import 'package:myungli_diary/design/components/today/time_band.dart';
import 'package:myungli_diary/design/elements/app_icon.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/features/depth/application/depth_sheets.dart';
import 'package:myungli_diary/features/depth/application/evidence_unlock_controller.dart';
import 'package:myungli_diary/features/depth/application/explain_content.dart';
import 'package:myungli_diary/features/depth/presentation/evidence_sheet.dart';
import 'package:myungli_diary/features/depth/presentation/explain_sheet.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/model/glossary_names.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';
import 'package:myungli_diary/features/today/presentation/today_screen.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_harness.dart';
import '../support/daily_fixture.dart';
import '../support/depth_link_finders.dart';
import '../support/onboarding_steps.dart' show pumpUntil;
import '../support/sheet_close.dart';
import '../support/test_today.dart';

final _ko = AppLocalizationsKo();

final Finder _content = find.byType(DateHeader);

Future<void> _settleToday(WidgetTester tester) => pumpUntil(
  tester,
  () =>
      _content.evaluate().isNotEmpty ||
      find.byType(ErrorState).evaluate().isNotEmpty,
);

/// 사주 기운 섹션의 [rank] 대표 태그를 눌러 사주 기운 시트를 엽니다.
Future<void> _openFeaturedTag(WidgetTester tester, int rank) async {
  final featured = find.descendant(
    of: find.byKey(TodayScreen.featuredCardKey),
    matching: find.byType(HanjaTag),
  );
  await tester.ensureVisible(featured.at(rank));
  await tester.pumpAndSettle();
  await tester.tap(featured.at(rank));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key(ScreenIds.tagSheet)), findsOneWidget);
}

Future<ProviderContainer> _openToday(
  WidgetTester tester, {
  String scenario = 'member',
}) async {
  final container = await pumpApp(tester, scenario: scenario);
  await _settleToday(tester);
  expect(find.byKey(const ValueKey(ScreenIds.today)), findsOneWidget);
  return container;
}

/// 항상 같은 바이트를 돌려주는 렌더러 대역(흐름 테스트는 실제 PNG 인코딩을 기다리지 않습니다).
final class _FixedRenderer implements OffscreenRenderer {
  int calls = 0;

  @override
  Future<Uint8List> render(Widget image, Size logicalSize) async {
    calls++;
    return Uint8List.fromList([1, 2, 3]);
  }
}

/// `/v1/daily/`를 [offline]일 때 연결 오류로 끊습니다.
final class _DailyNetwork extends Interceptor {
  bool offline = true;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (offline && options.path.startsWith('/v1/daily/')) {
      handler.reject(
        DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
        true,
      );
      return;
    }
    handler.next(options);
  }
}

/// `/v1/daily/`를 [hold]가 끝날 때까지 붙잡습니다.
final class _DailyHold extends Interceptor {
  final hold = Completer<void>();
  bool requested = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.path.startsWith('/v1/daily/')) {
      requested = true;
      await hold.future;
    }
    handler.next(options);
  }
}

/// 잠금 해제 뒤 다시 받는 `/v1/daily/`를 [armed] 뒤부터 붙잡고, 풀리면 한 번은 503으로 끊습니다.
final class _UnlockRefetch extends Interceptor {
  bool armed = false;
  bool requested = false;
  bool _failed = false;
  final release = Completer<void>();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!armed || !options.path.startsWith('/v1/daily/')) {
      handler.next(options);
      return;
    }
    requested = true;
    await release.future;
    if (!_failed) {
      _failed = true;
      handler.reject(
        DioException.badResponse(
          statusCode: 503,
          requestOptions: options,
          response: Response<Object?>(requestOptions: options, statusCode: 503),
        ),
        true,
      );
      return;
    }
    handler.next(options);
  }
}

final NotifierProvider<TestToday, CalendarDate> _testTodayProvider =
    testTodayProvider(CalendarDate(2026, 10, 13));

/// 열린 시트를 바깥(scrim)을 눌러 한 단계씩 모두 닫고 사라졌는지 확인합니다(V100).
Future<void> _closeSheet(WidgetTester tester) async {
  await tapSheetScrimUntilClosed(tester);
  expect(find.byKey(const Key(ScreenIds.evidenceSheet)), findsNothing);
  expect(find.byKey(const Key(ScreenIds.explainSheet)), findsNothing);
}

void main() {
  setUpAll(ensureTimeZonesInitialized);

  testWidgets('member: 용어 칩 → 풀이 시트, 근거 보기 → 근거 시트, 공유 → 공유 미리보기', (
    tester,
  ) async {
    covers(
      const Covers(
        exits: [
          'today>explain-sheet',
          'explain-sheet>evidence-sheet',
          'today>evidence-sheet',
          'today>share-preview',
        ],
      ),
    );
    await _openToday(tester);

    await tester.tap(find.byType(TermToken).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key(ScreenIds.explainSheet)), findsOneWidget);
    // 첫 칩은 총운의 `ten_god_group.bigyeop`이고,
    // 뜻은 member `getGlossary.json`의 meanings입니다.
    expect(
      find.descendant(
        of: find.byKey(const Key(SlotIds.explainSheetTermMeaning)),
        matching: find.text(
          '비견과 겁재를 함께 부르는 이름으로, 나와 어깨를 나란히 하는 기운이에요. '
          '나를 지키고 내 몫을 챙기려는 힘이 여기에 들어요.',
          findRichText: true,
        ),
      ),
      findsOneWidget,
    );
    // 풀이 시트의 근거 보기: 풀이 시트 위에 근거 시트가 겹쳐 열립니다.
    await tester.tap(
      depthLinkTarget(of: find.byKey(const Key(ScreenIds.explainSheet))),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key(ScreenIds.evidenceSheet)), findsOneWidget);
    expect(find.byKey(const Key(ScreenIds.explainSheet)), findsOneWidget);
    // 바깥을 누르면 쌓인 시트가 모두 닫힙니다.
    await _closeSheet(tester);
    expect(find.byKey(const Key(ScreenIds.evidenceSheet)), findsNothing);
    expect(find.byKey(const Key(ScreenIds.explainSheet)), findsNothing);

    // 총운 끝의 근거 보기.
    await tester.tap(
      depthLinkTarget(of: find.byKey(const Key(SlotIds.todayFortuneHead))),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key(ScreenIds.evidenceSheet)), findsOneWidget);
    await _closeSheet(tester);
    expect(find.byKey(const Key(ScreenIds.evidenceSheet)), findsNothing);

    await tester.tap(find.byType(ShareButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key(ScreenIds.sharePreview)), findsOneWidget);
  });

  testWidgets('evidence-unlocked: 용어 → 풀이 시트의 한자·오늘 그런 이유 → 근거 보기 → 판정 근거 문장', (
    tester,
  ) async {
    covers(
      const Covers(
        exits: ['today>explain-sheet', 'explain-sheet>evidence-sheet'],
      ),
    );
    await _openToday(tester, scenario: 'evidence-unlocked');

    // 첫 칩은 총운의 `ten_god_group.bigyeop`입니다. 한자는 `getGlossary.json`의 hanja,
    // 오늘 그런 이유는 `getDaily.json` 총운 첫 문장의 todayReason입니다.
    await tester.tap(find.byType(TermToken).first);
    await tester.pumpAndSettle();
    final explain = find.byKey(const Key(ScreenIds.explainSheet));
    expect(
      find.descendant(of: explain, matching: find.text('比劫')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key(SlotIds.explainSheetTodayReason)),
        matching: find.text(
          '오늘 들어오는 기운이 내 사주를 돕는 쪽이라 그래요.',
          findRichText: true,
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(depthLinkTarget(of: explain));
    await tester.pumpAndSettle();
    final evidence = find.byKey(const Key(ScreenIds.evidenceSheet));
    expect(evidence, findsOneWidget);
    expect(
      find.descendant(of: evidence, matching: find.byType(EvidenceLockPanel)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey(SlotIds.evidenceSheetBasisBody)),
        matching: find.text(
          '억부법으로 용신을 정했어요. 내 일간은 힘이 센 편이라, 그 힘을 고르게 맞추는 오행을 골랐어요.',
          findRichText: true,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'evidence-unlocked: 밤 시간 칩 → 시트 본문, 24시간 띠, 제목 줄 끝 근거 보기 → 그 카드의 근거',
    (tester) async {
      covers(
        const Covers(
          exits: ['today>explain-sheet', 'explain-sheet>evidence-sheet'],
          decisions: ['D122', 'D123'],
        ),
      );
      await _openToday(tester, scenario: 'evidence-unlocked');

      // 대역 시계는 정오라 밤 칩은 오늘 밤 카드이고 때 낱말은 "오늘 밤"입니다.
      final night = find.byKey(
        LuckyCardRow.chipKey(LuckyCardVariant.time, period: AppTimeOfDay.night),
      );
      await tester.ensureVisible(night);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: night,
          matching: find.text(_ko.todayLuckyTimeNightTonight),
        ),
        findsOneWidget,
      );
      await tester.tap(night);
      await tester.pumpAndSettle();
      final explain = find.byKey(const Key(ScreenIds.explainSheet));
      expect(explain, findsOneWidget);
      expect(
        find.descendant(
          of: explain,
          matching: find.text(_ko.todayLuckyTimeNightTitle),
        ),
        findsOneWidget,
      );
      final band = find.descendant(
        of: explain,
        matching: find.byType(TimeBand),
      );
      expect(band, findsOneWidget);
      // 칸 눈금은 fixture 낮 카드와 오늘 밤 카드의 hours(서울 진시 07:30, 해시 21:30)입니다(#1064).
      final shown = tester.widget<TimeBand>(band);
      expect(
        (shown.startTick.time, shown.boundaryTick.time, shown.endTick.time),
        ('07:30', '21:30', '07:30'),
      );
      // 정오라 낮 일곱 칸이 앞이고, 지금 꼬리표는 프로필 시간대 벽시계입니다.
      expect(
        find.descendant(
          of: find.byKey(TimeBand.nowTagKey),
          matching: find.text(_ko.todayLuckyTimeBandNow('12:00')),
        ),
        findsOneWidget,
      );
      final link = depthLinkTarget(of: explain);
      expect(link, findsOneWidget);
      // 근거 진입점은 시트 제목 줄 오른쪽 끝이라 띠보다 위입니다(V130).
      expect(
        tester.getBottomLeft(link).dy,
        lessThan(tester.getTopLeft(band).dy),
      );

      await tester.tap(link);
      await tester.pumpAndSettle();
      final evidence = find.byKey(const Key(ScreenIds.evidenceSheet));
      expect(evidence, findsOneWidget);
      // 밤 카드 문장의 근거입니다(같은 슬롯의 낮 카드가 아니라 카드로 찾음, A134).
      expect(
        find.descendant(
          of: evidence,
          matching: find.text(
            '택일 원전이 황도라 해서 길하게 꼽는 시간인지도 함께 봤어요.',
            findRichText: true,
          ),
        ),
        findsOneWidget,
      );
      await _closeSheet(tester);
      expect(evidence, findsNothing);
    },
  );

  /// 색이 둘인 날 [scenario]에서 알약의 둘째 칸을 눌러 두 색 시트를 열고, [colorIndex]째 색의
  /// 근거 진입점으로 근거 시트를 엽니다. 열린 근거 시트 본문을 돌려줍니다.
  Future<EvidenceSheetBody> openPairEvidence(
    WidgetTester tester, {
    required String scenario,
    required int colorIndex,
  }) async {
    await _openToday(tester, scenario: scenario);
    final chip = find.byKey(LuckyCardRow.chipKey(LuckyCardVariant.color));
    expect(chip, findsOneWidget);
    // 칩 하나에 검정(내 균형 기준)과 노랑(원전 기준) 두 칸이고 이름표는 없습니다.
    final first = find.byKey(LuckyChip.pairHalfKey(0));
    final second = find.byKey(LuckyChip.pairHalfKey(1));
    expect(
      find.descendant(of: first, matching: find.text('검정')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: second, matching: find.text('노랑')),
      findsOneWidget,
    );
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(second);
    await tester.pumpAndSettle();

    final explain = find.byKey(const Key(ScreenIds.explainSheet));
    expect(explain, findsOneWidget);
    for (final text in [
      _ko.todayLuckyColorName,
      _ko.todayLuckyColorPairIntro,
      '검정',
      '노랑',
    ]) {
      expect(
        find.descendant(of: explain, matching: find.text(text)),
        findsOneWidget,
        reason: text,
      );
    }
    for (final (slot, text) in [
      (SlotIds.todayLuckyColorBody, '내 사주의 균형으로 보면 검정이 잘 맞아요.'),
      (SlotIds.todayLuckyColorSecondBody, '원전의 해석에 따르면 오늘은 노랑도 어울려요.'),
    ]) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey(slot)),
          matching: find.text(text, findRichText: true),
        ),
        findsOneWidget,
        reason: slot,
      );
    }
    final section = find.byKey(ColorPairSheetBody.sectionKey(colorIndex));
    expect(depthLinkTarget(of: explain), findsNWidgets(2));
    await tester.tap(depthLinkTarget(of: section));
    await tester.pumpAndSettle();
    final evidence = find.byKey(const Key(ScreenIds.evidenceSheet));
    expect(evidence, findsOneWidget);
    return tester.widget<EvidenceSheetBody>(
      find.descendant(of: evidence, matching: find.byType(EvidenceSheetBody)),
    );
  }

  testWidgets('daily-pair-virtue: 두 칸 알약 → 두 색 시트 → 둘째 색 근거(잠김, 그 카드의 앞부분)', (
    tester,
  ) async {
    covers(
      const Covers(
        exits: ['today>explain-sheet', 'explain-sheet>evidence-sheet'],
        decisions: ['D119', 'D123'],
      ),
    );
    final body = await openPairEvidence(
      tester,
      scenario: 'daily-pair-virtue',
      colorIndex: 1,
    );
    expect(body.state, DepthLinkState.locked);
    expect(body.basisLead, isNotNull);
    // 두 카드는 같은 슬롯이라 카드 id로 둘째 색 카드의 근거를 엽니다(A134).
    expect(
      tester.widget<EvidenceSheet>(find.byType(EvidenceSheet)).slotId,
      'daily.color#secondColor',
    );
    await _closeSheet(tester);
  });

  testWidgets('daily-pair-virtue-unlocked: 두 색 시트의 첫째 색 근거는 열린 그 카드 근거 전부', (
    tester,
  ) async {
    covers(
      const Covers(
        exits: ['today>explain-sheet', 'explain-sheet>evidence-sheet'],
        decisions: ['D119', 'D123'],
      ),
    );
    final body = await openPairEvidence(
      tester,
      scenario: 'daily-pair-virtue-unlocked',
      colorIndex: 0,
    );
    expect(body.state, DepthLinkState.unlocked);
    expect(
      tester.widget<EvidenceSheet>(find.byType(EvidenceSheet)).slotId,
      'daily.color#color',
    );
    // 첫째 색 카드의 근거 셋(둘째 색은 둘)이고 셋째가 두 기준이 갈린 까닭입니다.
    expect(body.basis, hasLength(3));
    expect(
      find.descendant(
        of: find.byKey(const Key(ScreenIds.evidenceSheet)),
        matching: find.textContaining(
          '내 균형을 기준으로 한 검정을 첫째 색으로',
          findRichText: true,
        ),
      ),
      findsOneWidget,
    );
    await _closeSheet(tester);
  });

  /// 덕일인 날 [scenario]에서 날짜 머리의 [index]째 덕일 알약을 눌러 그 덕의 풀이 시트를 열고
  /// ([label] 제목, [body] 본문), 근거 진입점으로 근거 시트를 엽니다. 근거 시트 본문을 돌려줍니다.
  Future<EvidenceSheetBody> openVirtueEvidence(
    WidgetTester tester, {
    required String scenario,
    required int index,
    required String label,
    required String body,
  }) async {
    await _openToday(tester, scenario: scenario);
    final pills = find.descendant(
      of: find.byType(DateHeader),
      matching: find.byType(HanjaTag),
    );
    expect(pills, findsNWidgets(2));
    await tester.tap(pills.at(index));
    await tester.pumpAndSettle();
    final explain = find.byKey(const Key(ScreenIds.explainSheet));
    expect(explain, findsOneWidget);
    expect(
      find.descendant(of: explain, matching: find.text(label)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: explain,
        matching: find.text(body, findRichText: true),
      ),
      findsOneWidget,
    );
    // 원국의 천덕귀인, 월덕귀인 용어 풀이와 섞이지 않습니다.
    expect(
      find.descendant(of: explain, matching: find.byType(TermToken)),
      findsNothing,
    );
    await tester.tap(depthLinkTarget(of: explain));
    await tester.pumpAndSettle();
    final evidence = find.byKey(const Key(ScreenIds.evidenceSheet));
    expect(evidence, findsOneWidget);
    return tester.widget<EvidenceSheetBody>(
      find.descendant(of: evidence, matching: find.byType(EvidenceSheetBody)),
    );
  }

  testWidgets('daily-pair-virtue: 천덕일 알약 → 덕일 풀이 시트 → 그 덕 근거(잠김, 앞부분)', (
    tester,
  ) async {
    covers(
      const Covers(
        exits: ['today>explain-sheet', 'explain-sheet>evidence-sheet'],
        decisions: ['D124'],
      ),
    );
    final body = await openVirtueEvidence(
      tester,
      scenario: 'daily-pair-virtue',
      index: 0,
      label: _ko.todayDateVirtueCheondeok,
      body: '하늘의 덕이 들어오는 날이에요.',
    );
    expect(body.state, DepthLinkState.locked);
    expect(body.basisLead, isNotNull);
    // 두 덕 문장은 같은 슬롯이라 덕일 id로 누른 덕의 근거를 엽니다.
    expect(
      tester.widget<EvidenceSheet>(find.byType(EvidenceSheet)).slotId,
      'explain.day_virtue#cheondeok_day',
    );
    await _closeSheet(tester);
  });

  testWidgets('daily-pair-virtue-unlocked: 월덕일 풀이 시트의 근거는 열린 그 덕의 근거', (
    tester,
  ) async {
    covers(
      const Covers(
        exits: ['today>explain-sheet', 'explain-sheet>evidence-sheet'],
        decisions: ['D124'],
      ),
    );
    final body = await openVirtueEvidence(
      tester,
      scenario: 'daily-pair-virtue-unlocked',
      index: 1,
      label: _ko.todayDateVirtueWoldeok,
      body: '달의 덕이 들어오는 날이에요.',
    );
    expect(body.state, DepthLinkState.unlocked);
    expect(
      tester.widget<EvidenceSheet>(find.byType(EvidenceSheet)).slotId,
      'explain.day_virtue#woldeok_day',
    );
    final evidence = find.byKey(const Key(ScreenIds.evidenceSheet));
    expect(
      find.descendant(
        of: evidence,
        matching: find.textContaining('달의 덕이 드는 천간', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: evidence,
        matching: find.textContaining('하늘의 덕이 드는 천간', findRichText: true),
      ),
      findsNothing,
    );
    await _closeSheet(tester);
  });

  testWidgets('member: 공유 미리보기에서 비율을 고르고 공유하면 기기 공유 시트로 넘어갑니다', (tester) async {
    covers(
      const Covers(
        exits: ['today>share-preview', 'share-preview>system-share'],
        decisions: ['D47'],
      ),
    );
    final renderer = _FixedRenderer();
    final share = FakeShareSheet();
    await pumpApp(
      tester,
      scenario: 'member',
      overrides: [
        offscreenRendererProvider.overrideWithValue(renderer),
        shareSheetProvider.overrideWithValue(share),
      ],
    );
    await _settleToday(tester);

    await tester.tap(find.byType(ShareButton));
    await tester.pumpAndSettle();
    final sheet = find.byKey(const Key(ScreenIds.sharePreview));
    expect(sheet, findsOneWidget);

    await tester.tap(
      find.descendant(
        of: sheet,
        matching: find.text(_ko.sharePreviewRatioLabelSquare),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: sheet, matching: find.byType(PrimaryButton)),
    );
    await tester.pumpAndSettle();

    expect(renderer.calls, 1);
    expect(share.shared, hasLength(1));
    expect(share.shared.single.text, _ko.sharePreviewImageTagline);
    // 공유 뒤에도 시트는 그대로 열려 있습니다.
    expect(sheet, findsOneWidget);
  });

  testWidgets('풀이 시트: 사전을 받는 동안 skeleton, 실패하면 오류 화면, 다시 시도하면 이름', (
    tester,
  ) async {
    covers(
      const Covers(states: ['explain-sheet:loading', 'explain-sheet:error']),
    );
    // 오늘 화면은 사전이 있어야 열리므로, 풀이 시트만 따로 느리고 실패하는 사전을 받게 합니다.
    final firstAttempt = Completer<GlossaryNames>();
    var attempts = 0;
    final container = await pumpApp(
      tester,
      scenario: 'member',
      overrides: [
        depthSheetsProvider.overrideWithValue(
          DepthSheets(
            explainBody: (content, {head, diaryLinkTag}) => ProviderScope(
              overrides: [
                glossaryProvider.overrideWith((ref) {
                  if (++attempts == 1) return firstAttempt.future;
                  final termId = (content as ExplainTerm).termId;
                  final dot = termId.indexOf('.');
                  return GlossaryNames({
                    termId.substring(0, dot): {
                      termId.substring(dot + 1): '풀이 이름',
                    },
                  });
                }),
              ],
              child: ExplainSheet(content: content),
            ),
            evidenceBody: (_, _, _, _) => const SizedBox.shrink(),
            shareBody: SizedBox.shrink,
          ),
        ),
      ],
    );
    await _settleToday(tester);
    expect(container.read(glossaryProvider).hasValue, isTrue);

    await tester.tap(find.byType(TermToken).first);
    await tester.pump(const Duration(milliseconds: 400));
    final sheet = find.byKey(const Key(ScreenIds.explainSheet));
    expect(
      find.descendant(
        of: sheet,
        matching: find.byKey(const ValueKey('screen-state.loading')),
      ),
      findsOneWidget,
    );

    firstAttempt.completeError(const OfflineError());
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: sheet, matching: find.byType(ErrorState)),
      findsOneWidget,
    );

    await tester.tap(find.text(_ko.actionRetry));
    await tester.pumpAndSettle();
    expect(find.text('풀이 이름'), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);
  });

  testWidgets('member: 사주 기운 태그 → 사주 기운 시트(열린 동안 selected)', (tester) async {
    covers(const Covers(exits: ['today>tag-sheet'], decisions: ['D108']));
    await _openToday(tester);

    final featured = find.descendant(
      of: find.byKey(TodayScreen.featuredCardKey),
      matching: find.byType(HanjaTag),
    );
    await tester.ensureVisible(featured.first);
    await tester.pumpAndSettle();
    await tester.tap(featured.first);
    await tester.pumpAndSettle();

    final sheet = find.byKey(const Key(ScreenIds.tagSheet));
    expect(sheet, findsOneWidget);
    // 1순위: 머리 태그, 보조 문장과 오늘의 질문 줄(A113).
    expect(
      tester
          .widget<HanjaTag>(
            find.descendant(of: sheet, matching: find.byType(HanjaTag)),
          )
          .label,
      '합',
    );
    expect(
      tester
          .widget<TagSentenceList>(
            find.descendant(of: sheet, matching: find.byType(TagSentenceList)),
          )
          .items,
      hasLength(2),
    );
    // 연 태그는 시트가 열린 동안 open.ring(selected 테두리)을 그립니다(V129).
    bool open() {
      final surface = tester.widget<DecoratedBox>(
        find.descendant(
          of: featured.first,
          matching: find.byKey(HanjaTag.surfaceKey),
        ),
      );
      final border = (surface.decoration as BoxDecoration).border as Border?;
      return border?.top.color ==
          tester.element(featured.first).tokens.colors.actionPrimary;
    }

    expect(open(), isTrue);

    await tapSheetScrim(tester);
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(open(), isFalse);
  });

  testWidgets('D124 ②⑦ 오늘 태그 고신 孤, 과숙 寡, 원진 元: 대표 태그, 사주 기운 시트 뜻과 마무리', (
    tester,
  ) async {
    covers(const Covers(exits: ['today>tag-sheet'], decisions: ['D124']));
    final container = await _openToday(tester);
    // 오늘 응답을 새 태그가 대표 1순위인 응답으로 바꿉니다(fixture 대표 태그는 합, 비겁 몰림).
    final server = ScriptedDailyServer();
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, server);
    final featured = find.descendant(
      of: find.byKey(TodayScreen.featuredCardKey),
      matching: find.byType(HanjaTag),
    );
    for (final (key, glyph, label, meaningLead) in [
      ('gosin', '孤', '고신', '외로운 별을 뜻하는 신살'),
      ('gwasuk', '寡', '과숙', '홀로 지내는 별을 뜻하는 신살'),
      ('wonjin', '元', '원진', '띠끼리 서로 꺼리는 사이'),
    ]) {
      server.body['tags'] = {
        'featured': [
          {'key': key, 'polarity': 'bad'},
        ],
        'all': [key],
      };
      container.invalidate(dailyControllerProvider);
      await pumpUntil(
        tester,
        () =>
            featured.evaluate().length == 1 &&
            tester.widget<HanjaTag>(featured.first).glyph == glyph,
      );
      final tag = tester.widget<HanjaTag>(featured.first);
      expect(tag.label, label, reason: key);
      expect(tag.tone, HanjaTagTone.term, reason: key);
      await tester.ensureVisible(featured.first);
      await tester.pumpAndSettle();
      await tester.tap(featured.first);
      await tester.pumpAndSettle();
      final sheet = find.byKey(const Key(ScreenIds.tagSheet));
      expect(sheet, findsOneWidget, reason: key);
      final head = tester.widget<HanjaTag>(
        find.descendant(of: sheet, matching: find.byType(HanjaTag)),
      );
      expect((head.glyph, head.label), (glyph, label));
      // 뜻 줄은 사전(원고 `term.tag.<key>`)의 뜻이고, 흉 신살이라 바로 아래 마무리 한 줄(V120).
      final meaning = find.descendant(
        of: sheet,
        matching: find.byKey(const Key(SlotIds.tagSheetTagMeaning)),
      );
      expect(
        find.descendant(
          of: meaning,
          matching: find.textContaining(meaningLead, findRichText: true),
        ),
        findsOneWidget,
        reason: key,
      );
      final note = find.descendant(
        of: sheet,
        matching: find.byKey(WeighingNote.boxKey),
      );
      expect(
        find.descendant(of: note, matching: find.text(_ko.shinsalWeighingNote)),
        findsOneWidget,
        reason: key,
      );
      expect(
        tester.getRect(note).top - tester.getRect(meaning).bottom,
        moreOrLessEquals(WeighingNote.marginTop, epsilon: 0.01),
        reason: key,
      );
      // 1순위라 보조 문장과 오늘의 질문 줄이 있습니다(A113).
      expect(
        tester
            .widget<TagSentenceList>(
              find.descendant(
                of: sheet,
                matching: find.byType(TagSentenceList),
              ),
            )
            .items,
        hasLength(2),
        reason: key,
      );
      await tapSheetScrim(tester);
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
    }
  });

  testWidgets('member: 사주 기운 시트 근거 아이콘 → 그 태그를 머리로 한 근거 시트', (tester) async {
    covers(
      const Covers(exits: ['tag-sheet>evidence-sheet'], decisions: ['D108']),
    );
    await _openToday(tester);
    await _openFeaturedTag(tester, 0);

    final sheet = find.byKey(const Key(ScreenIds.tagSheet));
    // 흉 신살이 아닌 태그(fixture 1순위 합)에는 마무리 한 줄이 없습니다(V120).
    expect(
      find.descendant(of: sheet, matching: find.byKey(WeighingNote.boxKey)),
      findsNothing,
    );
    await tester.tap(depthLinkTarget(of: sheet));
    await tester.pumpAndSettle();

    final evidence = find.byKey(const Key(ScreenIds.evidenceSheet));
    expect(evidence, findsOneWidget);
    expect(
      find.descendant(
        of: find.descendant(
          of: evidence,
          matching: find.byKey(EvidenceSheetBody.targetTagsKey),
        ),
        matching: find.text('합'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: evidence,
        matching: find.text('이야기나 약속이 잘 맞아떨어지는 날이에요.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('member: 사주 기운 시트 일기 보기 → 그 태그의 tag-diary', (tester) async {
    covers(const Covers(exits: ['tag-sheet>tag-diary'], decisions: ['D108']));
    await _openToday(tester);
    await _openFeaturedTag(tester, 0);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key(ScreenIds.tagSheet)),
        matching: find.byKey(TagSentenceList.diaryLinkKey),
      ),
    );
    await pumpUntil(
      tester,
      () =>
          find.byKey(const ValueKey(ScreenIds.tagDiary)).evaluate().isNotEmpty,
    );
    expect(find.byKey(const Key(ScreenIds.tagSheet)), findsNothing);
    expect(find.byKey(const ValueKey(ScreenIds.tagDiary)), findsOneWidget);
  });

  testWidgets('member: 대표 태그 2순위의 사주 기운 시트는 빈 안내(empty)', (tester) async {
    covers(const Covers(states: ['tag-sheet:empty'], decisions: ['D108']));
    final container = await _openToday(tester);
    // 2순위 태그(역마)가 있는 날로 다시 받습니다.
    final server = ScriptedDailyServer();
    server.body['tags'] = {
      'featured': [
        {'key': 'cheoneul_gwiin', 'polarity': 'good'},
        {'key': 'yeokma', 'polarity': 'neutral'},
      ],
      'all': ['cheoneul_gwiin', 'yeokma', 'yongsin_day'],
    };
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, server);
    container.invalidate(dailyControllerProvider);
    final featured = find.descendant(
      of: find.byKey(TodayScreen.featuredCardKey),
      matching: find.byType(HanjaTag),
    );
    await pumpUntil(tester, () => featured.evaluate().length == 2);

    await _openFeaturedTag(tester, 1);
    final sheet = find.byKey(const Key(ScreenIds.tagSheet));
    expect(
      find.descendant(
        of: sheet,
        matching: find.text(_ko.tagSheetSentencesEmpty),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.byType(DepthLink)),
      findsNothing,
    );
  });

  testWidgets('member: 가이드 카드 → 오늘 새 일기 diary-edit', (tester) async {
    covers(const Covers(exits: ['today>diary-edit']));
    final container = await _openToday(tester);
    final action = find.bySemanticsIdentifier(SlotIds.todayGuideCta);
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(ScreenIds.diaryEdit)), findsOneWidget);
    expect(
      container.read(routerProvider).state.uri.toString(),
      '/diary-edit?date=2026-10-13',
    );
  });

  testWidgets('member: 오늘 일정 한 줄 → 오늘 day-sheet', (tester) async {
    covers(const Covers(exits: ['today>day-sheet']));
    await _openToday(tester);
    final summary = find.bySemanticsIdentifier(SlotIds.todayEventSummary);
    await pumpUntil(tester, () => summary.evaluate().isNotEmpty);
    await tester.ensureVisible(summary);
    await tester.pumpAndSettle();
    await tester.tap(summary);
    await settleWithIo(tester);

    final sheet = find.byKey(const Key(ScreenIds.daySheet));
    expect(sheet, findsOneWidget);
    // 오늘(2026-10-13) 시트입니다: 오늘 일정 세 개가 목록에 있습니다.
    final titles = [
      for (final row in tester.widgetList<EventRow>(
        find.descendant(of: sheet, matching: find.byType(EventRow)),
      ))
        row.title,
    ];
    expect(titles, ['엄마 생신', '팀 주간 회의', '요가 수업']);
  });

  testWidgets('diary-written: 오늘 쓴 일기 줄 → 그 일기의 diary-view', (tester) async {
    covers(const Covers(exits: ['today>diary-view']));
    final container = await _openToday(tester, scenario: 'diary-written');
    final row = find.byType(DiaryEntryLine);
    expect(row, findsOneWidget);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await settleWithIo(tester);
    expect(find.byKey(const ValueKey(ScreenIds.diaryView)), findsOneWidget);
    expect(
      container.read(routerProvider).state.uri.toString(),
      '/diary-view?id=7b1c2a54-3d0e-4f6a-9b21-5e8f40c1a005',
    );
  });

  testWidgets('loading: 화면을 연 채 날짜가 바뀌면 새 응답을 받는 동안 skeleton입니다', (
    tester,
  ) async {
    covers(const Covers(states: ['today:loading']));
    final container = await pumpApp(
      tester,
      scenario: 'member',
      overrides: [
        todayProvider.overrideWith((ref) => ref.watch(_testTodayProvider)),
      ],
    );
    await _settleToday(tester);
    final hold = _DailyHold();
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, hold);

    container
        .read(_testTodayProvider.notifier)
        .moveTo(CalendarDate(2026, 10, 14));
    await pumpUntil(tester, () => hold.requested, allowOngoing: true);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('screen-state.loading')), findsOneWidget);
    expect(_content, findsNothing);

    hold.hold.complete();
    await _settleToday(tester);
    expect(_content, findsOneWidget);
  });

  testWidgets('daily-error: 오류 화면과 다시 시도', (tester) async {
    covers(const Covers(states: ['today:error']));
    await _openToday(tester, scenario: 'daily-error');
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text(_ko.actionRetry), findsOneWidget);
    expect(_content, findsNothing);
  });

  testWidgets('offline: 받아 둔 오늘 풀이와 배너, 연결이 돌아와 다시 받으면 배너가 사라집니다', (
    tester,
  ) async {
    covers(const Covers(states: ['today:offline']));
    final container = await _openToday(tester);
    expect(find.text(_ko.noticeOffline), findsNothing);

    // 연결이 끊긴 채 다시 엽니다: 그날 캐시를 보이고 오프라인 배너를 띄웁니다.
    final network = _DailyNetwork();
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, network);
    container.invalidate(dailyControllerProvider);
    await pumpUntil(
      tester,
      () => container.read(dailyControllerProvider).value?.stale ?? false,
    );
    expect(_content, findsOneWidget);
    expect(find.text(_ko.noticeOffline), findsOneWidget);

    network.offline = false;
    unawaited(container.read(dailyControllerProvider.notifier).reload());
    await pumpUntil(
      tester,
      () => find.text(_ko.noticeOffline).evaluate().isEmpty,
    );
    expect(_content, findsOneWidget);
  });

  testWidgets('member-time-unknown: 시간 모름 배너', (tester) async {
    covers(const Covers(states: ['today:time-unknown']));
    await _openToday(tester, scenario: 'member-time-unknown');
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is NoticeBanner && w.variant == NoticeBannerVariant.timeUnknown,
      ),
      findsOneWidget,
    );
  });

  testWidgets('reward-unlock: 근거 시트 → 광고 제거권 안내, 광고 보고 열기 → 확인 → 다시 받아 열림', (
    tester,
  ) async {
    covers(
      const Covers(
        exits: ['evidence-sheet>system-rewarded-ad', 'evidence-sheet>ad-free'],
        states: ['evidence-sheet:loading', 'evidence-sheet:error'],
        decisions: ['D60'],
      ),
    );
    final container = await pumpApp(
      tester,
      scenario: 'reward-unlock',
      overrides: [
        rewardPollTimingProvider.overrideWithValue((
          interval: const Duration(milliseconds: 100),
          // 열림을 기대하므로 마감은 깁니다(마감이 응답보다 먼저 지나지 않게).
          timeout: const Duration(minutes: 10),
        )),
      ],
    );
    await _settleToday(tester);
    final refetch = _UnlockRefetch();
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, refetch);
    final sheet = find.byKey(const Key(ScreenIds.evidenceSheet));
    Finder inSheet(Finder matching) =>
        find.descendant(of: sheet, matching: matching);
    // 오늘 화면은 시트를 연 때의 응답을 근거 subject로 담습니다(A141).
    final unlock = evidenceUnlockControllerProvider(
      DailyEvidenceSubject(
        opened: container.read(dailyControllerProvider).value!.daily,
      ),
    );

    await tester.tap(
      depthLinkTarget(of: find.byKey(const Key(SlotIds.todayFortuneHead))),
    );
    await pumpUntil(
      tester,
      () => container.exists(unlock) && container.read(unlock).adReady,
    );
    expect(inSheet(find.byType(EvidenceLockPanel)), findsOneWidget);

    // 광고 제거권 안내: 시트 위에 ad-free가 열리고, 돌아오면 보던 근거 시트입니다.
    await tester.tap(
      inSheet(find.bySemanticsIdentifier(SlotIds.evidenceSheetLockPass)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(ScreenIds.adFree)), findsOneWidget);
    container.read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);

    // 광고를 끝까지 보면 확인 중 → 권한이 생기면 다시 받는 동안 skeleton입니다.
    refetch.armed = true;
    await tester.tap(inSheet(find.byKey(EvidenceLockPanel.ctaKey)));
    await pumpUntil(tester, () => refetch.requested, allowOngoing: true);
    expect(
      inSheet(find.byKey(EvidenceSheetBody.sectionSkeletonKey)),
      findsNWidgets(2),
    );

    // 다시 받기가 실패하면 오류 화면, 다시 시도하면 열립니다.
    refetch.release.complete();
    await pumpUntil(
      tester,
      () => inSheet(find.byType(ErrorState)).evaluate().isNotEmpty,
    );
    // 오늘 화면은 이전 값 그대로이고 오류 toast를 따로 띄우지 않습니다.
    expect(find.byType(ToastPill), findsNothing);
    await tester.tap(inSheet(find.text(_ko.actionRetry)));
    await pumpUntil(
      tester,
      () =>
          container.read(dailyControllerProvider).value?.daily.evidenceAccess ==
              EvidenceAccess.unlocked &&
          inSheet(find.byType(EvidenceLockPanel)).evaluate().isEmpty,
    );
    expect(inSheet(find.text(_ko.evidenceSheetTitle)), findsOneWidget);
    expect(inSheet(find.byType(ErrorState)), findsNothing);
  });
}
