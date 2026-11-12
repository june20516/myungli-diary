import 'dart:async';
import 'dart:convert';

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
import 'package:myungli_diary/design/components/action/breathing_dots.dart';
import 'package:myungli_diary/design/components/diary/date_block.dart';
import 'package:myungli_diary/design/components/diary/diary_editor.dart';
import 'package:myungli_diary/design/components/diary/draft_indicator.dart';
import 'package:myungli_diary/design/components/feedback/empty_state.dart';
import 'package:myungli_diary/design/components/feedback/error_state.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';
import 'package:myungli_diary/design/components/sentence/hanja_tag.dart';
import 'package:myungli_diary/design/elements/keyboard_dismiss.dart';
import 'package:myungli_diary/design/elements/seal.dart';
import 'package:myungli_diary/features/diary/application/diary_edit.dart';
import 'package:myungli_diary/features/diary/model/diary_draft_target.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_bar_title.dart';
import '../support/app_harness.dart';
import '../support/onboarding_steps.dart';

final _ko = AppLocalizationsKo();
final _today = CalendarDate(2026, 10, 13);

/// fake 시드의 2026-10-12 일기.
const _writtenId = '7b1c2a54-3d0e-4f6a-9b21-5e8f40c1a001';

/// [offline]이면 모든 요청을 연결 오류로 끊고, [failingPaths]의 GET은 503으로 답합니다.
final class _Network extends Interceptor {
  bool offline = false;
  final failingPaths = <String>{};

  /// 있으면 `createDiary` 요청을 이 completer가 끝날 때까지 붙잡습니다.
  Completer<void>? holdCreate;

  /// 있으면 `getDaily` 응답의 `guideCandidates`를 이 목록으로 바꿉니다.
  List<Map<String, Object?>>? candidates;

  /// 보낸 `createDiary` 요청 본문들.
  final createBodies = <Map<String, Object?>>[];

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final override = candidates;
    if (override != null && response.requestOptions.path.contains('/daily')) {
      final data = response.data;
      final decoded = Map<String, Object?>.from(
        (data is String ? jsonDecode(data) : data)! as Map,
      );
      final changed = {...decoded, 'guideCandidates': override};
      response.data = data is String ? jsonEncode(changed) : changed;
    }
    handler.next(response);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method == 'POST' && options.path == '/v1/diaries') {
      final data = options.data;
      createBodies.add(
        Map<String, Object?>.from(
          (data is String ? jsonDecode(data) : data)! as Map,
        ),
      );
    }
    final hold = holdCreate;
    if (hold != null &&
        options.method == 'POST' &&
        options.path == '/v1/diaries') {
      unawaited(hold.future.then((_) => handler.next(options)));
      return;
    }
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

/// [scenario]로 앱을 띄우고 [path](`diary-edit` 경로) 일기 쓰기를 엽니다.
Future<ProviderContainer> _openEditAt(
  WidgetTester tester,
  String path, {
  _Network? network,
  String scenario = 'member',
}) async {
  final container = await pumpApp(tester, scenario: scenario);
  if (network != null) {
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, network);
  }
  unawaited(container.read(routerProvider).push<void>(path));
  await _untilShown(tester);
  expect(find.byKey(const ValueKey(ScreenIds.diaryEdit)), findsOneWidget);
  return container;
}

/// [date]의 새 일기 쓰기를 엽니다.
Future<ProviderContainer> _openEdit(
  WidgetTester tester,
  CalendarDate date, {
  _Network? network,
  String scenario = 'member',
}) => _openEditAt(
  tester,
  datedPathOf(ScreenIds.diaryEdit, date),
  network: network,
  scenario: scenario,
);

/// 열린 [screenId] 화면의 경로.
Uri _uriOf(WidgetTester tester, String screenId) =>
    GoRouterState.of(tester.element(find.byKey(ValueKey(screenId)).last)).uri;

Finder get _body => find.byType(TextField);

/// 쓰기 화면이 본문 칸이나 오류·찾지 못함 안내를 보일 때까지 기다립니다. 받는 동안 skeleton이
/// 나오기 전(300ms)에는 프레임이 없어 [settleWithIo]만으로는 일찍 끝납니다.
Future<void> _untilShown(WidgetTester tester) => pumpUntil(
  tester,
  () =>
      find.byType(TextField).evaluate().isNotEmpty ||
      find.byType(ErrorState).evaluate().isNotEmpty ||
      find.byType(EmptyState).evaluate().isNotEmpty,
);

/// 상단 바 오른쪽 저장 글자 버튼(`app-bar` `textAction`).
AppBarTextAction _saveButton(WidgetTester tester) =>
    tester.widget<AppBarTextAction>(find.byType(AppBarTextAction));

bool _bodyFocused(WidgetTester tester) =>
    tester.widget<TextField>(_body).focusNode!.hasFocus;

/// 본문에 초점을 주고, 입력칸이 초점 상태로 다시 그려질 때까지 프레임을 돌립니다.
Future<void> _focusBody(WidgetTester tester) async {
  await tester.showKeyboard(_body);
  await tester.pump();
  await tester.pump();
}

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
    expect(find.text('오늘 마음이 잘 맞았던 대화가 있었다면 적어 볼까요?'), findsOneWidget);
    expect(find.text(_ko.diaryEditBodyPlaceholder), findsOneWidget);
    expect(find.byType(DraftIndicator), findsNothing);
    expect(_saveButton(tester).enabled, isFalse);
    // 아래 고정 저장 버튼은 없고 저장은 상단 바 글자 버튼입니다(V82).
    expect(find.text(_ko.diaryEditSave), findsOneWidget);
  });

  testWidgets('맨 위 큰 날짜 블록: 일 숫자, 월과 요일, 그날 일진', (tester) async {
    await _openEdit(tester, _today);
    expect(find.byType(DateBlock), findsOneWidget);
    final block = tester.widget<DateBlock>(find.byType(DateBlock));
    expect(block.day, _ko.diaryEditDateDay('13'));
    expect(block.monthWeekday, _ko.diaryEditDateMonth('10월 화요일'));
    // member 그날 일진은 庚申입니다. 독음 원천이 오기 전(#1069)이라 한자만입니다(A133).
    expect(block.iljin, _ko.diaryEditDateIljin('庚申'));
    expect(
      tester.getTopLeft(find.byKey(DiaryEditor.paperKey)).dy,
      greaterThan(tester.getBottomLeft(find.byType(DateBlock)).dy),
    );
  });

  testWidgets('질문 바꾸기: 그날 후보 넷을 돌고, 저장하면 고른 질문이 diary-view에 남습니다', (
    tester,
  ) async {
    covers(const Covers(exits: ['diary-edit>diary-view']));
    final container = await _openEdit(tester, _today);
    // member fixture의 그날 후보 순서: 합 질문 둘, 대표 태그 2순위 질문, 일진 십성 묶음 질문.
    const first = '오늘 마음이 잘 맞았던 대화가 있었다면 적어 볼까요?';
    const second = '오늘 함께해서 좋았던 사람이 있었나요?';
    const third = '오늘 끝까지 지키고 싶었던 내 생각을 적어 볼까요?';
    const fourth = '오늘 함께 시간을 보낸 사람이 있었다면 그 이야기를 적어 볼까요?';
    Future<void> swap() async {
      await tester.tap(find.byKey(DiaryEditor.swapKey));
      await tester.pumpAndSettle();
    }

    expect(find.text(first), findsOneWidget);
    await swap();
    expect(find.text(second), findsOneWidget);
    expect(find.text(first), findsNothing);
    await swap();
    expect(find.text(third), findsOneWidget);
    await swap();
    expect(find.text(fourth), findsOneWidget);
    await swap();
    expect(find.text(first), findsOneWidget);
    await swap();

    await tester.enterText(_body, '들은 말을 적었다.');
    await tester.pump();
    await tester.tap(find.text(_ko.diaryEditSave));
    await pumpUntil(
      tester,
      () => find.text(_ko.diaryEditSavedTags).evaluate().isNotEmpty,
    );
    expect(_server(container).callCountOf('createDiary'), 1);
    await pumpUntilScreen(tester, ScreenIds.diaryView);
    await pumpUntil(tester, () => find.text(second).evaluate().isNotEmpty);
    // 보기는 같은 인용 모양이고 바꾸기가 없습니다.
    expect(find.byKey(DiaryEditor.quoteLineKey), findsOneWidget);
    expect(find.byKey(DiaryEditor.swapKey), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await settleWithIo(tester);
  });

  testWidgets('쓰는 중(본문 초점)에만 가운데가 초안 상태와 글자 수, 밖을 누르면 제목', (tester) async {
    await _openEdit(tester, _today);
    await _focusBody(tester);
    await tester.enterText(_body, '열 글자 일기 쓰기');
    await tester.pump(diaryDraftDelay + const Duration(milliseconds: 100));
    await settleWithIo(tester);
    final indicator = tester.widget<DraftIndicator>(
      find.byType(DraftIndicator),
    );
    expect(indicator.state, DraftIndicatorState.local);
    expect(indicator.length, 10);
    expect(_saveButton(tester).enabled, isTrue);

    await tester.tapAt(
      tester.getBottomLeft(find.byType(DateBlock)) + const Offset(200, -10),
    );
    await tester.pumpAndSettle();
    expect(_bodyFocused(tester), isFalse);
    expect(find.byType(DraftIndicator), findsNothing);
  });

  testWidgets('저장 중: 상단 바 저장 글자는 점 숨쉬기이고, 뒤로를 눌러도 화면이 남습니다', (tester) async {
    final network = _Network();
    await _openEdit(tester, _today, network: network);
    await tester.enterText(_body, '보내는 중인 글');
    await tester.pump();
    final hold = network.holdCreate = Completer<void>();
    await tester.tap(find.text(_ko.diaryEditSave));
    await tester.pump();
    expect(_saveButton(tester).saving, isTrue);
    expect(
      find.descendant(
        of: find.byType(AppBarTextAction),
        matching: find.byType(BreathingDots),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('app-bar.back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey(ScreenIds.diaryEdit)), findsOneWidget);

    hold.complete();
    await pumpUntilScreen(tester, ScreenIds.diaryView);
    await tester.pump(const Duration(seconds: 3));
    await settleWithIo(tester);
  });

  testWidgets('스택 바닥(딥링크)에서 저장 중 뒤로를 눌러도 목록으로 가지 않습니다', (tester) async {
    final network = _Network();
    final container = await pumpApp(tester, scenario: 'member');
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, network);
    container.read(routerProvider).go(datedPathOf(ScreenIds.diaryEdit, _today));
    await _untilShown(tester);
    await tester.enterText(_body, '바닥에서 쓰는 글');
    await tester.pump();
    final hold = network.holdCreate = Completer<void>();
    await tester.tap(find.text(_ko.diaryEditSave));
    await tester.pump();
    expect(_saveButton(tester).saving, isTrue);

    await tester.tap(find.byKey(const ValueKey('app-bar.back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey(ScreenIds.diaryEdit)), findsOneWidget);
    expect(find.byKey(const ValueKey(ScreenIds.diaryList)), findsNothing);

    hold.complete();
    await pumpUntilScreen(tester, ScreenIds.diaryView);
    await tester.pump(const Duration(seconds: 3));
    await settleWithIo(tester);
  });

  testWidgets('422 diary.guide_invalid: 일반 저장 실패 문구 toast, 본문과 화면은 그대로', (
    tester,
  ) async {
    // 화면은 셋째 후보를 받았지만 server의 그날 후보에는 없습니다.
    Map<String, Object?> candidate(String key, String variant, String text) => {
      'slot': 'daily.guide',
      'messageKey': key,
      'variant': variant,
      'reactable': false,
      'text': {
        'segments': [
          {'text': text},
        ],
      },
    };
    final network = _Network()
      ..candidates = [
        candidate('guide.harmony', '1', '오늘 마음이 잘 맞았던 대화가 있었다면 적어 볼까요?'),
        candidate('guide.harmony', '2', '오늘 함께해서 좋았던 사람이 있었나요?'),
        candidate('guide.gongmang', '1', '오늘 기대와 다르게 흘러간 일이 있었다면 하나 적어 볼까요?'),
      ];
    final container = await _openEdit(tester, _today, network: network);
    await tester.tap(find.byKey(DiaryEditor.swapKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DiaryEditor.swapKey));
    await tester.pumpAndSettle();
    network.candidates = null;
    await tester.enterText(_body, '지켜야 할 글');
    await tester.pump();
    await tester.tap(find.text(_ko.diaryEditSave));
    await pumpUntil(
      tester,
      () => find.text(_ko.errorClient).evaluate().isNotEmpty,
    );
    expect(_server(container).callCountOf('createDiary'), 1);
    expect(find.byKey(const ValueKey(ScreenIds.diaryEdit)), findsOneWidget);
    expect(tester.widget<TextField>(_body).controller!.text, '지켜야 할 글');
    // 다시 읽은 후보(fixture 넷)의 첫 질문으로 돌아옵니다.
    expect(find.text('오늘 마음이 잘 맞았던 대화가 있었다면 적어 볼까요?'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await settleWithIo(tester);
  });

  group('키보드 내리기(F-013)', () {
    testWidgets('본문 초점 중 종이 밖(날짜 블록)을 누르면 키보드가 내려갑니다', (tester) async {
      await _openEdit(tester, _today);
      await _focusBody(tester);
      expect(_bodyFocused(tester), isTrue);
      await tester.tap(find.byType(DateBlock));
      await tester.pump();
      expect(_bodyFocused(tester), isFalse);
    });

    testWidgets('스크롤을 끌면 키보드가 내려갑니다', (tester) async {
      await _openEdit(tester, _today);
      await _focusBody(tester);
      await tester.enterText(
        _body,
        List.generate(40, (i) => '줄 $i').join('\n'),
      );
      // 커서를 보이게 하는 스크롤 애니메이션(다음 프레임에 시작) 동안은 스크롤 안 누르기가
      // 무시되므로 끝까지 둡니다.
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_bodyFocused(tester), isTrue);
      // 본문 칸 안에서 끌기 시작해 밖 누르기(onTapOutside)가 아니라 스크롤 끌기만 봅니다. 긴
      // 본문은 일부만 보이므로 보이는 영역과 본문 칸이 겹친 곳 가운데에서 시작합니다.
      final viewport = tester.getRect(
        find.ancestor(of: _body, matching: find.byType(Scrollable)).first,
      );
      final visibleBody = viewport.intersect(tester.getRect(_body));
      await tester.dragFrom(visibleBody.center, const Offset(0, -200));
      await tester.pump();
      expect(_bodyFocused(tester), isFalse);
      // 쓴 글의 초안 쓰기(디바운스)가 끝날 때까지 둡니다.
      await tester.pump(diaryDraftDelay);
      await settleWithIo(tester);
    });

    testWidgets('키보드 위 내리기 버튼을 누르면 키보드가 내려갑니다', (tester) async {
      tester.view.viewInsets = FakeViewPadding(
        bottom: 300 * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetViewInsets);
      await _openEdit(tester, _today);
      await _focusBody(tester);
      await tester.pump();
      expect(find.byType(KeyboardDismissButton), findsOneWidget);
      await tester.tap(find.byType(KeyboardDismissButton));
      await tester.pump();
      expect(_bodyFocused(tester), isFalse);
      expect(find.byType(KeyboardDismissButton), findsNothing);
    });
  });

  testWidgets('쓰면 잠시 뒤 기기에 초안, 저장하면 도장·대표 태그·toast 뒤 diary-view', (
    tester,
  ) async {
    covers(const Covers(exits: ['diary-edit>diary-view'], decisions: ['D49']));
    final container = await _openEdit(tester, _today);
    await tester.enterText(_body, '회의에서 먼저 말을 꺼냈다.');
    await tester.pump(diaryDraftDelay + const Duration(milliseconds: 100));
    await settleWithIo(tester);
    // 쓰는 중(초점)이라 가운데가 초안 상태입니다.
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
    expect(_server(container).callCountOf('createDiary'), 1);
    await pumpUntilScreen(tester, ScreenIds.diaryView);
    await pumpUntil(
      tester,
      () => find.textContaining('먼저 말을 꺼냈다').evaluate().isNotEmpty,
    );
    await settleWithIo(tester, allowOngoing: true);

    // 새로 쓴 일기는 server가 준 id로 엽니다.
    final location = _uriOf(tester, ScreenIds.diaryView);
    expect(location.path, '/diary-view');
    final id = location.queryParameters[diaryIdQuery];
    expect(id, isNotNull);
    expect(id, isNot(_writtenId));
    expect(location.queryParameters, {diaryIdQuery: id});
    expect(find.byKey(const ValueKey(ScreenIds.diaryEdit)), findsNothing);
    // toast가 사라질 때까지 둡니다.
    await tester.pump(const Duration(seconds: 3));
    await settleWithIo(tester);
  });

  testWidgets('저장 순간에 도장과 대표 태그이 종이에 남습니다', (tester) async {
    await _openEdit(tester, _today);
    await tester.enterText(_body, '오늘 일기');
    await tester.pump();
    await tester.tap(find.text(_ko.diaryEditSave));
    // 저장 응답(실제 I/O)을 받은 뒤 스크롤 → 도장 → 대표 태그 순서로 종이에 남습니다.
    final onPaper = find.descendant(
      of: find.descendant(
        of: find.byKey(const ValueKey(ScreenIds.diaryEdit)),
        matching: find.byKey(DiaryEditor.tagsKey),
      ),
      matching: find.byType(HanjaTag),
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

  testWidgets('질문 떼기: 권유 줄로 바뀌고 다시 붙이면 첫 질문, 뗀 채 저장하면 diary-view에 질문이 없습니다', (
    tester,
  ) async {
    final network = _Network();
    final container = await _openEdit(tester, _today, network: network);
    const first = '오늘 마음이 잘 맞았던 대화가 있었다면 적어 볼까요?';
    const second = '오늘 함께해서 좋았던 사람이 있었나요?';
    await tester.tap(find.byKey(DiaryEditor.swapKey));
    await tester.pumpAndSettle();
    expect(find.text(second), findsOneWidget);

    await tester.tap(find.byKey(DiaryEditor.removeKey));
    await tester.pumpAndSettle();
    expect(find.text(second), findsNothing);
    expect(find.byKey(DiaryEditor.quoteLineKey), findsNothing);
    expect(find.byKey(DiaryEditor.swapKey), findsNothing);
    expect(find.text(_ko.diaryEditGuideAttach), findsOneWidget);

    // 다시 붙이면 그날 기본 질문(첫 후보)입니다.
    await tester.tap(find.text(_ko.diaryEditGuideAttach));
    await tester.pumpAndSettle();
    expect(find.text(first), findsOneWidget);
    expect(find.byKey(DiaryEditor.removeKey), findsOneWidget);

    await tester.tap(find.byKey(DiaryEditor.removeKey));
    await tester.pumpAndSettle();
    await tester.enterText(_body, '질문 없이 적었다.');
    await tester.pump();
    await tester.tap(find.text(_ko.diaryEditSave));
    await pumpUntil(
      tester,
      () => find.text(_ko.diaryEditSavedTags).evaluate().isNotEmpty,
    );
    expect(_server(container).callCountOf('createDiary'), 1);
    // 뗀 채 저장하면 withoutGuideQuestion true만 보내고 고른 질문은 싣지 않습니다(D116).
    final body = network.createBodies.single;
    expect(body['withoutGuideQuestion'], isTrue);
    expect(body.containsKey('guideQuestion'), isFalse);
    await pumpUntilScreen(tester, ScreenIds.diaryView);
    await pumpUntil(
      tester,
      () => find.text('질문 없이 적었다.').evaluate().isNotEmpty,
    );
    expect(find.byKey(DiaryEditor.quoteLineKey), findsNothing);
    expect(find.text(first), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await settleWithIo(tester);
  });

  testWidgets('이미 쓴 날도 ?date=는 빈 새 일기입니다', (tester) async {
    await _openEdit(tester, CalendarDate(2026, 10, 12));
    expect(tester.widget<TextField>(_body).controller!.text, isEmpty);
    expect(find.byType(DraftIndicator), findsNothing);
  });

  testWidgets('?id=로 열면 그 일기 본문이고 저장됨 상태, 질문 바꾸기는 없습니다', (tester) async {
    await _openEditAt(tester, diaryPathOf(ScreenIds.diaryEdit, _writtenId));
    expect(
      tester.widget<TextField>(_body).controller!.text,
      startsWith('오랜만에'),
    );
    expect(find.byKey(DiaryEditor.swapKey), findsNothing);
    // 질문은 쓸 때만 정해 고치기에서는 뗄 수도 없습니다(D116, `updateDiary`).
    expect(find.byKey(DiaryEditor.removeKey), findsNothing);
    // 초점 전에는 제목, 쓰기 시작하면 저장됨 상태입니다.
    expect(find.byType(DraftIndicator), findsNothing);
    await _focusBody(tester);
    await tester.pump();
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
        () => container
            .read(diaryDraftStoreProvider)
            .read(DiaryDraftTarget.newOn(_today)),
      ),
      '끊긴 글',
    );
    expect(_saveButton(tester).enabled, isTrue, reason: '다시 시도');
  });

  testWidgets('error: 저장된 일기를 읽지 못하면 오류 화면과 다시 시도', (tester) async {
    covers(const Covers(states: ['diary-edit:error']));
    final network = _Network()..failingPaths.add('/v1/diaries/$_writtenId');
    await _openEditAt(
      tester,
      diaryPathOf(ScreenIds.diaryEdit, _writtenId),
      network: network,
    );
    expect(find.byType(ErrorState), findsOneWidget);
    network.failingPaths.clear();
    await tester.tap(find.text(_ko.actionRetry));
    await pumpUntil(tester, () => find.byType(TextField).evaluate().isNotEmpty);
    expect(
      tester.widget<TextField>(_body).controller!.text,
      startsWith('오랜만에'),
    );
  });

  testWidgets('?id=의 일기가 없으면(404) 찾지 못했다는 안내', (tester) async {
    await _openEditAt(tester, diaryPathOf(ScreenIds.diaryEdit, 'gone'));
    expect(find.text(_ko.errorDiaryNotFound), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('그날 10편이면 저장이 422 diary.day_full: 문구 toast, 화면과 초안은 그대로', (
    tester,
  ) async {
    final container = await _openEdit(
      tester,
      _today,
      scenario: 'diary-day-full',
    );
    await tester.enterText(_body, '열한 번째 일기');
    await tester.pump();
    await tester.tap(find.text(_ko.diaryEditSave));
    await pumpUntil(
      tester,
      () => find.text(_ko.errorDiaryDayFull).evaluate().isNotEmpty,
    );
    expect(find.text(_ko.errorDiaryDayFull), findsOneWidget);
    expect(_server(container).callCountOf('createDiary'), 1);
    expect(find.byKey(const ValueKey(ScreenIds.diaryEdit)), findsOneWidget);
    expect(find.byKey(const ValueKey(ScreenIds.diaryView)), findsNothing);
    expect(find.text('열한 번째 일기'), findsOneWidget);
    expect(
      await tester.runAsync(
        () => container
            .read(diaryDraftStoreProvider)
            .read(DiaryDraftTarget.newOn(_today)),
      ),
      '열한 번째 일기',
    );
    // toast가 사라질 때까지 둡니다.
    await tester.pump(const Duration(seconds: 3));
    await settleWithIo(tester);
  });
}
