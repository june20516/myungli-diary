import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/input/date_picker.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft_store.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboard_birth_screen.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboarding_step_mode.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_harness.dart';

PrimaryButton _next(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byType(PrimaryButton));

Future<void> _tapNext(WidgetTester tester) async {
  await tester.tap(find.byType(PrimaryButton));
  await tester.pumpAndSettle();
}

/// welcome에서 시작하기를 눌러 onboard-call까지 갑니다.
Future<ProviderContainer> _openCall(WidgetTester tester) async {
  final container = await pumpApp(tester, scenario: 'new-user');
  await tester.tap(find.byKey(const ValueKey(SlotIds.welcomeCtaStart)));
  await tester.pumpAndSettle();
  return container;
}

/// 저장소에 쓴 값을 비동기 I/O로 읽습니다.
Future<String?> _savedHonorific(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final draft = await tester.runAsync(
    () => container.read(onboardingDraftStoreProvider).read(),
  );
  return draft?.honorific;
}

/// 파일 DB의 실제 I/O가 끝나도록 시계를 풀어 줍니다.
Future<void> _settleIo(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

/// 가운데 칸 기준 휠을 [steps]칸 내립니다(한 칸 40px).
Future<void> _dragWheel(WidgetTester tester, Key key, int steps) async {
  await tester.drag(find.byKey(key), Offset(0, -40.0 * steps));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('onboard-call: 빈 호칭은 막고 10자까지만 받으며 다음에서 호칭을 저장합니다', (
    tester,
  ) async {
    covers(
      const Covers(exits: ['onboard-call>onboard-birth'], decisions: ['D50']),
    );
    final container = await _openCall(tester);
    expect(find.byKey(const ValueKey(ScreenIds.onboardCall)), findsOneWidget);
    expect(_next(tester).onPressed, isNull);

    await tester.enterText(find.byType(EditableText), '가나다라마바사아자차카');
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '가나다라마바사아자차',
    );

    await tester.enterText(find.byType(EditableText), '별님');
    await tester.pump();
    expect(_next(tester).onPressed, isNotNull);
    await _tapNext(tester);

    expect(find.byKey(const ValueKey(ScreenIds.onboardBirth)), findsOneWidget);
    expect(await _savedHonorific(tester, container), '별님');
  });

  testWidgets('onboard-birth: 1990-05-17 양력 다음 → onboard-time, 뒤로 오면 값이 남습니다', (
    tester,
  ) async {
    covers(const Covers(exits: ['onboard-birth>onboard-time']));
    final container = await _openCall(tester);
    await tester.enterText(find.byType(EditableText), '별님');
    await tester.pump();
    await _tapNext(tester);

    // 기본값 1990-03-15에서 두 칸씩 돌려 5월 17일로 갑니다.
    await _dragWheel(tester, BirthDatePicker.monthWheelKey, 2);
    await _dragWheel(tester, BirthDatePicker.dayWheelKey, 2);
    await _tapNext(tester);
    expect(find.byKey(const ValueKey(ScreenIds.onboardTime)), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(ScreenIds.onboardBirth)), findsOneWidget);
    final draft = await tester.runAsync(
      () => container.read(onboardingDraftStoreProvider).read(),
    );
    expect(draft!.calendar, CalendarType.solar);
    expect(
      (draft.date!.year, draft.date!.month, draft.date!.day),
      (1990, 5, 17),
    );
    final picker = tester.widget<BirthDatePicker>(find.byType(BirthDatePicker));
    expect(
      (picker.value.year, picker.value.month, picker.value.day),
      (1990, 5, 17),
    );
  });

  testWidgets('입력 상태를 저장소에서 다시 읽어도 호칭이 채워져 있습니다', (tester) async {
    // fake 시나리오 bootstrap은 DB를 비우므로, 같은 DB에서 draft provider만 새로 만듭니다.
    final container = await _openCall(tester);
    await tester.enterText(find.byType(EditableText), '별님');
    await tester.pump();
    await _tapNext(tester);
    await _settleIo(tester);

    container.invalidate(onboardingDraftProvider);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await _settleIo(tester);
    expect(find.byKey(const ValueKey(ScreenIds.onboardCall)), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '별님',
    );
  });

  testWidgets('수정 모드: onboard-call은 저장 버튼으로 값을 돌려주고 초안은 그대로입니다', (
    tester,
  ) async {
    covers(
      const Covers(
        exits: ['onboard-call>profile-edit', 'onboard-birth>profile-edit'],
      ),
    );
    final container = await pumpApp(tester, scenario: 'member-overseas');
    final router = container.read(routerProvider);

    String? result;
    unawaited(
      router
          .push<String>('${pathOf(ScreenIds.onboardCall)}?mode=edit')
          .then((value) => result = value),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(ScreenIds.onboardCall)), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);
    expect(find.text('다음'), findsNothing);

    await tester.enterText(find.byType(EditableText), '달님');
    await tester.pump();
    await _tapNext(tester);
    expect(result, '달님');
    expect(await _savedHonorific(tester, container), isNull);

    BirthDateValue? birth;
    unawaited(
      router
          .push<BirthDateValue>('${pathOf(ScreenIds.onboardBirth)}?mode=edit')
          .then((value) => birth = value),
    );
    await tester.pumpAndSettle();
    expect(find.text('저장'), findsOneWidget);
    await _dragWheel(tester, BirthDatePicker.dayWheelKey, 1);
    await _tapNext(tester);
    expect(birth, isNotNull);
    expect(birth!.day, 16);
    final draft = await tester.runAsync(
      () => container.read(onboardingDraftStoreProvider).read(),
    );
    expect(draft, isNull);
  });

  testWidgets('온보딩 진행 단계 수는 한국 기기 4입니다', (tester) async {
    final korea = await pumpApp(
      tester,
      scenario: 'new-user',
      locale: const Locale('ko', 'KR'),
    );
    expect(korea.read(onboardingStepCountProvider), 4);
  });

  testWidgets('온보딩 진행 단계 수는 해외 기기 5입니다', (tester) async {
    final overseas = await pumpApp(
      tester,
      scenario: 'new-user',
      locale: const Locale('en', 'US'),
    );
    expect(overseas.read(onboardingStepCountProvider), 5);
  });

  group('수정 모드 시작 값', () {
    final profile = Profile.fromJson({
      'honorific': '하늘',
      'language': 'ko',
      'currentTimezone': 'Asia/Seoul',
      'birth': {
        'calendar': 'lunar',
        'date': {'year': 1988, 'month': 4, 'day': 9},
        'isLeapMonth': true,
        'time': {'status': 'unknown'},
        'gender': 'female',
        'timezone': 'Asia/Seoul',
        'place': {'status': 'not_asked'},
      },
      'notification': {'status': 'not_asked'},
    });

    String fieldText(WidgetTester tester) =>
        tester.widget<EditableText>(find.byType(EditableText)).controller.text;

    testWidgets('extra가 있으면 extra, 없고 사본이 있으면 사본 값으로 시작합니다', (tester) async {
      final container = await pumpApp(
        tester,
        scenario: 'member-overseas',
        overrides: [cachedProfileProvider.overrideWith((ref) async => profile)],
      );
      final router = container.read(routerProvider);
      final path = '${pathOf(ScreenIds.onboardCall)}?mode=edit';

      unawaited(router.push<String>(path, extra: '구름'));
      await tester.pumpAndSettle();
      expect(fieldText(tester), '구름');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      unawaited(router.push<String>(path));
      await _settleIo(tester);
      expect(fieldText(tester), '하늘');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      unawaited(
        router.push<BirthDateValue>(
          '${pathOf(ScreenIds.onboardBirth)}?mode=edit',
        ),
      );
      await _settleIo(tester);
      final picker = tester.widget<BirthDatePicker>(
        find.byType(BirthDatePicker),
      );
      expect(
        picker.value,
        const BirthDateValue(
          calendar: BirthCalendar.lunar,
          year: 1988,
          month: 4,
          day: 9,
          isLeapMonth: true,
        ),
      );
    });

    testWidgets('extra도 사본도 없으면 호칭은 빈 칸입니다', (tester) async {
      final container = await pumpApp(
        tester,
        scenario: 'member-overseas',
        overrides: [cachedProfileProvider.overrideWith((ref) async => null)],
      );
      unawaited(
        container
            .read(routerProvider)
            .push<String>('${pathOf(ScreenIds.onboardCall)}?mode=edit'),
      );
      await _settleIo(tester);
      expect(fieldText(tester), '');
    });
  });

  testWidgets('en 기기는 호칭을 20자까지 받습니다', (tester) async {
    await pumpApp(
      tester,
      scenario: 'new-user',
      locale: const Locale('en', 'US'),
    );
    await tester.tap(find.byKey(const ValueKey(SlotIds.welcomeCtaStart)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(EditableText),
      'abcdefghijklmnopqrstuvwxyz',
    );
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'abcdefghijklmnopqrst',
    );
  });

  test('음력 윤달 생일이 초안과 화면 값 사이를 왕복해도 같습니다', () {
    const value = BirthDateValue(
      calendar: BirthCalendar.lunar,
      year: 2001,
      month: 4,
      day: 30,
      isLeapMonth: true,
    );
    final draft = const OnboardingDraft().copyWith(
      calendar: CalendarType.lunar,
      date: LunarOrSolarDate(year: 2001, month: 4, day: 30),
      isLeapMonth: true,
    );
    expect(birthDateValueOfDraft(draft), value);
    final back = draftWithBirthDate(const OnboardingDraft(), value);
    expect(back.calendar, CalendarType.lunar);
    expect(back.isLeapMonth, isTrue);
    expect(back.date, LunarOrSolarDate(year: 2001, month: 4, day: 30));
    // 양력으로 바꾸면 윤달 표시가 꺼집니다.
    final solar = draftWithBirthDate(
      back,
      value.copyWith(calendar: BirthCalendar.solar),
    );
    expect(solar.calendar, CalendarType.solar);
    expect(solar.isLeapMonth, isFalse);
  });

  testWidgets('호칭 칸 이름이 질문과 겹쳐 두 번 읽히지 않습니다', (tester) async {
    final handle = tester.ensureSemantics();
    await _openCall(tester);
    expect(find.bySemanticsLabel('뭐라고 불러 드릴까요?'), findsOneWidget);
    // 칸 이름은 목적만 말하고, 예시 문구와 같지 않습니다.
    final field = tester.getSemantics(find.byType(EditableText));
    // 이름 '호칭' 뒤에 예시가 hint로 한 번만 이어집니다.
    expect(field.label, '호칭\n예: 별님');
    handle.dispose();
  });
}
