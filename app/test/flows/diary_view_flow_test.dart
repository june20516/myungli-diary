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
import 'package:myungli_diary/design/components/diary/tag_chip.dart';
import 'package:myungli_diary/design/components/feedback/empty_state.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/today/day_character.dart';
import 'package:myungli_diary/features/diary/presentation/diary_view_screen.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_bar_title.dart';
import '../support/app_harness.dart';
import '../support/onboarding_steps.dart';

final _ko = AppLocalizationsKo();
final _written = CalendarDate(2026, 10, 12);
const _writtenPath = '/v1/diaries/2026-10-12';

/// [failingPaths]의 GET은 503으로 답하고, [hold]가 있으면 그 GET을 [gate]가 열릴 때까지
/// 붙잡습니다.
final class _Network extends Interceptor {
  final failingPaths = <String>{};
  String? hold;
  final gate = Completer<void>();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.method == 'GET' && options.path == hold) {
      await gate.future;
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

/// member로 앱을 띄우고 홈 위에 [date] 일기 보기를 엽니다.
Future<ProviderContainer> _openView(
  WidgetTester tester,
  CalendarDate date, {
  _Network? network,
  bool settle = true,
}) async {
  final container = await pumpApp(tester, scenario: 'member');
  if (network != null) {
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, network);
  }
  unawaited(
    container
        .read(routerProvider)
        .push<void>(datedPathOf(ScreenIds.diaryView, date)),
  );
  if (settle) {
    await pumpUntil(
      tester,
      () =>
          _paper.evaluate().isNotEmpty ||
          find.byType(EmptyState).evaluate().isNotEmpty ||
          find.byType(ErrorState).evaluate().isNotEmpty,
    );
    await settleWithIo(tester);
  } else {
    await pumpUntilScreen(tester, ScreenIds.diaryView);
  }
  expect(find.byKey(const ValueKey(ScreenIds.diaryView)), findsOneWidget);
  return container;
}

/// 종이에 그려진 일기 본문.
Finder get _paper => find.textContaining('오랜만에 연락이 온 친구');

FakeServerInterceptor _server(ProviderContainer container) => container
    .read(dioProvider)
    .interceptors
    .whereType<FakeServerInterceptor>()
    .single;

void main() {
  testWidgets('그날 제목, 성격과 이유, 본문, 대표 태그 칩', (tester) async {
    await _openView(tester, _written);
    await expectAppBarTitle(
      tester,
      SlotIds.diaryViewBarTitle,
      _ko.diaryViewBarTitle('10월 12일'),
    );
    expect(find.byType(DayCharacter), findsOneWidget);
    expect(_paper, findsOneWidget);
    expect(find.byType(TagChip), findsWidgets);
    expect(find.byKey(DiaryViewScreen.editKey), findsOneWidget);
    expect(find.byKey(DiaryViewScreen.deleteKey), findsOneWidget);
  });

  testWidgets('성격을 누르면 그 성격 용어의 풀이 시트', (tester) async {
    covers(const Covers(exits: ['diary-view>explain-sheet']));
    await _openView(tester, _written);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey(SlotIds.diaryViewCharacterLabel)),
        matching: find.byType(PressInkTarget),
      ),
    );
    await settleWithIo(tester);
    expect(find.byKey(const Key(ScreenIds.explainSheet)), findsOneWidget);
  });

  testWidgets('고치기는 이 화면을 그날 쓰기 화면으로 바꿉니다', (tester) async {
    covers(const Covers(exits: ['diary-view>diary-edit']));
    await _openView(tester, _written);
    await tester.tap(find.byKey(DiaryViewScreen.editKey));
    await pumpUntil(tester, () => find.byType(TextField).evaluate().isNotEmpty);
    await settleWithIo(tester);

    final edit = find.byKey(const ValueKey(ScreenIds.diaryEdit));
    expect(edit, findsOneWidget);
    expect(find.byKey(const ValueKey(ScreenIds.diaryView)), findsNothing);
    expect(
      GoRouterState.of(tester.element(edit)).uri.toString(),
      '/diary-edit?date=2026-10-12',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      startsWith('오랜만에'),
    );
  });

  testWidgets('지우기: 확인하면 지우고 앞 화면으로 돌아가 toast', (tester) async {
    covers(const Covers(decisions: ['A50']));
    final container = await _openView(tester, _written);
    await tester.tap(find.byKey(DiaryViewScreen.deleteKey));
    await settleWithIo(tester);
    expect(find.text(_ko.diaryViewDeleteConfirm), findsOneWidget);

    await tester.tap(find.text(_ko.diaryViewDeleteConfirmDelete));
    await settleWithIo(tester, allowOngoing: true);

    expect(_server(container).callCountOf('deleteDiary'), 1);
    expect(find.byKey(const ValueKey(ScreenIds.diaryView)), findsNothing);
    expect(find.text(_ko.diaryViewDeleted), findsOneWidget);
    // toast가 사라질 때까지 둡니다.
    await tester.pump(const Duration(seconds: 3));
    await settleWithIo(tester);
  });

  testWidgets('지우기: 취소하면 그대로입니다', (tester) async {
    final container = await _openView(tester, _written);
    await tester.tap(find.byKey(DiaryViewScreen.deleteKey));
    await settleWithIo(tester);
    await tester.tap(find.text(_ko.diaryViewDeleteConfirmCancel));
    await settleWithIo(tester);

    expect(_server(container).callCountOf('deleteDiary'), 0);
    expect(find.byKey(const ValueKey(ScreenIds.diaryView)), findsOneWidget);
    expect(_paper, findsOneWidget);
  });

  testWidgets('없는 일기면 그 안내만, 고치기·지우기는 없습니다', (tester) async {
    await _openView(tester, CalendarDate(2026, 10, 6));
    expect(find.text(_ko.errorDiaryNotFound), findsOneWidget);
    expect(find.byKey(DiaryViewScreen.editKey), findsNothing);
    expect(find.byKey(DiaryViewScreen.deleteKey), findsNothing);
  });

  testWidgets('loading: 일기를 받는 동안 skeleton, 오면 본문', (tester) async {
    covers(const Covers(states: ['diary-view:loading']));
    final network = _Network()..hold = _writtenPath;
    await _openView(tester, _written, network: network, settle: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('screen-state.loading')), findsOneWidget);
    expect(_paper, findsNothing);

    network.gate.complete();
    await pumpUntil(tester, () => _paper.evaluate().isNotEmpty);
    await settleWithIo(tester);
    expect(_paper, findsOneWidget);
  });

  testWidgets('error: 일기를 받지 못하면 오류 화면과 다시 시도', (tester) async {
    covers(const Covers(states: ['diary-view:error']));
    final network = _Network()..failingPaths.add(_writtenPath);
    await _openView(tester, _written, network: network);
    expect(find.byType(ErrorState), findsOneWidget);

    network.failingPaths.clear();
    await tester.tap(find.text(_ko.actionRetry));
    await pumpUntil(tester, () => _paper.evaluate().isNotEmpty);
    await settleWithIo(tester);
    expect(_paper, findsOneWidget);
  });
}
