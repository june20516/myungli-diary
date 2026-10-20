import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/model/daily.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
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
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/elements/lock_veil.dart';
import 'package:myungli_diary/features/depth/application/evidence_unlock_controller.dart';
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
  await pumpUntil(
    tester,
    () => find.byType(DayCharacter).evaluate().isNotEmpty,
  );
  final gate = _DailyGate();
  final interceptors = container.read(dioProvider).interceptors;
  interceptors.insert(interceptors.length - 1, gate);

  // 기본은 총운 끝의 근거 보기(날의 성격 이유 줄에도 같은 링크가 있습니다).
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

    testWidgets('권한이 있으면(unlocked) 본문 없는 구역은 제목도 그리지 않습니다(A22)', (
      tester,
    ) async {
      // 날의 성격 이유 슬롯에는 근거 문장이 없습니다.
      await _openSheet(
        tester,
        scenario: 'evidence-unlocked',
        link: find.byKey(DayCharacter.reasonKey),
      );

      expect(_inSheet(find.text(_ko.evidenceSheetTitle)), findsOneWidget);
      expect(_inSheet(find.byType(LockVeil)), findsNothing);
      expect(_inSheet(find.byType(EvidenceLockPanel)), findsNothing);
      expect(_inSheet(find.text(_ko.evidenceSheetSectionBasis)), findsNothing);
      expect(_inSheet(find.text(_ko.evidenceSheetSectionSource)), findsNothing);
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
  });
}
