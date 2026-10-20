import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/diary/diary_row.dart';
import 'package:myungli_diary/design/components/diary/tag_chip.dart';
import 'package:myungli_diary/design/components/feedback/empty_state.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/features/glossary/application/glossary_providers.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_bar_title.dart';
import '../support/app_harness.dart';
import '../support/onboarding_steps.dart';

final _ko = AppLocalizationsKo();
const _tag = 'cheoneul_gwiin';
const _listPath = '/v1/diaries';
const _meaning = '어려울 때 도와주는 사람이 곁에 오는 기운이에요.';

/// [failListing]이면 일기 목록 GET을 503으로 답하고, [holdListing]이면 [gate]가 열릴 때까지
/// 붙잡습니다. [termInMeaning]이면 용어 사전의 태그 뜻 끝에 용어 조각을 붙여 답합니다.
final class _Network extends Interceptor {
  bool failListing = false;
  bool holdListing = false;
  bool termInMeaning = false;
  final gate = Completer<void>();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.method == 'GET' && options.path == _listPath) {
      if (holdListing) await gate.future;
      if (failListing) {
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
    }
    if (termInMeaning && options.path == '/v1/glossary') {
      handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: _glossaryWithTerm(),
          headers: Headers.fromMap({
            Headers.contentTypeHeader: ['application/json'],
          }),
        ),
        true,
      );
      return;
    }
    handler.next(options);
  }

  /// member 용어 사전에서 [_tag] 뜻 끝에 `element.wood` 용어 조각을 붙인 본문.
  static Map<String, Object?> _glossaryWithTerm() {
    final fixture = jsonDecode(
      File('fixtures/member/getGlossary.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final body = fixture['body']! as Map<String, Object?>;
    final meanings = body['meanings']! as Map<String, Object?>;
    meanings['tag.$_tag'] = {
      'segments': [
        {'text': '$_meaning '},
        {'text': '목', 'term': 'element.wood'},
        {'text': '의 기운과 함께 와요.'},
      ],
    };
    return body;
  }
}

/// member로 앱을 띄우고 [tag] 모아보기를 엽니다. [network]가 있으면 용어 사전을 다시 받습니다.
Future<ProviderContainer> _openTagDiary(
  WidgetTester tester, {
  String? tag = _tag,
  _Network? network,
}) async {
  final container = await pumpApp(tester, scenario: 'member');
  if (network != null) {
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, network);
    container.invalidate(glossaryProvider);
  }
  final path = tag == null ? pathOf(ScreenIds.tagDiary) : taggedPathOf(tag);
  unawaited(container.read(routerProvider).push<void>(path));
  await pumpUntilScreen(tester, ScreenIds.tagDiary);
  if (!(network?.holdListing ?? false)) {
    await _untilShown(tester);
  }
  return container;
}

/// 목록 줄이나 빈 안내, 오류 화면이 보일 때까지 기다립니다.
Future<void> _untilShown(WidgetTester tester) async {
  await pumpUntil(
    tester,
    () =>
        find.byType(DiaryRow).evaluate().isNotEmpty ||
        find.byType(EmptyState).evaluate().isNotEmpty ||
        find.byType(ErrorState).evaluate().isNotEmpty,
  );
  await settleWithIo(tester);
}

Finder get _screen => find.byKey(const ValueKey(ScreenIds.tagDiary));

void main() {
  testWidgets('제목은 태그 이름, 뜻 한 줄, 그 태그의 일기 줄', (tester) async {
    covers(const Covers(decisions: ['D47']));
    await _openTagDiary(tester);
    await expectAppBarTitle(
      tester,
      SlotIds.tagDiaryBarTitle,
      _ko.tagDiaryBarTitle('천을귀인'),
    );
    expect(find.text(_meaning), findsOneWidget);
    expect(find.byType(DiaryRow), findsWidgets);
    // 목록과 같은 태그 칩은 같은 화면을 다시 쌓지 않도록 누를 수 없습니다.
    final chips = tester.widgetList<TagChip>(
      find.descendant(of: _screen, matching: find.byType(TagChip)),
    );
    expect(chips, isNotEmpty);
    expect(chips.every((chip) => chip.onTap == null), isTrue);
  });

  testWidgets('diary-view의 태그 칩 → 그 태그 모아보기', (tester) async {
    covers(const Covers(exits: ['diary-view>tag-diary']));
    final container = await pumpApp(tester, scenario: 'member');
    unawaited(
      container
          .read(routerProvider)
          .push<void>(
            datedPathOf(ScreenIds.diaryView, CalendarDate(2026, 10, 12)),
          ),
    );
    await pumpUntil(tester, () => find.byType(TagChip).evaluate().isNotEmpty);
    await settleWithIo(tester);
    await tester.tap(find.byType(TagChip).first);
    await pumpUntilScreen(tester, ScreenIds.tagDiary);
    await _untilShown(tester);
    expect(
      GoRouterState.of(tester.element(_screen)).uri.toString(),
      '/tag-diary?tag=$_tag',
    );
  });

  testWidgets('줄을 누르면 그날 diary-view', (tester) async {
    covers(const Covers(exits: ['tag-diary>diary-view']));
    await _openTagDiary(tester);
    await tester.tap(find.byType(DiaryRow).first);
    await pumpUntilScreen(tester, ScreenIds.diaryView);
    await settleWithIo(tester);
    final view = find.byKey(const ValueKey(ScreenIds.diaryView));
    expect(
      GoRouterState.of(tester.element(view)).uri.toString(),
      '/diary-view?date=2026-10-12',
    );
  });

  testWidgets('뜻의 용어 칩 → 풀이 시트', (tester) async {
    covers(const Covers(exits: ['tag-diary>explain-sheet']));
    await _openTagDiary(tester, network: _Network()..termInMeaning = true);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey(SlotIds.tagDiaryTagMeaning)),
        matching: find.byType(TermToken),
      ),
    );
    await settleWithIo(tester);
    expect(find.byKey(const Key(ScreenIds.explainSheet)), findsOneWidget);
  });

  testWidgets('empty: 그 태그가 붙은 일기가 없으면 안내, 뜻이 없으면 뜻 줄도 없습니다', (tester) async {
    covers(const Covers(states: ['tag-diary:empty']));
    await _openTagDiary(tester, tag: 'yeokma');
    expect(find.text(_ko.tagDiaryEmptyBody), findsOneWidget);
    expect(
      find.byKey(const ValueKey(SlotIds.tagDiaryTagMeaning)),
      findsNothing,
    );
    await expectAppBarTitle(
      tester,
      SlotIds.tagDiaryBarTitle,
      _ko.tagDiaryBarTitle('역마'),
    );
  });

  testWidgets('태그 없는 경로는 목록을 묻지 않고 빈 안내', (tester) async {
    await _openTagDiary(tester, tag: null);
    expect(find.text(_ko.tagDiaryEmptyBody), findsOneWidget);
    expect(find.byType(DiaryRow), findsNothing);
  });

  testWidgets('loading: 목록을 받는 동안 skeleton, 오면 줄', (tester) async {
    covers(const Covers(states: ['tag-diary:loading']));
    final network = _Network()..holdListing = true;
    await _openTagDiary(tester, network: network);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.descendant(
        of: _screen,
        matching: find.byKey(const ValueKey('screen-state.loading')),
      ),
      findsOneWidget,
    );
    expect(find.byType(DiaryRow), findsNothing);

    network.gate.complete();
    await _untilShown(tester);
    expect(find.byType(DiaryRow), findsWidgets);
  });

  testWidgets('error: 목록을 받지 못하면 오류 화면과 다시 시도', (tester) async {
    covers(const Covers(states: ['tag-diary:error']));
    final network = _Network()..failListing = true;
    await _openTagDiary(tester, network: network);
    expect(find.byType(ErrorState), findsOneWidget);

    network.failListing = false;
    await tester.tap(find.text(_ko.actionRetry));
    await _untilShown(tester);
    expect(find.byType(DiaryRow), findsWidgets);
  });
}
