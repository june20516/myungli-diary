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
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/share_button.dart';
import 'package:myungli_diary/design/components/depth/evidence_lock_panel.dart';
import 'package:myungli_diary/design/components/depth/evidence_sheet_body.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/guide_question_card.dart';
import 'package:myungli_diary/features/depth/application/evidence_unlock_controller.dart';
import 'package:myungli_diary/features/depth/presentation/depth_sheets.dart';
import 'package:myungli_diary/features/depth/presentation/explain_sheet.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/features/glossary/data/glossary_repository.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';
import 'package:myungli_diary/features/today/application/share_renderer.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_harness.dart';
import '../support/depth_link_finders.dart';
import '../support/onboarding_steps.dart' show pumpUntil;

final _ko = AppLocalizationsKo();

final Finder _content = find.byType(DayCharacter);

Future<void> _settleToday(WidgetTester tester) => pumpUntil(
  tester,
  () =>
      _content.evaluate().isNotEmpty ||
      find.byType(ErrorState).evaluate().isNotEmpty,
);

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
final class _FixedRenderer implements ShareRenderer {
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

/// `/v1/diaries/`에 쓴 일기(200)로 답하고 호출 수를 셉니다.
final class _DiaryWritten extends Interceptor {
  int calls = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!options.path.startsWith('/v1/diaries/')) {
      handler.next(options);
      return;
    }
    calls++;
    handler.resolve(
      Response<Object?>(
        requestOptions: options,
        statusCode: 200,
        headers: Headers.fromMap({
          Headers.contentTypeHeader: ['application/json'],
        }),
        data: {
          'date': '2026-10-13',
          'body': '일기',
          'tags': {'featured': <Object>[], 'all': <Object>[]},
          'rulesetVersion': 'r1',
          'createdAt': '2026-10-13T12:00:00Z',
          'updatedAt': '2026-10-13T12:00:00Z',
        },
      ),
      true,
    );
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

/// 손으로 바꾸는 "오늘"(자정 넘김 흉내).
final class _TestToday extends Notifier<CalendarDate> {
  @override
  CalendarDate build() => CalendarDate(2026, 10, 13);

  CalendarDate get date => state;

  set date(CalendarDate value) => state = value;
}

final _testTodayProvider = NotifierProvider<_TestToday, CalendarDate>(
  _TestToday.new,
);

Future<void> _closeSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(10, 10));
  await tester.pumpAndSettle();
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

    await tester.tap(find.byType(DepthLink));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key(ScreenIds.evidenceSheet)), findsOneWidget);
    await _closeSheet(tester);
    expect(find.byKey(const Key(ScreenIds.evidenceSheet)), findsNothing);

    await tester.tap(find.byType(ShareButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key(ScreenIds.sharePreview)), findsOneWidget);
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
        shareRendererProvider.overrideWithValue(renderer),
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
            explainBody: (termId, sourceSlotId) => ProviderScope(
              overrides: [
                glossaryProvider.overrideWith((ref) {
                  if (++attempts == 1) return firstAttempt.future;
                  final dot = termId.indexOf('.');
                  return GlossaryNames({
                    termId.substring(0, dot): {
                      termId.substring(dot + 1): '풀이 이름',
                    },
                  });
                }),
              ],
              child: ExplainSheet(termId: termId, sourceSlotId: sourceSlotId),
            ),
            evidenceBody: (_) => const SizedBox.shrink(),
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

  testWidgets('member: 가이드 카드 → diary-edit, 돌아오면 일기 여부를 다시 확인합니다', (
    tester,
  ) async {
    covers(const Covers(exits: ['today>diary-edit']));
    final container = await _openToday(tester);
    final action = find.bySemanticsIdentifier(SlotIds.todayGuideCta);
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(ScreenIds.diaryEdit)), findsOneWidget);

    // 일기 화면에 있는 동안 일기를 썼다고 봅니다: 이제 getDiary는 200입니다.
    final written = _DiaryWritten();
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, written);

    container.read(routerProvider).pop();
    await pumpUntil(
      tester,
      () =>
          tester
              .widget<GuideQuestionCard>(find.byType(GuideQuestionCard))
              .state ==
          GuideQuestionState.after,
    );
    // 돌아온 뒤 한 번 다시 물었고, 쓴 뒤 상태(도장)와 쓴 일기 보기로 바뀝니다.
    expect(written.calls, 1);
    final card = tester.widget<GuideQuestionCard>(
      find.byType(GuideQuestionCard),
    );
    expect(card.actionLabel, _ko.todayGuideCtaWritten);
  });

  testWidgets('diary-written: 가이드 카드 → diary-view', (tester) async {
    covers(const Covers(exits: ['today>diary-view']));
    await _openToday(tester, scenario: 'diary-written');
    final action = find.bySemanticsIdentifier(SlotIds.todayGuideCta);
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(ScreenIds.diaryView)), findsOneWidget);
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

    container.read(_testTodayProvider.notifier).date = CalendarDate(
      2026,
      10,
      14,
    );
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
    final unlock = evidenceUnlockControllerProvider(
      const DailyEvidenceSubject(),
    );

    await tester.tap(find.byType(DepthLink));
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
