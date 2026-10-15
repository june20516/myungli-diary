import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/action/share_button.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/design/components/today/guide_question_card.dart';
import 'package:myungli_diary/features/today/application/daily_controller.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_harness.dart';
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
          'today>evidence-sheet',
          'today>share-preview',
        ],
      ),
    );
    await _openToday(tester);

    await tester.tap(find.byType(TermToken).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key(ScreenIds.explainSheet)), findsOneWidget);
    await _closeSheet(tester);
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

    container.read(routerProvider).pop();
    await _settleToday(tester);
    expect(find.byKey(const ValueKey(ScreenIds.today)), findsOneWidget);
    expect(
      tester.widget<GuideQuestionCard>(find.byType(GuideQuestionCard)).state,
      GuideQuestionState.before,
    );
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
    await pumpUntil(tester, () => hold.requested);
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
}
