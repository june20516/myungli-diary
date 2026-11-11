import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/gen/model/ad_free.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/insight.dart';
import 'package:myungli_diary/core/api/gen/model/me.dart';
import 'package:myungli_diary/core/api/gen/model/rendered_text.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/depth/evidence_lock_panel.dart';
import 'package:myungli_diary/design/components/depth/evidence_sheet_body.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/components/today/date_header.dart';
import 'package:myungli_diary/design/elements/lock_veil.dart';
import 'package:myungli_diary/design/interaction/unlock_glint.dart';
import 'package:myungli_diary/design/theme/myungli_tokens.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';
import 'package:myungli_diary/features/depth/application/evidence_unlock_controller.dart';
import 'package:myungli_diary/features/monetization/application/insight_providers.dart';
import 'package:myungli_diary/features/purchase/model/ad_free_date.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';

import '../../support/app_harness.dart';
import '../../support/daily_fixture.dart';
import '../../support/depth_link_finders.dart';
import '../../support/onboarding_steps.dart' show pumpUntil;
import '../../support/sheet_close.dart';

final _ko = AppLocalizationsKo();

final Finder _sheet = find.byKey(const Key(ScreenIds.evidenceSheet));

Finder _inSheet(Finder matching) =>
    find.descendant(of: _sheet, matching: matching);

final NotifierProvider<EvidenceUnlockController, EvidenceUnlockState>
_provider = evidenceUnlockControllerProvider(const DailyEvidenceSubject());

/// 열림을 기대하는 테스트의 확인 간격·시간: 간격은 짧고 마감은 깁니다(마감이 가짜 시계로
/// 흐르는데 대역 서버 응답은 실제 I/O라, 마감이 짧으면 응답보다 먼저 지납니다).
const ({Duration interval, Duration timeout}) _fastTiming = (
  interval: Duration(milliseconds: 100),
  timeout: Duration(minutes: 10),
);

/// 마감을 실제로 기다리는 테스트(시간 초과 toast)의 확인 간격·시간.
const ({Duration interval, Duration timeout}) _expiringTiming = (
  interval: Duration(milliseconds: 100),
  timeout: Duration(seconds: 1),
);

/// 시간 초과가 오지 않을 만큼 깁니다(확인 중 상태를 보는 테스트).
const ({Duration interval, Duration timeout}) _slowTiming = (
  interval: Duration(seconds: 2),
  timeout: Duration(minutes: 10),
);

/// `/v1/daily/` 요청을 [armed] 뒤부터 [hold]가 끝날 때까지 붙잡거나, [fail]이면 503으로 끊습니다.
final class _DailyGate extends Interceptor {
  bool armed = false;
  bool fail = false;
  bool requested = false;
  final hold = Completer<void>();

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
    if (fail) {
      fail = false;
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
    await hold.future;
    handler.next(options);
  }
}

/// 오늘 응답을 [daily]로 고정하는 대역.
final class _StubDaily extends DailyController {
  new(this.daily);

  final Daily daily;

  @override
  Future<DailyView> build() async => DailyView(
    date: CalendarDate(2026, 10, 13),
    daily: daily,
    stale: false,
    cacheKey: null,
  );
}

/// 처음에는 [daily]이고 [nextDay]로 자정 뒤 새 날 응답으로 바뀌는 대역.
final class _MidnightDaily extends DailyController {
  new(this.daily);

  final Daily daily;

  @override
  Future<DailyView> build() async => DailyView(
    date: CalendarDate(2026, 10, 13),
    daily: daily,
    stale: false,
    cacheKey: null,
  );

  /// 자정이 지나 새 날 응답 [next]를 받은 것처럼 바꿉니다. 화면 날짜는 시계를 움직이지 않는
  /// 대역이라 그대로 두고 응답만 바꿉니다(열람 상태가 잠긴 응답).
  void nextDay(Daily next) => state = AsyncData(
    DailyView(
      date: CalendarDate(2026, 10, 13),
      daily: next,
      stale: false,
      cacheKey: null,
    ),
  );
}

/// member 오늘 응답의 열람 상태를 [access]로 두고 총운 첫 문장에 [evidence]를 담습니다.
Daily _dailyWithEvidence(
  EvidenceAccess access,
  List<Map<String, Object>> evidence,
) {
  final json = memberDailyJson();
  final fortune = Map<String, dynamic>.of(
    json['fortune'] as Map<String, dynamic>,
  );
  fortune['head'] = {
    ...fortune['head'] as Map<String, dynamic>,
    'evidence': evidence,
  };
  return Daily.fromJson({
    ...json,
    'evidenceAccess': access.value,
    'fortune': fortune,
  });
}

Map<String, Object> _sentence(String text) => {
  'segments': [
    {'text': text},
  ],
};

/// 근거 셋: 첫째는 판정 근거와 원전, 둘째는 문장 없음(원고가 없어 server가 생략), 셋째는 판정 근거만.
final List<Map<String, Object>> _threeEvidence = [
  {
    'ruleId': 'fortune/day_kind',
    'sourceRef': 'gungtong-bogam/five_elements#balance_principle',
    'basis': _sentence('첫째 근거'),
    'source': _sentence('첫째 원전'),
  },
  {'ruleId': 'tags/select', 'sourceRef': 'gungtong-bogam/five_elements#color'},
  {
    'ruleId': 'yongsin/eokbu',
    'sourceRef': 'gungtong-bogam/five_elements#balance_principle',
    'basis': _sentence('셋째 근거'),
  },
];

/// member 오늘 응답의 [slot] 문장(`head` 또는 `tag`)에 잠긴 근거 앞부분 [previews]를 담습니다.
Daily _dailyWithPreview(
  List<Map<String, Object>> previews, {
  String slot = 'head',
}) {
  final json = memberDailyJson();
  final fortune = Map<String, dynamic>.of(
    json['fortune'] as Map<String, dynamic>,
  );
  fortune[slot] = {
    ...fortune[slot] as Map<String, dynamic>,
    'evidencePreview': previews,
  };
  return Daily.fromJson({...json, 'fortune': fortune});
}

/// [finder] 안 `lock.veil` 또렷한 층의 첫 조각 글자.
String _clearHead(WidgetTester tester, Finder finder) {
  final text = tester.widget<Text>(
    find.descendant(of: finder, matching: find.byKey(LockVeil.clearKey)),
  );
  return ((text.textSpan! as TextSpan).children!.first as TextSpan).text!;
}

List<String> _plain(List<RenderedText> texts) => [
  for (final text in texts) text.segments.map((s) => s.text).join(),
];

/// [scenario]로 오늘 화면을 띄우고 근거 보기로 근거 시트를 엽니다. 광고를 미리 불러 둘 때까지 기다립니다.
///
/// [link]는 누를 근거 보기가 든 위젯(기본은 총운 첫 문장)이고, [daily]를 주면 오늘 응답을 그 값으로 고정합니다.
Future<(ProviderContainer, _DailyGate)> _openSheet(
  WidgetTester tester, {
  String scenario = 'member',
  ({Duration interval, Duration timeout}) timing = _fastTiming,
  Finder? link,
  Daily? daily,
}) async {
  final container = await pumpApp(
    tester,
    scenario: scenario,
    overrides: [
      rewardPollTimingProvider.overrideWithValue(timing),
      if (daily != null)
        dailyControllerProvider.overrideWith(() => _StubDaily(daily)),
    ],
  );
  await pumpUntil(tester, () => find.byType(DateHeader).evaluate().isNotEmpty);
  final gate = _DailyGate();
  final interceptors = container.read(dioProvider).interceptors;
  interceptors.insert(interceptors.length - 1, gate);

  // 기본은 총운 헤드라인 끝의 근거 보기입니다.
  await tester.tap(
    depthLinkTarget(
      of: link ?? find.byKey(const Key(SlotIds.todayFortuneHead)),
    ),
  );
  await pumpUntil(tester, () {
    if (_sheet.evaluate().isEmpty || !container.exists(_provider)) {
      return false;
    }
    final state = container.read(_provider);
    return state.adReady || state.link != DepthLinkState.locked;
  });
  return (container, gate);
}

Future<void> _tapCta(WidgetTester tester) async {
  await tester.tap(_inSheet(find.byKey(EvidenceLockPanel.ctaKey)));
  await tester.pump();
}

void main() {
  setUpAll(ensureTimeZonesInitialized);

  group('EvidenceSheet', () {
    testWidgets('잠김: 제목, 두 구역의 lock.veil과 아래 잠금 안내', (tester) async {
      final handle = tester.ensureSemantics();
      await _openSheet(tester);

      expect(_inSheet(find.text(_ko.evidenceSheetTitle)), findsOneWidget);
      expect(_inSheet(find.byType(LockVeil)), findsNWidgets(2));
      expect(_inSheet(find.byType(EvidenceLockPanel)), findsOneWidget);
      final body = tester.widget<EvidenceSheetBody>(
        _inSheet(find.byType(EvidenceSheetBody)),
      );
      expect(body.state, DepthLinkState.locked);
      expect(body.pillars, isNull, reason: '원국표는 계획 6');
      expect(body.showPersonal, isFalse);
      final cta = tester.widget<PrimaryButton>(
        _inSheet(find.byKey(EvidenceLockPanel.ctaKey)),
      );
      expect(cta.onPressed, isNotNull);
      expect(find.bySemanticsLabel(_ko.evidenceSheetTitle), findsWidgets);
      handle.dispose();
    });

    testWidgets('lockedNoAd: 광고가 없다는 안내와 꺼진 버튼', (tester) async {
      await _openSheet(tester, scenario: 'reward-unavailable');

      expect(
        _inSheet(
          find.bySemanticsIdentifier(SlotIds.evidenceSheetLockUnavailable),
        ),
        findsOneWidget,
      );
      final cta = tester.widget<PrimaryButton>(
        _inSheet(find.byKey(EvidenceLockPanel.ctaKey)),
      );
      expect(cta.onPressed, isNull);
    });

    testWidgets('확인 중: 버튼은 점 숨쉬기와 "확인 중"이고 다시 누를 수 없습니다', (tester) async {
      final handle = tester.ensureSemantics();
      final (container, _) = await _openSheet(
        tester,
        scenario: 'reward-timeout',
        timing: _slowTiming,
      );

      await _tapCta(tester);
      await pumpUntil(
        tester,
        () => container.read(_provider).link == DepthLinkState.unlocking,
        allowOngoing: true,
      );
      expect(_inSheet(find.byKey(PrimaryButton.dotsKey)), findsOneWidget);
      expect(
        _inSheet(find.bySemanticsIdentifier(SlotIds.evidenceSheetA11yChecking)),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(_ko.evidenceSheetA11yChecking),
        findsOneWidget,
      );
      handle.dispose();

      // 시트를 닫으면 묻기를 멈추고, 닫힌 화면에 toast가 뜨지 않습니다(Review Focus 5).
      await tapSheetScrim(tester);
      await pumpUntil(tester, () => _sheet.evaluate().isEmpty);
      await tester.pump(const Duration(minutes: 11));
      expect(find.byType(ToastPill), findsNothing);
      expect(container.exists(_provider), isFalse);
    });

    testWidgets('시간 초과면 toast와 다시 잠김', (tester) async {
      final (container, _) = await _openSheet(
        tester,
        scenario: 'reward-timeout',
        timing: _expiringTiming,
      );

      await _tapCta(tester);
      await pumpUntil(
        tester,
        () => find.byType(ToastPill).evaluate().isNotEmpty,
        allowOngoing: true,
      );
      expect(find.text(_ko.evidenceSheetUnlockFailed), findsOneWidget);
      expect(container.read(_provider).link, DepthLinkState.locked);
      expect(_inSheet(find.byKey(PrimaryButton.dotsKey)), findsNothing);
      // toast가 사라지는 시간을 흘려 보냅니다.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('흐름이 다시 build되어도(invalidate) 시간 초과 toast를 받습니다', (
      tester,
    ) async {
      final (container, _) = await _openSheet(
        tester,
        scenario: 'reward-timeout',
        timing: _expiringTiming,
      );
      container.invalidate(_provider);
      await pumpUntil(tester, () => container.read(_provider).adReady);

      await _tapCta(tester);
      await pumpUntil(
        tester,
        () => find.byType(ToastPill).evaluate().isNotEmpty,
        allowOngoing: true,
      );
      expect(find.text(_ko.evidenceSheetUnlockFailed), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('표시 실패면 오류 toast', (tester) async {
      final (container, _) = await _openSheet(
        tester,
        scenario: 'reward-failed',
      );

      await _tapCta(tester);
      await pumpUntil(
        tester,
        () => find.byType(ToastPill).evaluate().isNotEmpty,
        allowOngoing: true,
      );
      expect(find.text(_ko.errorUnexpected), findsOneWidget);
      expect(container.read(_provider).link, DepthLinkState.locked);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('광고 제거권 링크는 시트 위에 ad-free를 열고, 돌아오면 보던 근거 시트', (tester) async {
      final (container, _) = await _openSheet(tester);

      await tester.tap(
        _inSheet(find.bySemanticsIdentifier(SlotIds.evidenceSheetLockPass)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey(ScreenIds.adFree)), findsOneWidget);

      container.read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey(ScreenIds.adFree)), findsNothing);
      expect(_sheet, findsOneWidget);
    });

    testWidgets('unlocked면 evidence의 basis·source를 순서대로 문단으로 그립니다', (
      tester,
    ) async {
      await _openSheet(
        tester,
        daily: _dailyWithEvidence(EvidenceAccess.unlocked, _threeEvidence),
      );

      final body = tester.widget<EvidenceSheetBody>(
        _inSheet(find.byType(EvidenceSheetBody)),
      );
      expect(body.state, DepthLinkState.unlocked);
      expect(_plain(body.basis), ['첫째 근거', '셋째 근거']);
      expect(_plain(body.source), ['첫째 원전']);
      expect(
        _inSheet(find.byKey(const ValueKey(SlotIds.evidenceSheetBasisBody))),
        findsNWidgets(2),
      );
      expect(_inSheet(find.text('셋째 근거', findRichText: true)), findsOneWidget);
      expect(_inSheet(find.text('첫째 원전', findRichText: true)), findsOneWidget);
    });

    testWidgets('문장이 없는 항목은 건너뛰고 모두 없으면 구역이 없습니다', (tester) async {
      await _openSheet(
        tester,
        daily: _dailyWithEvidence(EvidenceAccess.unlocked, [
          {
            'ruleId': 'tags/select',
            'sourceRef': 'gungtong-bogam/five_elements#color',
          },
        ]),
      );

      final body = tester.widget<EvidenceSheetBody>(
        _inSheet(find.byType(EvidenceSheetBody)),
      );
      expect(body.basis, isEmpty);
      expect(body.source, isEmpty);
      expect(_inSheet(find.text(_ko.evidenceSheetSectionBasis)), findsNothing);
      expect(_inSheet(find.text(_ko.evidenceSheetSectionSource)), findsNothing);
    });

    testWidgets('locked면 본문을 받지 않습니다(D60)', (tester) async {
      // 잠긴 응답에 문장이 잘못 실려 와도 시트는 받지도 그리지도 않습니다.
      await _openSheet(
        tester,
        daily: _dailyWithEvidence(EvidenceAccess.locked, _threeEvidence),
      );

      final body = tester.widget<EvidenceSheetBody>(
        _inSheet(find.byType(EvidenceSheetBody)),
      );
      expect(body.state, DepthLinkState.locked);
      expect(body.basis, isEmpty);
      expect(body.source, isEmpty);
      expect(_inSheet(find.byType(LockVeil)), findsNWidgets(2));
      expect(find.text('첫째 근거', findRichText: true), findsNothing);
      expect(find.text('첫째 원전', findRichText: true), findsNothing);
    });

    testWidgets('loading: 권한이 생겨 다시 받는 동안 구역 skeleton, 받으면 열림', (tester) async {
      final handle = tester.ensureSemantics();
      final (container, gate) = await _openSheet(
        tester,
        scenario: 'reward-unlock',
      );
      gate.armed = true;

      await _tapCta(tester);
      await pumpUntil(tester, () => gate.requested, allowOngoing: true);
      expect(
        _inSheet(find.byKey(EvidenceSheetBody.sectionSkeletonKey)),
        findsNWidgets(2),
      );
      expect(_inSheet(find.byType(LockVeil)), findsNothing);
      expect(_inSheet(find.byKey(PrimaryButton.dotsKey)), findsOneWidget);

      gate.hold.complete();
      await pumpUntil(
        tester,
        () => container.read(_provider).link == DepthLinkState.unlocked,
      );
      expect(
        _inSheet(find.byKey(EvidenceSheetBody.sectionSkeletonKey)),
        findsNothing,
      );
      expect(_inSheet(find.byType(EvidenceLockPanel)), findsNothing);
      expect(
        find.bySemanticsLabel(_ko.evidenceSheetA11yUnlocked),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('error: 다시 받기에 실패하면 error-state, 다시 시도하면 열림', (tester) async {
      final (container, gate) = await _openSheet(
        tester,
        scenario: 'reward-unlock',
      );
      gate
        ..armed = true
        ..fail = true;
      gate.hold.complete();

      await _tapCta(tester);
      await pumpUntil(
        tester,
        () => _inSheet(find.byType(ErrorState)).evaluate().isNotEmpty,
      );
      expect(_inSheet(find.byType(EvidenceLockPanel)), findsNothing);
      expect(find.byType(ToastPill), findsNothing, reason: '오류는 시트만 알림');

      await tester.tap(_inSheet(find.text(_ko.actionRetry)));
      await pumpUntil(
        tester,
        () => container.read(_provider).link == DepthLinkState.unlocked,
      );
      expect(_inSheet(find.byType(ErrorState)), findsNothing);
      expect(_inSheet(find.text(_ko.evidenceSheetTitle)), findsOneWidget);
    });

    testWidgets('잠김 G1: 앞부분이 또렷하고 판정 근거 3줄, 원전은 앞부분이 없어 자리값만 2줄', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _openSheet(
        tester,
        daily: _dailyWithPreview([
          // 첫 근거는 앞부분이 없고, 둘째 근거의 판정 근거 앞부분을 씁니다(근거 순서).
          {},
          {'basis': _sentence('오늘은 용신의')},
          {'basis': _sentence('셋째 앞부분')},
        ]),
      );

      final basis = _inSheet(
        find.byKey(const ValueKey(SlotIds.evidenceSheetBasisBody)),
      );
      final source = _inSheet(
        find.byKey(const ValueKey(SlotIds.evidenceSheetSourceQuote)),
      );
      final veils = tester
          .widgetList<LockVeil>(_inSheet(find.byType(LockVeil)))
          .toList();
      expect(
        [for (final veil in veils) veil.lines],
        [LockVeilLines.basis, LockVeilLines.source],
      );
      expect(_clearHead(tester, basis), startsWith('오늘은 용신의'));
      expect(
        _clearHead(tester, source),
        startsWith(LockVeil.placeholderFor(const Locale('ko'))),
      );
      expect(
        find.bySemanticsLabel(
          '${_ko.evidenceSheetSectionBasis}, 오늘은 용신의, '
          '${_ko.evidenceSheetA11yLocked}',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          '${_ko.evidenceSheetSectionSource}, ${_ko.evidenceSheetA11yLocked}',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('잠긴 원전 앞부분은 첫 원전 뜻 줄이고 원전 대체 글꼴을 쓰며 판정 근거는 대체하지 않습니다', (
      tester,
    ) async {
      // 미리보기는 새 순서(뜻, 원문)의 앞 두 줄입니다. 원문 줄의 한자 글꼴은 열린 시트의
      // 원문 줄이 확인합니다(sentence_test 원전 세 줄).
      await _openSheet(
        tester,
        daily: _dailyWithPreview([
          {
            'basis': _sentence('오늘은 용신의'),
            'source': _sentence('넘치는 것은 덜고\n以義推之'),
          },
        ]),
      );
      final hanja = tester
          .element(_inSheet(find.byType(EvidenceSheetBody)))
          .tokens
          .typography
          .hanjaPillar
          .fontFamily;
      final veils = tester
          .widgetList<LockVeil>(_inSheet(find.byType(LockVeil)))
          .toList();
      expect(
        [for (final veil in veils) veil.fontFallback],
        [
          const <String>[],
          [hanja],
        ],
      );
      expect(
        veils.last.lead?.segments.map((segment) => segment.text).join(),
        '넘치는 것은 덜고',
        reason: '원문 줄은 그리지 않음',
      );
      expect(_inSheet(find.textContaining('以義推之')), findsNothing);
    });

    testWidgets('evidencePreview가 없으면 두 구역 모두 자리값만입니다', (tester) async {
      // member fixture의 총운 헤드라인에는 앞부분이 있어, 필드를 뺀 응답으로 엽니다.
      final json = memberDailyJson();
      final fortune = Map<String, dynamic>.of(
        json['fortune'] as Map<String, dynamic>,
      );
      fortune['head'] = Map<String, dynamic>.of(
        fortune['head'] as Map<String, dynamic>,
      )..remove('evidencePreview');
      await _openSheet(
        tester,
        daily: Daily.fromJson({...json, 'fortune': fortune}),
      );

      final body = tester.widget<EvidenceSheetBody>(
        _inSheet(find.byType(EvidenceSheetBody)),
      );
      expect(body.basisLead, isNull);
      expect(body.sourceLead, isNull);
      for (final veil in tester.widgetList<LockVeil>(
        _inSheet(find.byType(LockVeil)),
      )) {
        expect(veil.lead, isNull);
      }
    });

    testWidgets('구역 제목 위는 space.24입니다', (tester) async {
      await _openSheet(tester);

      final basisTitle = tester.getRect(
        _inSheet(find.byKey(const ValueKey(SlotIds.evidenceSheetSectionBasis))),
      );
      final sourceTitle = tester.getRect(
        _inSheet(
          find.byKey(const ValueKey(SlotIds.evidenceSheetSectionSource)),
        ),
      );
      final basisBody = tester.getRect(
        _inSheet(find.byKey(const ValueKey(SlotIds.evidenceSheetBasisBody))),
      );
      final target = tester.getRect(
        _inSheet(find.byKey(const ValueKey(SlotIds.evidenceSheetTargetBody))),
      );
      expect(basisTitle.top - target.bottom, Space.s24);
      expect(sourceTitle.top - basisBody.bottom, Space.s24);
    });

    testWidgets('헤드라인에서 열면 시트 위에 날의 성격 태그와 헤드라인 문장(잠겨도 보임)', (tester) async {
      await _openSheet(tester);

      final body = tester.widget<EvidenceSheetBody>(
        _inSheet(find.byType(EvidenceSheetBody)),
      );
      expect(body.state, DepthLinkState.locked);
      final tags = [for (final tag in body.targetTags) tag as HanjaTag];
      // member는 날의 성격과 십성 묶음(비겁) 둘입니다.
      expect(tags, hasLength(2));
      for (final tag in tags) {
        expect(tag.onTap, isNull);
        expect(tag.variant, HanjaTagVariant.normal);
      }
      final headText = Daily.fromJson(memberDailyJson())
          .fortune
          .head
          .text
          .segments
          .map((segment) => segment.text)
          .join();
      expect(
        _inSheet(find.text(headText)),
        findsOneWidget,
        reason: '대상 문장은 caption.lg 일반 글자 한 덩어리',
      );
      final title = tester.getRect(
        _inSheet(find.byKey(const ValueKey(SlotIds.evidenceSheetSheetTitle))),
      );
      final tagRow = tester.getRect(
        _inSheet(find.byKey(EvidenceSheetBody.targetTagsKey)),
      );
      final sentence = tester.getRect(
        _inSheet(find.byKey(const ValueKey(SlotIds.evidenceSheetTargetBody))),
      );
      expect(tagRow.top - title.bottom, Space.s12);
      expect(sentence.top - tagRow.bottom, Space.s8);
      final text = tester.widget<Text>(
        find.descendant(
          of: _inSheet(
            find.byKey(const ValueKey(SlotIds.evidenceSheetTargetBody)),
          ),
          matching: find.byType(Text),
        ),
      );
      expect(text.maxLines, 3);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('보조 문장에서 열면 시트 위에 대표 태그 1순위와 보조 문장', (tester) async {
      await _openSheet(
        tester,
        link: find.byKey(const Key(SlotIds.todayFortuneBody)),
      );

      final body = tester.widget<EvidenceSheetBody>(
        _inSheet(find.byType(EvidenceSheetBody)),
      );
      expect(
        [for (final tag in body.targetTags) (tag as HanjaTag).label],
        ['합'],
      );
      expect(
        body.target?.segments.map((s) => s.text).join(),
        '이야기나 약속이 잘 맞아떨어지는 날이에요.',
      );
    });

    testWidgets(
      'evidence-unlocked: 광고 한 편으로 열린 날은 근거 아이콘이 그라데이션이고 시트 제목 옆 "자정까지 열림"',
      (tester) async {
        await pumpApp(tester, scenario: 'evidence-unlocked');
        await pumpUntil(
          tester,
          () => find.byType(DateHeader).evaluate().isNotEmpty,
        );
        expect(
          find.descendant(
            of: find.byType(DepthLink),
            matching: find.byType(ShaderMask),
          ),
          findsWidgets,
          reason: '시트 밖에서도 열린 것이 보임(icon.unlocked)',
        );

        await tester.tap(
          depthLinkTarget(of: find.byKey(const Key(SlotIds.todayFortuneHead))),
        );
        await pumpUntil(
          tester,
          () =>
              _inSheet(find.text(_ko.evidenceSheetUnlockUntilMidnight))
                  .evaluate()
                  .isNotEmpty,
        );
        expect(_inSheet(find.byType(UnlockGlintScope)), findsOneWidget);
      },
    );

    testWidgets('reward-unlock: 광고로 열리면 받은 권한으로 "자정까지 열림"이고 시트 밖 아이콘도 바뀝니다', (
      tester,
    ) async {
      final (container, _) = await _openSheet(
        tester,
        scenario: 'reward-unlock',
      );
      expect(
        find.descendant(
          of: find.byType(DepthLink),
          matching: find.byType(ShaderMask),
        ),
        findsNothing,
      );
      await _tapCta(tester);
      await pumpUntil(
        tester,
        () => container.read(_provider).link == DepthLinkState.unlocked,
      );
      await pumpUntil(
        tester,
        () =>
            _inSheet(find.text(_ko.evidenceSheetUnlockUntilMidnight))
                .evaluate()
                .isNotEmpty,
      );
      await closeSheet(tester, _sheet);
      expect(
        find.descendant(
          of: find.byType(DepthLink),
          matching: find.byType(ShaderMask),
        ),
        findsWidgets,
      );
    });

    testWidgets('광고 제거권으로 열렸으면 꼬리표는 기간 끝 날짜입니다', (tester) async {
      final end = DateTime.utc(2026, 11, 12, 3);
      await pumpApp(
        tester,
        scenario: 'member',
        overrides: [
          dailyControllerProvider.overrideWith(
            () => _StubDaily(
              _dailyWithEvidence(EvidenceAccess.unlocked, _threeEvidence),
            ),
          ),
          unlockTagInsightProvider.overrideWith(
            (ref) async => Insight(
              active: true,
              expiresAt: end,
              source_: InsightSource_Enum.adFreePass,
            ),
          ),
        ],
      );
      await pumpUntil(
        tester,
        () => find.byType(DateHeader).evaluate().isNotEmpty,
      );
      await tester.tap(
        depthLinkTarget(of: find.byKey(const Key(SlotIds.todayFortuneHead))),
      );
      final expected = _ko.evidenceSheetUnlockUntilDate(
        expiryDate('ko', end, 'Asia/Seoul'),
      );
      await pumpUntil(
        tester,
        () => _inSheet(find.text(expected)).evaluate().isNotEmpty,
      );
      expect(expected, contains('12'));
    });

    testWidgets(
      '열어 둔 채 자정이 지나 새 날 응답이 잠겨도 닫을 때까지 근거, 꼬리표, 반짝임이 그대로이고 다시 열면 잠깁니다',
      (tester) async {
        final container = await pumpApp(
          tester,
          scenario: 'member',
          overrides: [
            dailyControllerProvider.overrideWith(
              () => _MidnightDaily(
                _dailyWithEvidence(EvidenceAccess.unlocked, _threeEvidence),
              ),
            ),
            unlockTagInsightProvider.overrideWith(
              (ref) async => Insight(
                active: true,
                expiresAt: DateTime.utc(2026, 10, 13, 15),
                source_: InsightSource_Enum.rewardedAd,
              ),
            ),
          ],
        );
        await pumpUntil(
          tester,
          () => find.byType(DateHeader).evaluate().isNotEmpty,
        );
        final link = depthLinkTarget(
          of: find.byKey(const Key(SlotIds.todayFortuneHead)),
        );
        await tester.tap(link);
        await pumpUntil(
          tester,
          () =>
              _inSheet(find.text(_ko.evidenceSheetUnlockUntilMidnight))
                  .evaluate()
                  .isNotEmpty,
        );
        expect(
          _inSheet(find.text('첫째 근거', findRichText: true)),
          findsOneWidget,
        );

        (container.read(dailyControllerProvider.notifier) as _MidnightDaily)
            .nextDay(
              _dailyWithEvidence(EvidenceAccess.locked, [
                {
                  'ruleId': 'fortune/day_kind',
                  'sourceRef': 'gungtong-bogam/five_elements#balance_principle',
                  'basis': _sentence('새 날 근거'),
                },
              ]),
            );
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(container.read(_provider).link, DepthLinkState.unlocked);
        expect(
          _inSheet(find.text('첫째 근거', findRichText: true)),
          findsOneWidget,
        );
        expect(
          _inSheet(find.text('첫째 원전', findRichText: true)),
          findsOneWidget,
        );
        expect(
          _inSheet(find.text(_ko.evidenceSheetUnlockUntilMidnight)),
          findsOneWidget,
        );
        expect(_inSheet(find.text('새 날 근거', findRichText: true)), findsNothing);
        expect(_inSheet(find.byType(UnlockGlint)), findsWidgets);
        expect(_inSheet(find.byType(EvidenceLockPanel)), findsNothing);
        expect(_inSheet(find.byType(LockVeil)), findsNothing);

        // 뒤 오늘 화면은 새 날 응답이라 움직임이 남을 수 있어 settle 대신 몇 프레임만 넘깁니다.
        await closeSheet(
          tester,
          _sheet,
          settle: (t) async {
            for (var i = 0; i < 10; i++) {
              await t.pump(const Duration(milliseconds: 100));
            }
          },
        );
        await tester.tap(link);
        await pumpUntil(
          tester,
          () => _inSheet(find.byType(LockVeil)).evaluate().isNotEmpty,
        );
        expect(container.read(_provider).link, isNot(DepthLinkState.unlocked));
        expect(
          _inSheet(find.text(_ko.evidenceSheetUnlockUntilMidnight)),
          findsNothing,
        );
      },
    );

    testWidgets('꼬리표 권한이 이미 받아져 있어 동기로 오면 구독을 바로 닫고 이용권을 다시 묻지 않습니다', (
      tester,
    ) async {
      // 진입 때 내 정보에는 권한이 없어(광고를 본 뒤 열린 날) 꼬리표 권한은 이용권으로 압니다.
      final container = await pumpApp(
        tester,
        scenario: 'evidence-unlocked',
        overrides: [
          meProvider.overrideWithValue(
            Me(
              accountId: '0b3f6a9e-6c1d-4f43-9a52-3c1e7d2b8a10',
              consentRequired: false,
              requiredConsents: const [],
              hasProfile: true,
              adFree: AdFree(active: false),
              insight: Insight(active: false),
            ),
          ),
        ],
      );
      await pumpUntil(
        tester,
        () => find.byType(DateHeader).evaluate().isNotEmpty,
      );
      final fake =
          container.read(fakeServerInterceptorProvider)!
              as FakeServerInterceptor;
      // 다른 곳이 먼저 받아 둔 상태를 만듭니다(시트가 구독할 때 값이 동기로 옴).
      final early = container.listen(unlockTagInsightProvider, (_, _) {});
      await pumpUntil(
        tester,
        () => container.read(unlockTagInsightProvider).value != null,
      );
      final asked = fake.callCountOf('getEntitlements');
      expect(asked, 1);

      await tester.tap(
        depthLinkTarget(of: find.byKey(const Key(SlotIds.todayFortuneHead))),
      );
      await pumpUntil(
        tester,
        () =>
            _inSheet(find.text(_ko.evidenceSheetUnlockUntilMidnight))
                .evaluate()
                .isNotEmpty,
      );
      early.close();
      await tester.pump();
      expect(
        container.exists(unlockTagInsightProvider),
        isFalse,
        reason: '시트가 구독을 닫아 provider가 버려짐',
      );

      // 알던 권한을 잊어도(보는 중 권한이 끝난 것과 같음) 열린 시트의 꼬리표는 그대로입니다.
      container.invalidate(latestInsightGrantProvider);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        _inSheet(find.text(_ko.evidenceSheetUnlockUntilMidnight)),
        findsOneWidget,
      );
    });
  });
}
