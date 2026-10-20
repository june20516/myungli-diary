import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/app_error.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/calendar_type.dart';
import 'package:myungli_diary/core/api/gen/model/lunar_or_solar_date.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_en.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/device_locale.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/input/date_picker.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/design/components/input/time_picker.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_completer.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_finish.dart';
import 'package:myungli_diary/features/onboarding/application/onboarding_providers.dart';
import 'package:myungli_diary/features/onboarding/data/onboarding_draft_store.dart';
import 'package:myungli_diary/features/onboarding/model/onboarding_draft.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboard_birth_screen.dart';
import 'package:myungli_diary/features/onboarding/presentation/onboarding_step_mode.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_bar_title.dart';
import '../support/app_harness.dart';
import '../support/onboarding_steps.dart';

final _ko = AppLocalizationsKo();
final _en = AppLocalizationsEn();

PrimaryButton _next(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byType(PrimaryButton));

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

/// 가운데 칸 기준 휠을 [steps]칸 내립니다(한 칸 40px).
Future<void> _dragWheel(WidgetTester tester, Key key, int steps) async {
  await tester.drag(find.byKey(key), Offset(0, -40.0 * steps));
  await tester.pumpAndSettle();
}

const Locale _usa = Locale('en', 'US');

/// 오전·오후 휠을 [meridiemSteps]칸, 시 휠을 [hourSteps]칸 내립니다. 휠이 멈춘 뒤 요청이 나갑니다.
Future<void> _pickTime(
  WidgetTester tester, {
  required int hourSteps,
  int meridiemSteps = 0,
}) async {
  if (meridiemSteps != 0) {
    await _dragWheel(tester, TimePicker.meridiemWheelKey, meridiemSteps);
  }
  await _dragWheel(tester, TimePicker.hourWheelKey, hourSteps);
  // 휠이 멈춘 뒤(debounce) 요청이 나갑니다. 가짜 시계를 넘기고 fixture I/O를 기다립니다.
  await tester.pump(const Duration(seconds: 1));
  await settleIo(tester);
}

/// 열린 직후 debounce가 지나고 fixture I/O가 끝나기를 기다립니다.
Future<void> _settleConfirm(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  // 설치 id·manifest·fixture를 차례로 읽으므로 실제 I/O와 프레임을 몇 번 번갈아 돕니다.
  for (var i = 0; i < 5; i++) {
    await settleIo(tester);
  }
}

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

Map<String, Object?> _bodyOf(Object? data) =>
    (data is String ? jsonDecode(data) : data)! as Map<String, Object?>;

void main() {
  testWidgets('onboard-call: 빈 호칭은 막고 10자까지만 받으며 다음에서 호칭을 저장합니다', (
    tester,
  ) async {
    covers(
      const Covers(exits: ['onboard-call>onboard-birth'], decisions: ['D50']),
    );
    final container = await _openCall(tester);
    expect(find.byKey(const ValueKey(ScreenIds.onboardCall)), findsOneWidget);
    await expectAppBarTitle(
      tester,
      SlotIds.onboardCallBarTitle,
      _ko.onboardCallBarTitle,
    );
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
    await tapNext(tester);

    expect(find.byKey(const ValueKey(ScreenIds.onboardBirth)), findsOneWidget);
    await expectAppBarTitle(
      tester,
      SlotIds.onboardBirthBarTitle,
      _ko.onboardBirthBarTitle,
    );
    expect(await _savedHonorific(tester, container), '별님');
  });

  testWidgets('onboard-birth: 1990-05-17 양력 다음 → onboard-time, 뒤로 오면 값이 남습니다', (
    tester,
  ) async {
    covers(const Covers(exits: ['onboard-birth>onboard-time']));
    final container = await _openCall(tester);
    await tester.enterText(find.byType(EditableText), '별님');
    await tester.pump();
    await tapNext(tester);

    // 기본값 1990-03-15에서 두 칸씩 돌려 5월 17일로 갑니다.
    await _dragWheel(tester, BirthDatePicker.monthWheelKey, 2);
    await _dragWheel(tester, BirthDatePicker.dayWheelKey, 2);
    await tapNext(tester);
    expect(find.byKey(const ValueKey(ScreenIds.onboardTime)), findsOneWidget);
    await expectAppBarTitle(
      tester,
      SlotIds.onboardTimeBarTitle,
      _ko.onboardTimeBarTitle,
    );

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
    await tapNext(tester);
    await settleIo(tester);

    container.invalidate(onboardingDraftProvider);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await settleIo(tester);
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
    // 한국어 문구로 확인하므로 프로필 언어가 ko인 회원입니다(member-overseas는 en, A60).
    final container = await pumpApp(tester, scenario: 'member');
    final router = container.read(routerProvider);

    String? result;
    unawaited(
      router
          .push<String>('${pathOf(ScreenIds.onboardCall)}?mode=edit')
          .then((value) => result = value),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(ScreenIds.onboardCall)), findsOneWidget);
    expect(find.text(_ko.onboardingSave), findsOneWidget);
    expect(find.text(_ko.onboardingNext), findsNothing);

    await tester.enterText(find.byType(EditableText), '달님');
    await tester.pump();
    await tapNext(tester);
    expect(result, '달님');
    expect(await _savedHonorific(tester, container), isNull);

    BirthDateValue? birth;
    unawaited(
      router
          .push<BirthDateValue>('${pathOf(ScreenIds.onboardBirth)}?mode=edit')
          .then((value) => birth = value),
    );
    await tester.pumpAndSettle();
    expect(find.text(_ko.onboardingSave), findsOneWidget);
    await _dragWheel(tester, BirthDatePicker.dayWheelKey, 1);
    await tapNext(tester);
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
      await settleIo(tester);
      expect(fieldText(tester), '하늘');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      unawaited(
        router.push<BirthDateValue>(
          '${pathOf(ScreenIds.onboardBirth)}?mode=edit',
        ),
      );
      await settleIo(tester);
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
      await settleIo(tester);
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
    expect(find.bySemanticsLabel(_ko.onboardCallQuestionHead), findsOneWidget);
    // 칸 이름은 목적만 말하고, 예시 문구와 같지 않습니다.
    final field = tester.getSemantics(find.byType(EditableText));
    // 칸 이름 뒤에 예시가 hint로 한 번만 이어집니다.
    expect(
      field.label,
      '${_ko.onboardCallInputLabel}\n${_ko.onboardCallInputHint}',
    );
    handle.dispose();
  });

  test('호칭 칸 이름과 예시는 세 언어 모두 다른 문구입니다', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      expect(l10n.onboardCallInputLabel, isNot(l10n.onboardCallInputHint));
    }
  });

  group('onboard-time', () {
    testWidgets('04:00이면 인시 확인 줄이 보이고 요청은 휠이 멈춘 뒤 한 번이며, 모름은 3주 안내입니다', (
      tester,
    ) async {
      covers(
        const Covers(
          exits: ['onboard-time>onboard-gender'],
          states: ['onboard-time:time-unknown'],
          decisions: ['D58'],
        ),
      );
      final container = await openTimeStep(tester);
      final fake = _fake(container);
      // 열자마자 기본 12:00으로 한 번 묻습니다.
      await _settleConfirm(tester);
      expect(
        find.byKey(const ValueKey(SlotIds.onboardTimeHourConfirm)),
        findsOneWidget,
      );
      expect(fake.callCountOf('getBirthHour'), 1);
      // 기본 12:00(오후)에서 오전 4시로: 오전·오후 한 칸, 시 4칸.
      await _pickTime(tester, hourSteps: 4, meridiemSteps: -1);

      expect(
        // 원고 틀이 '시'를 붙이므로 지지 이름에는 '시'가 없어야 합니다(D68).
        find.textContaining('인시, 03:30~05:30에 태어났어요.'),
        findsOneWidget,
      );
      expect(fake.callCountOf('getBirthHour'), 2);
      final body = _bodyOf(fake.requestBodiesOf('getBirthHour').last);
      expect(body['installationId'], isA<String>());
      expect((body['installationId']! as String).isNotEmpty, isTrue);
      expect(body['time'], '04:00');

      await tester.tap(find.text(_ko.timeUnknownLabel));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey(SlotIds.onboardTimeUnknownNote)),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey(SlotIds.onboardTimeHourConfirm)),
        findsNothing,
      );
      expect(fake.callCountOf('getBirthHour'), 2);

      await tapNext(tester);
      expect(
        find.byKey(const ValueKey(ScreenIds.onboardGender)),
        findsOneWidget,
      );
      await expectAppBarTitle(
        tester,
        SlotIds.onboardGenderBarTitle,
        _ko.onboardGenderBarTitle,
      );
      final draft = container.read(onboardingDraftProvider).value!;
      expect(draft.time!.status, BirthTimeStatusEnum.unknown);
      expect(draft.time!.value, isNull);
    });

    testWidgets('휠을 빠르게 여러 번 돌려도 멈춘 뒤 한 번만 묻고, 이동 중에는 이전 줄이 그대로입니다', (
      tester,
    ) async {
      final container = await openTimeStep(tester);
      await _settleConfirm(tester);
      final fake = _fake(container);
      expect(fake.callCountOf('getBirthHour'), 1);
      const lineKey = ValueKey(SlotIds.onboardTimeHourConfirm);
      final before = tester.getSize(find.byKey(lineKey));

      for (var i = 0; i < 3; i++) {
        await tester.drag(
          find.byKey(TimePicker.hourWheelKey),
          const Offset(0, -40),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      // 아직 멈추기 전: 요청도 없고 줄도 같은 자리에 그대로입니다.
      expect(fake.callCountOf('getBirthHour'), 1);
      expect(find.byKey(lineKey), findsOneWidget);
      expect(tester.getSize(find.byKey(lineKey)).height, before.height);

      await _settleConfirm(tester);
      expect(fake.callCountOf('getBirthHour'), 2);
      expect(find.byKey(lineKey), findsOneWidget);
    });

    testWidgets('본 적 있는 시각으로 되돌리면 다시 묻지 않습니다', (tester) async {
      final container = await openTimeStep(tester);
      await _settleConfirm(tester);
      final fake = _fake(container);
      await _pickTime(tester, hourSteps: 1);
      expect(fake.callCountOf('getBirthHour'), 2);
      await _pickTime(tester, hourSteps: -1);
      expect(fake.callCountOf('getBirthHour'), 2);
      expect(
        find.byKey(const ValueKey(SlotIds.onboardTimeHourConfirm)),
        findsOneWidget,
      );
    });

    testWidgets('429(rate_limited)여도 줄 없이 입력을 이어 갑니다', (tester) async {
      final container = await openTimeStep(
        tester,
        scenario: 'birth-hour-rate-limited',
      );
      await _settleConfirm(tester);
      await _pickTime(tester, hourSteps: 1);
      expect(_fake(container).callCountOf('getBirthHour'), 2);
      expect(
        find.byKey(const ValueKey(SlotIds.onboardTimeHourConfirm)),
        findsNothing,
      );
      await tapNext(tester);
      expect(
        find.byKey(const ValueKey(ScreenIds.onboardGender)),
        findsOneWidget,
      );
    });

    testWidgets('시진 확인이 실패(503)해도 줄 없이 다음으로 갑니다', (tester) async {
      final container = await openTimeStep(
        tester,
        scenario: 'birth-hour-unavailable',
      );
      await _pickTime(tester, hourSteps: 4, meridiemSteps: -1);

      expect(_fake(container).callCountOf('getBirthHour'), 2);
      expect(
        find.byKey(const ValueKey(SlotIds.onboardTimeHourConfirm)),
        findsNothing,
      );
      await tapNext(tester);
      expect(
        find.byKey(const ValueKey(ScreenIds.onboardGender)),
        findsOneWidget,
      );
      expect(
        container.read(onboardingDraftProvider).value!.time,
        BirthTime(status: BirthTimeStatusEnum.known, value: '04:00'),
      );
    });

    testWidgets('overseas 시나리오는 확인 줄을 요청하지도 그리지도 않습니다', (tester) async {
      final container = await openTimeStep(
        tester,
        scenario: 'overseas',
        locale: _usa,
      );
      await _pickTime(tester, hourSteps: 4, meridiemSteps: -1);

      expect(_fake(container).callCountOf('getBirthHour'), 0);
      expect(
        find.byKey(const ValueKey(SlotIds.onboardTimeHourConfirm)),
        findsNothing,
      );
    });

    testWidgets('시나리오 locale이 기기 로케일이 됩니다(override 없을 때)', (tester) async {
      final container = await pumpApp(
        tester,
        scenario: 'overseas',
        locale: null,
      );
      expect(container.read(localeProvider), const Locale('en', 'US'));
      expect(container.read(deviceRegionIsKoreaProvider), isFalse);
    });
  });

  group('onboard-gender', () {
    Future<void> openGender(WidgetTester tester) async {
      await tapNext(tester);
      expect(
        find.byKey(const ValueKey(ScreenIds.onboardGender)),
        findsOneWidget,
      );
    }

    testWidgets('고르기 전에는 다음이 꺼져 있고, 한국 기기는 다음 → preview입니다', (tester) async {
      covers(
        const Covers(exits: ['onboard-gender>preview'], decisions: ['D29']),
      );
      final container = await openTimeStep(tester);
      await openGender(tester);
      expect(_next(tester).onPressed, isNull);

      await tester.tap(find.text(_ko.genderFemale));
      await tester.pumpAndSettle();
      expect(_next(tester).onPressed, isNotNull);
      await tapNext(tester);

      expect(find.byKey(const ValueKey(ScreenIds.preview)), findsOneWidget);
      await expectAppBarTitle(
        tester,
        SlotIds.previewBarTitle,
        _ko.previewBarTitle,
      );
      expect(
        container.read(onboardingDraftProvider).value!.gender,
        BirthGenderEnum.female,
      );
    });

    testWidgets('한국 밖 기기는 다음 → birthplace입니다', (tester) async {
      covers(
        const Covers(exits: ['onboard-gender>birthplace'], decisions: ['D29']),
      );
      await openTimeStep(tester, scenario: 'overseas', locale: _usa);
      await openGender(tester);
      await tester.tap(find.text(_en.genderMale));
      await tester.pumpAndSettle();
      await tapNext(tester);
      expect(find.byKey(const ValueKey(ScreenIds.birthplace)), findsOneWidget);
      await expectAppBarTitle(
        tester,
        SlotIds.birthplaceBarTitle,
        _en.birthplaceBarTitle,
      );
    });

    testWidgets('세션이 있으면 미리보기를 건너뛰고 마무리 동작을 부릅니다', (tester) async {
      var finished = 0;
      await openTimeStep(
        tester,
        scenario: 'profile-required',
        overrides: [
          onboardingFinishProvider.overrideWithValue(() async => finished++),
        ],
      );
      await openGender(tester);
      await tester.tap(find.text(_ko.genderMale));
      await tester.pumpAndSettle();
      await tapNext(tester);

      expect(finished, 1);
      expect(find.byKey(const ValueKey(ScreenIds.preview)), findsNothing);
      expect(
        find.byKey(const ValueKey(ScreenIds.onboardGender)),
        findsOneWidget,
      );
    });

    testWidgets('마무리 동작이 입력 오류면 onboard-call로 돌아가 그 문구를 toast로 보입니다', (
      tester,
    ) async {
      await openTimeStep(
        tester,
        scenario: 'profile-required',
        overrides: [
          onboardingFinishProvider.overrideWithValue(
            () async => throw const OnboardingInputRejected(
              ProblemError(
                code: 'birth.invalid',
                status: 422,
                fieldErrors: [],
                traceId: '',
              ),
            ),
          ),
        ],
      );
      await openGender(tester);
      await tester.tap(find.text(_ko.genderMale));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpAndSettle();

      // 입력 오류는 첫 단계부터 고칩니다(약관 동의 직후 저장과 같은 동작). 생년월일 오류라
      // 호칭 칸이 아닌 toast입니다.
      expect(tester.takeException(), isNull);
      expect(find.text(_ko.errorBirthInvalid), findsOneWidget);
      expect(find.byKey(const ValueKey(ScreenIds.onboardGender)), findsNothing);
      expect(find.byKey(const ValueKey(ScreenIds.onboardCall)), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('마무리 동작이 도는 동안 다음을 다시 눌러도 한 번만 부릅니다', (tester) async {
      final gate = Completer<void>();
      var finished = 0;
      await openTimeStep(
        tester,
        scenario: 'profile-required',
        overrides: [
          onboardingFinishProvider.overrideWithValue(() {
            finished++;
            return gate.future;
          }),
        ],
      );
      await openGender(tester);
      await tester.tap(find.text(_ko.genderMale));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await tester.pump();
      expect(finished, 1);
      gate.complete();
      await tester.pumpAndSettle();
    });
  });

  testWidgets('수정 모드: onboard-time은 BirthTime, onboard-gender는 성별을 돌려줍니다', (
    tester,
  ) async {
    covers(
      const Covers(
        exits: ['onboard-time>profile-edit', 'onboard-gender>profile-edit'],
      ),
    );
    final container = await pumpApp(tester, scenario: 'member');
    final router = container.read(routerProvider);

    BirthTime? time;
    unawaited(
      router
          .push<BirthTime>(
            '${pathOf(ScreenIds.onboardTime)}?mode=edit',
            extra: BirthTime(status: BirthTimeStatusEnum.known, value: '09:30'),
          )
          .then((value) => time = value),
    );
    await tester.pumpAndSettle();
    expect(find.text(_ko.onboardingSave), findsOneWidget);
    final picker = tester.widget<TimePicker>(find.byType(TimePicker));
    expect(picker.value, const TimeOfDay(hour: 9, minute: 30));
    await _dragWheel(tester, TimePicker.hourWheelKey, 1);
    await tapNext(tester);
    expect(time, BirthTime(status: BirthTimeStatusEnum.known, value: '10:30'));

    BirthGenderEnum? gender;
    unawaited(
      router
          .push<BirthGenderEnum>(
            '${pathOf(ScreenIds.onboardGender)}?mode=edit',
            extra: BirthGenderEnum.male,
          )
          .then((value) => gender = value),
    );
    await tester.pumpAndSettle();
    final segmented = tester.widget<Segmented<BirthGenderEnum?>>(
      find.byType(Segmented<BirthGenderEnum?>),
    );
    expect(segmented.selected, BirthGenderEnum.male);
    await tester.tap(find.text(_ko.genderFemale));
    await tester.pumpAndSettle();
    await tapNext(tester);
    expect(gender, BirthGenderEnum.female);
    final draft = await tester.runAsync(
      () => container.read(onboardingDraftStoreProvider).read(),
    );
    expect(draft, isNull);
  });
}
