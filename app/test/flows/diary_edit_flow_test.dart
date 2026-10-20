import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/diary/draft_indicator.dart';
import 'package:myungli_diary/design/components/diary/tag_chip.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/features/diary/application/diary_edit.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_bar_title.dart';
import '../support/app_harness.dart';
import '../support/onboarding_steps.dart';

final _ko = AppLocalizationsKo();
final _today = CalendarDate(2026, 10, 13);

/// [offline]이면 모든 요청을 연결 오류로 끊고, [failingPaths]의 GET은 503으로 답합니다.
final class _Network extends Interceptor {
  bool offline = false;
  final failingPaths = <String>{};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (offline) {
      handler.reject(
        DioException.connectionError(requestOptions: options, reason: '오프라인'),
        true,
      );
      return;
    }
    if (options.method == 'GET' && failingPaths.contains(options.path)) {
      handler.reject(
        DioException.badResponse(
          statusCode: 503,
          requestOptions: options,
          response: Response<Object?>(
            requestOptions: options,
            statusCode: 503,
            data: {
              'type': 'about:blank',
              'title': 'Unavailable',
              'status': 503,
              'code': 'service.unavailable',
              'traceId': 'test',
            },
            headers: Headers.fromMap({
              Headers.contentTypeHeader: ['application/problem+json'],
            }),
          ),
        ),
        true,
      );
      return;
    }
    handler.next(options);
  }
}

/// member로 앱을 띄우고 [date] 일기 쓰기를 엽니다.
Future<ProviderContainer> _openEdit(
  WidgetTester tester,
  CalendarDate date, {
  _Network? network,
}) async {
  final container = await pumpApp(tester, scenario: 'member');
  if (network != null) {
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, network);
  }
  unawaited(
    container
        .read(routerProvider)
        .push<void>(datedPathOf(ScreenIds.diaryEdit, date)),
  );
  await _untilShown(tester);
  expect(find.byKey(const ValueKey(ScreenIds.diaryEdit)), findsOneWidget);
  return container;
}

Finder get _body => find.byType(TextField);

/// 쓰기 화면이 본문 칸이나 오류 화면을 보일 때까지 기다립니다. 받는 동안 skeleton이
/// 나오기 전(300ms)에는 프레임이 없어 [settleWithIo]만으로는 일찍 끝납니다.
Future<void> _untilShown(WidgetTester tester) => pumpUntil(
  tester,
  () =>
      find.byType(TextField).evaluate().isNotEmpty ||
      find.byType(ErrorState).evaluate().isNotEmpty,
);

PrimaryButton _saveButton(WidgetTester tester) => tester.widget<PrimaryButton>(
  find.ancestor(
    of: find.text(_ko.diaryEditSave),
    matching: find.byType(PrimaryButton),
  ),
);

FakeServerInterceptor _server(ProviderContainer container) => container
    .read(dioProvider)
    .interceptors
    .whereType<FakeServerInterceptor>()
    .single;

void main() {
  testWidgets('새 일기: 그날 질문과 안내, 빈 본문이면 저장할 수 없습니다', (tester) async {
    covers(const Covers(states: ['diary-edit:loading'], decisions: ['D22']));
    await _openEdit(tester, _today);
    await expectAppBarTitle(
      tester,
      SlotIds.diaryEditBarTitle,
      _ko.diaryEditBarTitle,
    );
    expect(find.text('오늘 눈길이 갔던 사람이나 장면을 하나 적어 볼까요?'), findsOneWidget);
    expect(find.text(_ko.diaryEditBodyPlaceholder), findsOneWidget);
    expect(find.byType(DraftIndicator), findsNothing);
    expect(_saveButton(tester).onPressed, isNull);
  });

  testWidgets('쓰면 잠시 뒤 기기에 초안, 저장하면 도장·태그 칩·toast 뒤 diary-view', (
    tester,
  ) async {
    covers(const Covers(exits: ['diary-edit>diary-view'], decisions: ['D49']));
    final container = await _openEdit(tester, _today);
    await tester.enterText(_body, '회의에서 먼저 말을 꺼냈다.');
    await tester.pump(diaryDraftDelay + const Duration(milliseconds: 100));
    await settleWithIo(tester);
    expect(
      tester.widget<DraftIndicator>(find.byType(DraftIndicator)).state,
      DraftIndicatorState.local,
    );

    await tester.tap(find.text(_ko.diaryEditSave));
    // 저장 순간이 끝나면 toast가 뜹니다. 뒤이어 여는 diary-view의 읽기를 기다리는 사이
    // toast가 사라질 수 있어, 뜨는 때를 먼저 확인합니다.
    await pumpUntil(
      tester,
      () => find.text(_ko.diaryEditSavedTags).evaluate().isNotEmpty,
    );
    expect(_server(container).callCountOf('putDiary'), 1);
    await pumpUntilScreen(tester, ScreenIds.diaryView);
    await settleWithIo(tester, allowOngoing: true);

    final view = find.byKey(const ValueKey(ScreenIds.diaryView)).last;
    expect(
      GoRouterState.of(tester.element(view)).uri.toString(),
      '/diary-view?date=2026-10-13',
    );
    expect(find.byKey(const ValueKey(ScreenIds.diaryEdit)), findsNothing);
    // toast가 사라질 때까지 둡니다.
    await tester.pump(const Duration(seconds: 3));
    await settleWithIo(tester);
  });

  testWidgets('저장 순간에 도장과 대표 태그 칩이 종이에 남습니다', (tester) async {
    await _openEdit(tester, _today);
    await tester.enterText(_body, '오늘 일기');
    await tester.pump();
    await tester.tap(find.text(_ko.diaryEditSave));
    // 저장 응답(실제 I/O)을 받은 뒤 스크롤 → 도장 → 태그 칩 순서로 종이에 남습니다.
    final onPaper = find.descendant(
      of: find.byKey(const ValueKey(ScreenIds.diaryEdit)),
      matching: find.byType(TagChip),
    );
    for (var i = 0; i < 100 && onPaper.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(onPaper, findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey(ScreenIds.diaryEdit)),
        matching: find.byType(Seal),
      ),
      findsOneWidget,
    );
    // 저장 순간 뒤에 뜨는 toast가 사라질 때까지 둡니다.
    for (var i = 0; i < 2; i++) {
      await tester.pump(const Duration(seconds: 3));
      await settleWithIo(tester);
    }
  });

  testWidgets('저장된 일기는 그 본문으로 열리고 저장됨 상태입니다', (tester) async {
    await _openEdit(tester, CalendarDate(2026, 10, 12));
    expect(
      tester.widget<TextField>(_body).controller!.text,
      startsWith('오랜만에'),
    );
    expect(
      tester.widget<DraftIndicator>(find.byType(DraftIndicator)).state,
      DraftIndicatorState.saved,
    );
  });

  testWidgets('offline: 저장이 연결 오류로 실패하면 배너, 화면과 글은 그대로', (tester) async {
    covers(const Covers(states: ['diary-edit:offline', 'diary-edit:draft']));
    final network = _Network();
    final container = await _openEdit(tester, _today, network: network);
    await tester.enterText(_body, '끊긴 글');
    await tester.pump();
    network.offline = true;
    await tester.tap(find.text(_ko.diaryEditSave));
    await settleWithIo(tester);

    expect(
      find.byWidgetPredicate(
        (w) =>
            w is NoticeBanner &&
            w.variant == NoticeBannerVariant.offline &&
            w.present,
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey(ScreenIds.diaryEdit)), findsOneWidget);
    expect(find.text('끊긴 글'), findsOneWidget);
    expect(
      await tester.runAsync(
        () => container.read(diaryDraftStoreProvider).read(_today),
      ),
      '끊긴 글',
    );
    expect(_saveButton(tester).onPressed, isNotNull, reason: '다시 시도');
  });

  testWidgets('error: 저장된 일기를 읽지 못하면 오류 화면과 다시 시도', (tester) async {
    covers(const Covers(states: ['diary-edit:error']));
    final network = _Network()..failingPaths.add('/v1/diaries/2026-10-12');
    final container = await pumpApp(tester, scenario: 'member');
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, network);
    unawaited(
      container
          .read(routerProvider)
          .push<void>(
            datedPathOf(ScreenIds.diaryEdit, CalendarDate(2026, 10, 12)),
          ),
    );
    await _untilShown(tester);
    expect(find.byType(ErrorState), findsOneWidget);
    network.failingPaths.clear();
    await tester.tap(find.text(_ko.actionRetry));
    await pumpUntil(tester, () => find.byType(TextField).evaluate().isNotEmpty);
    expect(
      tester.widget<TextField>(_body).controller!.text,
      startsWith('오랜만에'),
    );
  });
}
