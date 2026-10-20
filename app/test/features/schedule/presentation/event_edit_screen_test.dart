import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/gen/model/calendar.dart';
import 'package:myungli_diary/core/api/gen/model/schedule.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/clock/clock.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/skeleton.dart';
import 'package:myungli_diary/design/components/input/date_picker.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/design/components/input/text_field.dart';
import 'package:myungli_diary/design/components/input/time_picker.dart';
import 'package:myungli_diary/design/components/sentence/rendered_text_view.dart';
import 'package:myungli_diary/features/calendar/application/calendar_providers.dart';
import 'package:myungli_diary/features/schedule/application/schedule_providers.dart';
import 'package:myungli_diary/features/schedule/data/schedule_repository.dart';
import 'package:myungli_diary/features/schedule/presentation/event_edit_screen.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../../../support/app_bar_title.dart';
import '../../../support/app_harness.dart';
import '../../../support/onboarding_steps.dart' show pumpUntil;
import '../../../support/schedule_test_server.dart';

final _ko = AppLocalizationsKo();

final Finder _screen = find.byKey(const ValueKey(ScreenIds.eventEdit));
final Finder _save = find.byKey(EventEditScreen.saveKey);
final Finder _delete = find.byKey(EventEditScreen.deleteKey);

Finder _richText(String text) => find.text(text, findRichText: true);

Finder _id(String identifier) => find.bySemanticsIdentifier(identifier);

Finder _editableIn(String slotId) => find.descendant(
  of: find.byKey(ValueKey(slotId)),
  matching: find.byType(EditableText),
);

/// 2026-10-13 09:07 시각 일정(memo 있음).
Schedule _morning() => Schedule.fromJson(memberSchedules()[1]);

/// member 시나리오로 앱을 띄우고 event-edit을 엽니다. [extra]가 있으면 수정 모드입니다.
Future<ProviderContainer> _open(
  WidgetTester tester, {
  String? location,
  Schedule? extra,
  List<Override> overrides = const [],
  bool allowOngoing = false,
}) async {
  final container = await pumpApp(
    tester,
    scenario: 'member',
    overrides: overrides,
  );
  final target =
      location ?? datedPathOf(ScreenIds.eventEdit, CalendarDate(2026, 10, 20));
  unawaited(container.read(routerProvider).push<void>(target, extra: extra));
  await settleWithIo(tester, allowOngoing: allowOngoing);
  if (!allowOngoing) {
    await _waitCharacterLine(tester);
  }
  return container;
}

/// 그날 성격 한 줄이 그려질 때까지 기다립니다(달 길흉 응답은 실제 I/O로 옵니다).
Future<void> _waitCharacterLine(WidgetTester tester) => pumpUntil(
  tester,
  () => find
      .descendant(
        of: find.byKey(const ValueKey(SlotIds.eventEditCharacterHint)),
        matching: find.byType(RenderedTextView),
      )
      .evaluate()
      .isNotEmpty,
);

/// 떠 있는 toast가 저절로 사라지게 시간을 보냅니다(테스트 끝에 timer가 남지 않게).
Future<void> _dismissToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(seconds: 1));
}

/// [server]로 일정 저장소를 바꾸는 override.
Override _repositoryOf(ScheduleTestServer server) => scheduleRepositoryProvider
    .overrideWithValue(ScheduleRepository(server.client()));

/// 오프라인 배너가 보이는지(배너는 늘 있고 `present`로 나타나고 사라집니다).
bool _bannerShown(WidgetTester tester) =>
    tester.widget<NoticeBanner>(find.byType(NoticeBanner)).present;

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<PrimaryButton>(_save).onPressed != null;

String _path(ProviderContainer container) =>
    container.read(routerProvider).routerDelegate.currentConfiguration.uri.path;

/// 수정 모드에서 일정 지우기 → 확인 창의 지우기를 누릅니다.
Future<void> _confirmDelete(WidgetTester tester) async {
  await tester.ensureVisible(_delete);
  await tester.tap(_delete);
  await settleWithIo(tester);
  await tester.tap(find.text(_ko.eventEditDeleteConfirmDelete));
  await settleWithIo(tester);
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.ensureVisible(_save);
  await tester.tap(_save);
  await settleWithIo(tester);
}

void main() {
  setUpAll(ensureTimeZonesInitialized);

  testWidgets('새 일정: 제목·그날 성격 한 줄·입력칸이 보이고 제목이 비면 저장이 꺼집니다', (tester) async {
    await _open(tester);

    expect(_screen, findsOneWidget);
    expect(_id(ScreenIds.eventEdit), findsOneWidget);
    expect(find.text(_ko.eventEditBarTitle), findsOneWidget);
    await expectAppBarTitle(
      tester,
      SlotIds.eventEditBarTitle,
      _ko.eventEditBarTitle,
    );
    expect(_id(SlotIds.eventEditCharacterHint), findsOneWidget);
    expect(_richText('큰 기복 없이 평소 흐름대로 지내기 좋은 날이에요.'), findsOneWidget);
    expect(_id(SlotIds.eventEditTitleHint), findsOneWidget);
    expect(_id(SlotIds.eventEditMemoHint), findsOneWidget);

    final picker = tester.widget<BirthDatePicker>(find.byType(BirthDatePicker));
    expect(picker.variant, DatePickerVariant.solar);
    expect(
      picker.value,
      const BirthDateValue(
        calendar: BirthCalendar.solar,
        year: 2026,
        month: 10,
        day: 20,
      ),
    );
    expect(find.byType(Segmented<bool>), findsOneWidget);
    // 새 일정은 하루 종일로 시작해 시각 휠이 없습니다.
    expect(find.byType(TimePicker), findsNothing);
    expect(_delete, findsNothing);
    expect(_saveEnabled(tester), isFalse);

    await tester.enterText(_editableIn(SlotIds.eventEditTitleHint), '   ');
    await tester.pump();
    expect(_saveEnabled(tester), isFalse, reason: '공백뿐인 제목은 비어 있음');

    await tester.enterText(_editableIn(SlotIds.eventEditTitleHint), '산책');
    await tester.pump();
    expect(_saveEnabled(tester), isTrue);
  });

  testWidgets('날짜가 없으면 오늘(2026-10-13)의 새 일정입니다', (tester) async {
    await _open(tester, location: '/event-edit');
    final picker = tester.widget<BirthDatePicker>(find.byType(BirthDatePicker));
    expect(
      (picker.value.year, picker.value.month, picker.value.day),
      (2026, 10, 13),
    );
    expect(_richText('내게 필요한 기운이 들어와 일이 잘 풀리기 쉬운 날이에요.'), findsOneWidget);
  });

  testWidgets('날짜를 바꾸면 그날 성격 한 줄도 그 날로 바뀝니다', (tester) async {
    await _open(tester);
    tester
        .widget<BirthDatePicker>(find.byType(BirthDatePicker))
        .onChanged(
          const BirthDateValue(
            calendar: BirthCalendar.solar,
            year: 2026,
            month: 10,
            day: 21,
          ),
        );
    await _waitCharacterLine(tester);
    expect(_richText('기운이 엇갈리기 쉬워 한 박자 쉬어 가면 좋은 날이에요.'), findsOneWidget);
    expect(_richText('큰 기복 없이 평소 흐름대로 지내기 좋은 날이에요.'), findsNothing);
  });

  testWidgets('그날 성격을 기다리는 동안 skeleton입니다(loading)', (tester) async {
    covers(const Covers(states: ['event-edit:loading']));
    final pending = Completer<Calendar>();
    await _open(
      tester,
      overrides: [
        calendarMonthProvider.overrideWith((ref, month) => pending.future),
      ],
      allowOngoing: true,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey(SlotIds.eventEditCharacterHint)),
        matching: find.byType(SkeletonBlock),
      ),
      findsOneWidget,
    );
    // 성격을 기다려도 입력과 저장은 막지 않습니다.
    expect(_id(SlotIds.eventEditTitleHint), findsOneWidget);
  });

  testWidgets('시간 지정을 고르면 5분 휠이 나오고 그 시각으로 만듭니다', (tester) async {
    final server = ScheduleTestServer();
    final container = await _open(tester, overrides: [_repositoryOf(server)]);
    await tester.enterText(_editableIn(SlotIds.eventEditTitleHint), '산책');
    tester.widget<Segmented<bool>>(find.byType(Segmented<bool>)).onChanged!(
      false,
    );
    await settleWithIo(tester);
    final picker = tester.widget<TimePicker>(find.byType(TimePicker));
    expect(picker.variant, TimePickerVariant.notify);
    expect(picker.value, const TimeOfDay(hour: 9, minute: 0));
    picker.onChanged(const TimeOfDay(hour: 18, minute: 30));
    await tester.pump();
    await tester.enterText(_editableIn(SlotIds.eventEditMemoHint), '공원');
    await tester.pump();

    await _tapSave(tester);

    final posts = server.requestsOf('POST', '/v1/schedules');
    expect(posts, hasLength(1));
    expect(jsonDecode(posts.single.data as String), {
      'date': '2026-10-20',
      'allDay': false,
      'time': '18:30',
      'title': '산책',
      'memo': '공원',
    });
    expect(_screen, findsNothing, reason: '저장하면 닫힘');
    expect(container.read(scheduleEditorProvider), isFalse);
  });

  testWidgets('수정: 불러온 값을 채우고 시각은 아래로 맞춰 보이며, 바꾼 필드만 보냅니다 (A36)', (
    tester,
  ) async {
    final server = ScheduleTestServer();
    await _open(
      tester,
      location: '/event-edit',
      extra: _morning(),
      overrides: [_repositoryOf(server)],
    );
    expect(find.text('팀 주간 회의'), findsOneWidget);
    expect(find.text('안건 정리'), findsOneWidget);
    expect(
      tester.widget<TimePicker>(find.byType(TimePicker)).value,
      const TimeOfDay(hour: 9, minute: 5),
    );
    expect(_delete, findsOneWidget);

    await tester.enterText(_editableIn(SlotIds.eventEditTitleHint), '팀 회의');
    await tester.pump();
    await _tapSave(tester);

    final patches = server.requestsOf('PATCH', '/v1/schedules/morning');
    expect(jsonDecode(patches.single.data as String), {'title': '팀 회의'});
    expect(_screen, findsNothing);
  });

  testWidgets('저장이 연결 오류면 배너를 보이고 입력을 지키며 다시 누를 수 있습니다(offline)', (
    tester,
  ) async {
    covers(const Covers(states: ['event-edit:offline'], decisions: ['D47']));
    final server = ScheduleTestServer()..offline = true;
    await _open(tester, overrides: [_repositoryOf(server)]);
    expect(_bannerShown(tester), isFalse);
    await tester.enterText(_editableIn(SlotIds.eventEditTitleHint), '산책');
    await tester.pump();

    await _tapSave(tester);

    expect(_screen, findsOneWidget);
    expect(_bannerShown(tester), isTrue);
    expect(
      tester.widget<NoticeBanner>(find.byType(NoticeBanner)).variant,
      NoticeBannerVariant.offline,
    );
    expect(find.text(_ko.eventEditOfflineNotice), findsWidgets);
    expect(find.text('산책'), findsOneWidget);
    expect(_saveEnabled(tester), isTrue);

    server.offline = false;
    await _tapSave(tester);
    expect(server.requestsOf('POST', '/v1/schedules'), hasLength(1));
    expect(_screen, findsNothing);
  });

  testWidgets('그 밖의 저장 실패는 toast를 띄우고 화면에 남습니다(error)', (tester) async {
    covers(const Covers(states: ['event-edit:error']));
    final server = ScheduleTestServer()..writeFailureStatus = 503;
    await _open(tester, overrides: [_repositoryOf(server)]);
    await tester.enterText(_editableIn(SlotIds.eventEditTitleHint), '산책');
    await tester.pump();

    await _tapSave(tester);

    expect(find.text(_ko.eventEditSaveFailed), findsOneWidget);
    expect(_screen, findsOneWidget);
    expect(find.text('산책'), findsOneWidget);
    expect(_bannerShown(tester), isFalse);
    expect(_saveEnabled(tester), isTrue);
    await _dismissToast(tester);
  });

  testWidgets('수정 모드 "일정 지우기": destructive 확인 창 뒤 지우고 닫힙니다', (tester) async {
    final server = ScheduleTestServer();
    await _open(
      tester,
      location: '/event-edit',
      extra: _morning(),
      overrides: [_repositoryOf(server)],
    );
    await tester.ensureVisible(_delete);
    await tester.tap(_delete);
    await settleWithIo(tester);
    expect(_id(SlotIds.eventEditDeleteConfirm), findsOneWidget);
    expect(find.text(_ko.eventEditDeleteConfirm), findsOneWidget);

    // 취소하면 지우지 않습니다.
    await tester.tap(find.text(_ko.eventEditDeleteConfirmCancel));
    await settleWithIo(tester);
    expect(server.requestsOf('DELETE', '/v1/schedules'), isEmpty);
    expect(_screen, findsOneWidget);

    await tester.tap(_delete);
    await settleWithIo(tester);
    await tester.tap(find.text(_ko.eventEditDeleteConfirmDelete));
    await settleWithIo(tester);
    expect(server.requestsOf('DELETE', '/v1/schedules/morning'), hasLength(1));
    expect(_screen, findsNothing);
  });

  testWidgets('이미 없는 일정(404)이면 닫고 일반 오류 toast를 띄웁니다 (A41)', (tester) async {
    final server = ScheduleTestServer();
    await _open(
      tester,
      location: '/event-edit',
      extra: _morning(),
      overrides: [_repositoryOf(server)],
    );
    server.store.delete('morning');
    await tester.enterText(_editableIn(SlotIds.eventEditTitleHint), '팀 회의');
    await tester.pump();

    await _tapSave(tester);

    expect(_screen, findsNothing);
    expect(find.text(_ko.errorUnexpected), findsOneWidget);
    await _dismissToast(tester);
  });

  testWidgets('삭제가 이미 없는 일정(404)이면 닫고 일반 오류 toast를 띄웁니다 (A41)', (tester) async {
    final server = ScheduleTestServer();
    await _open(
      tester,
      location: '/event-edit',
      extra: _morning(),
      overrides: [_repositoryOf(server)],
    );
    server.store.delete('morning');
    await tester.ensureVisible(_delete);
    await tester.tap(_delete);
    await settleWithIo(tester);
    await tester.tap(find.text(_ko.eventEditDeleteConfirmDelete));
    // 확인 창이 닫히고 화면이 닫히는 움직임까지 기다리면 toast가 사라지므로, 응답이 와서
    // toast가 뜨는 때를 바로 봅니다.
    for (
      var i = 0;
      i < 100 && find.text(_ko.errorUnexpected).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text(_ko.errorUnexpected), findsOneWidget);
    await settleWithIo(tester);
    expect(server.requestsOf('DELETE', '/v1/schedules/morning'), hasLength(1));
    expect(_screen, findsNothing);
    await _dismissToast(tester);
  });

  testWidgets('삭제가 연결 오류면 오프라인 배너를 보이고 화면에 남습니다', (tester) async {
    final server = ScheduleTestServer();
    await _open(
      tester,
      location: '/event-edit',
      extra: _morning(),
      overrides: [_repositoryOf(server)],
    );
    server.offline = true;

    await _confirmDelete(tester);

    expect(_screen, findsOneWidget);
    expect(_bannerShown(tester), isTrue);
    expect(find.text('팀 주간 회의'), findsOneWidget);
  });

  testWidgets('스택 바닥에서 열었으면 저장한 뒤 달력 탭으로 갑니다', (tester) async {
    final server = ScheduleTestServer();
    final container = await pumpApp(
      tester,
      scenario: 'member',
      overrides: [_repositoryOf(server)],
    );
    container
        .read(routerProvider)
        .go(datedPathOf(ScreenIds.eventEdit, CalendarDate(2026, 10, 20)));
    await settleWithIo(tester);
    await _waitCharacterLine(tester);
    expect(find.byKey(const ValueKey('app-bar.back')), findsNothing);
    await tester.enterText(_editableIn(SlotIds.eventEditTitleHint), '산책');
    await tester.pump();

    await _tapSave(tester);

    expect(server.requestsOf('POST', '/v1/schedules'), hasLength(1));
    expect(_screen, findsNothing);
    expect(_path(container), '/calendar');
  });

  testWidgets('시각 → 하루 종일 → 시각으로 되돌리면 PATCH에 time이 없습니다 (A36)', (tester) async {
    final server = ScheduleTestServer();
    await _open(
      tester,
      location: '/event-edit',
      extra: _morning(),
      overrides: [_repositoryOf(server)],
    );
    final segmented = find.byType(Segmented<bool>);
    tester.widget<Segmented<bool>>(segmented).onChanged!(true);
    await tester.pump();
    expect(find.byType(TimePicker), findsNothing);
    tester.widget<Segmented<bool>>(segmented).onChanged!(false);
    await tester.pump();
    expect(
      tester.widget<TimePicker>(find.byType(TimePicker)).value,
      const TimeOfDay(hour: 9, minute: 5),
    );
    await tester.enterText(_editableIn(SlotIds.eventEditTitleHint), '팀 회의');
    await tester.pump();

    await _tapSave(tester);

    final patches = server.requestsOf('PATCH', '/v1/schedules/morning');
    expect(jsonDecode(patches.single.data as String), {'title': '팀 회의'});
  });

  testWidgets('아무것도 바꾸지 않고 저장하면 요청 없이 닫힙니다', (tester) async {
    final server = ScheduleTestServer();
    await _open(
      tester,
      location: '/event-edit',
      extra: _morning(),
      overrides: [_repositoryOf(server)],
    );

    await _tapSave(tester);

    expect(server.requestsOf('PATCH', '/v1/schedules'), isEmpty);
    expect(_screen, findsNothing);
  });

  testWidgets('저장 중에는 두 번 눌러도 POST 1건이고 휠·뒤로 가기가 막힙니다', (tester) async {
    final server = ScheduleTestServer()..hold = Completer<void>();
    await _open(tester, overrides: [_repositoryOf(server)]);
    await tester.enterText(_editableIn(SlotIds.eventEditTitleHint), '산책');
    tester.widget<Segmented<bool>>(find.byType(Segmented<bool>)).onChanged!(
      false,
    );
    await tester.pump();
    await tester.ensureVisible(_save);
    await tester.tap(_save);
    await tester.pump();
    // 처리 중 버튼은 눌림을 받지 않으므로 콜백을 직접 다시 부릅니다(두 번 누름 흉내).
    await tester.tap(_save, warnIfMissed: false);
    tester.widget<PrimaryButton>(_save).onPressed?.call();
    await tester.pump();

    bool ignoring(Key key) =>
        tester.widget<IgnorePointer>(find.byKey(key)).ignoring;
    expect(ignoring(EventEditScreen.dateWheelsKey), isTrue);
    expect(ignoring(EventEditScreen.timeWheelsKey), isTrue);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(_screen, findsOneWidget, reason: '저장 중 뒤로 가기는 막힘');

    server.hold!.complete();
    await settleWithIo(tester);
    expect(server.requestsOf('POST', '/v1/schedules'), hasLength(1));
    expect(_screen, findsNothing);
  });

  testWidgets('제목 칸에서 완료를 누르면 키보드만 내리고 저장하지 않습니다', (tester) async {
    final server = ScheduleTestServer();
    await _open(tester, overrides: [_repositoryOf(server)]);
    await tester.enterText(_editableIn(SlotIds.eventEditTitleHint), '산책');
    await tester.pump();
    final editable = tester.state<EditableTextState>(
      _editableIn(SlotIds.eventEditTitleHint),
    );
    expect(editable.widget.focusNode.hasFocus, isTrue);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(editable.widget.focusNode.hasFocus, isFalse);
    // 아래 깔린 today가 오늘 일정 줄로 받는 GET은 정상입니다. 쓰기 요청만 없어야 합니다.
    expect(
      server.requests.where((request) => request.method != 'GET'),
      isEmpty,
    );
    expect(_screen, findsOneWidget);
  });

  testWidgets('메모는 여러 줄이고 공백뿐이면 메모 없이 만듭니다', (tester) async {
    final server = ScheduleTestServer();
    await _open(tester, overrides: [_repositoryOf(server)]);
    final memo = tester.widget<MyungliTextField>(
      find.byKey(const ValueKey(SlotIds.eventEditMemoHint)),
    );
    expect(memo.maxLines, MyungliTextField.maxLinesLimit);
    await tester.enterText(_editableIn(SlotIds.eventEditTitleHint), '산책');
    await tester.enterText(_editableIn(SlotIds.eventEditMemoHint), '  \n ');
    await tester.pump();

    await _tapSave(tester);

    final posts = server.requestsOf('POST', '/v1/schedules');
    expect(jsonDecode(posts.single.data as String), {
      'date': '2026-10-20',
      'allDay': true,
      'title': '산책',
    });
  });
}
