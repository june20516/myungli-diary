import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/gen/model/birth.dart';
import 'package:myungli_diary/core/api/gen/model/birth_time.dart';
import 'package:myungli_diary/core/api/gen/model/evidence_access.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/api/gen/model/profile.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_en.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/storage/app_database.dart';
import 'package:myungli_diary/core/storage/cache_store.dart';
import 'package:myungli_diary/core/storage/saju_fingerprint.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/action/settings_row.dart';
import 'package:myungli_diary/design/components/feedback/dialog.dart';
import 'package:myungli_diary/design/components/feedback/notice_banner.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/input/date_picker.dart';
import 'package:myungli_diary/features/me/presentation/settings_screen.dart';
import 'package:myungli_diary/features/me/presentation/settings_sheets.dart';
import 'package:myungli_diary/features/onboarding/model/time_step_edit.dart';
import 'package:myungli_diary/features/profile/application/profile_edit_controller.dart';
import 'package:myungli_diary/features/profile/application/profile_providers.dart';
import 'package:myungli_diary/features/profile/presentation/profile_edit_screen.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_bar_title.dart';
import '../support/app_harness.dart';
import '../support/onboarding_steps.dart';
import '../support/profile_network.dart';

final _ko = AppLocalizationsKo();
final _en = AppLocalizationsEn();

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

Map<String, Object?> _bodyOf(Object? data) =>
    (data is String ? jsonDecode(data) : data)! as Map<String, Object?>;

/// [field]를 바꾼 `updateProfile` 본문. 기기 시간대 동기화 요청은 거릅니다.
List<Map<String, Object?>> _patches(
  ProviderContainer container,
  String field,
) => [
  for (final body in _fake(container).requestBodiesOf('updateProfile'))
    if (_bodyOf(body).containsKey(field)) _bodyOf(body),
];

/// member 시나리오의 생일 글자(양력 1990-05-15).
String _birthLabel(int day, {String locale = 'ko', String? calendar}) =>
    '${calendar ?? _ko.calendarSolar} '
    '${DateFormat.yMMMMd(locale).format(DateTime(1990, 5, day))}';

String _timeLabel(int hour, int minute, {String locale = 'ko'}) =>
    DateFormat.jm(locale).format(DateTime(2000, 1, 1, hour, minute));

/// [scenario]로 앱을 띄우고 정보 수정을 엽니다. [network]는 앱 시작 뒤에 끼웁니다.
Future<ProviderContainer> _openProfileEdit(
  WidgetTester tester, {
  String scenario = 'member',
  Locale locale = const Locale('ko'),
  Interceptor? startNetwork,
  Interceptor? network,
}) async {
  final container = await pumpApp(
    tester,
    scenario: scenario,
    locale: locale,
    network: startNetwork,
  );
  if (network != null) {
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, network);
  }
  unawaited(
    container.read(routerProvider).push<void>(pathOf(ScreenIds.profileEdit)),
  );
  await pumpUntilScreen(tester, ScreenIds.profileEdit);
  await settleWithIo(tester);
  return container;
}

/// [screenId] 화면의 라우터 상태(경로·query·extra).
GoRouterState _stateOf(WidgetTester tester, String screenId) =>
    GoRouterState.of(tester.element(find.byKey(ValueKey(screenId))));

SettingsRow _row(WidgetTester tester, Key key) =>
    tester.widget<SettingsRow>(find.byKey(key));

/// 오류 배너. 숨은 동안은 높이가 0이라 목록이 offstage로 보므로 함께 찾습니다.
final Finder _banner = find.byKey(
  ProfileEditScreen.errorKey,
  skipOffstage: false,
);

PrimaryButton _saveButton(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byKey(ProfileEditScreen.saveKey));

Future<void> _tapRow(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await settleWithIo(tester);
}

/// 성별 줄을 눌러 [label] 성별을 골라 저장합니다.
Future<void> _changeGender(WidgetTester tester, String label) async {
  await _tapRow(tester, ProfileEditScreen.genderRowKey);
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  await tapNext(tester);
  await settleWithIo(tester);
}

/// 생일 줄을 눌러 일 휠을 한 칸 내려 저장합니다(15일 → 16일).
Future<void> _changeBirthDay(WidgetTester tester) async {
  await _tapRow(tester, ProfileEditScreen.birthRowKey);
  await tester.drag(
    find.byKey(BirthDatePicker.dayWheelKey),
    const Offset(0, -40),
  );
  await tester.pumpAndSettle();
  await tapNext(tester);
  await settleWithIo(tester);
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.byKey(ProfileEditScreen.saveKey));
  await settleWithIo(tester);
}

/// 사본의 사주 지문으로 사주 기반 캐시(달력·차트·그날)를 한 줄씩 심고 그 키를 돌려줍니다.
Future<List<(CacheKind, String)>> _seedSajuCaches(
  WidgetTester tester,
  ProviderContainer container,
) async => (await tester.runAsync(() async {
  final profile = (await container.read(cachedProfileProvider.future))!;
  final fingerprint = sajuFingerprint(profile);
  final keys = [
    (
      CacheKind.calendar,
      calendarKey(
        fingerprint: fingerprint,
        language: 'ko',
        year: 1999,
        month: 1,
      ),
    ),
    (
      CacheKind.chart,
      chartKey(fingerprint: fingerprint, language: 'ko', year: 1999),
    ),
    (
      CacheKind.daily,
      dailyKey(fingerprint: fingerprint, language: 'ko', date: '1999-01-01'),
    ),
  ];
  final cache = container.read(cacheStoreProvider);
  for (final (kind, key) in keys) {
    await cache.write(kind, key, '{}', access: EvidenceAccess.unlocked);
  }
  return keys;
}))!;

/// 심은 캐시 줄의 값(없으면 null).
Future<List<String?>> _readCaches(
  WidgetTester tester,
  ProviderContainer container,
  List<(CacheKind, String)> keys,
) async => (await tester.runAsync(
  () => Future.wait([
    for (final (kind, key) in keys)
      container.read(cacheStoreProvider).read(kind, key),
  ]),
))!;

void main() {
  testWidgets('제목과 줄마다 지금 값(사본), 저장 버튼은 꺼져 있습니다', (tester) async {
    covers(const Covers(decisions: ['D36', 'D39']));
    await _openProfileEdit(tester);
    await expectAppBarTitle(
      tester,
      SlotIds.profileEditBarTitle,
      _ko.profileEditBarTitle,
    );

    expect(find.byType(SettingsGroup), findsNWidgets(2));
    final rows = [
      for (final row in tester.widgetList<SettingsRow>(
        find.byType(SettingsRow),
      ))
        (row.label, row.value, row.variant),
    ];
    expect(rows, [
      (_ko.onboardCallBarTitle, '하늘', SettingsRowVariant.value),
      (_ko.onboardBirthBarTitle, _birthLabel(15), SettingsRowVariant.value),
      (_ko.onboardTimeBarTitle, _timeLabel(14, 30), SettingsRowVariant.value),
      (_ko.onboardGenderBarTitle, _ko.genderFemale, SettingsRowVariant.value),
      (
        _ko.birthplaceBarTitle,
        _ko.profileEditBirthplaceKorea,
        SettingsRowVariant.value,
      ),
    ]);
    expect(
      find.byKey(const ValueKey(SlotIds.profileEditRecalcNotice)),
      findsOneWidget,
    );
    expect(find.text(_ko.profileEditRecalcNotice), findsOneWidget);
    expect(_saveButton(tester).label, _ko.onboardingSave);
    expect(_saveButton(tester).onPressed, isNull);
    // 실패 전에는 오류 배너가 없습니다.
    expect(tester.widget<NoticeBanner>(_banner).present, isFalse);
  });

  testWidgets('줄을 누르면 그 입력 화면을 수정 모드로, extra는 지금 값입니다', (tester) async {
    covers(
      const Covers(
        exits: [
          'profile-edit>onboard-call',
          'profile-edit>onboard-birth',
          'profile-edit>onboard-time',
          'profile-edit>onboard-gender',
          'profile-edit>birthplace',
        ],
      ),
    );
    final container = await _openProfileEdit(tester);
    final cases = <(Key, String, Object?)>[
      (ProfileEditScreen.callRowKey, ScreenIds.onboardCall, '하늘'),
      (
        ProfileEditScreen.birthRowKey,
        ScreenIds.onboardBirth,
        const BirthDateValue(
          calendar: BirthCalendar.solar,
          year: 1990,
          month: 5,
          day: 15,
        ),
      ),
      (
        ProfileEditScreen.timeRowKey,
        ScreenIds.onboardTime,
        TimeStepEdit(
          time: BirthTime(status: BirthTimeStatusEnum.known, value: '14:30'),
          date: const BirthDateValue(
            calendar: BirthCalendar.solar,
            year: 1990,
            month: 5,
            day: 15,
          ),
        ),
      ),
      (
        ProfileEditScreen.genderRowKey,
        ScreenIds.onboardGender,
        BirthGenderEnum.female,
      ),
      // 사본의 출생지는 도시 이름을 다시 고르는 검색이라 넘길 값이 없습니다.
      (ProfileEditScreen.placeRowKey, ScreenIds.birthplace, null),
    ];
    for (final (key, screen, extra) in cases) {
      await _tapRow(tester, key);
      await pumpUntilScreen(tester, screen);
      final state = _stateOf(tester, screen);
      expect(state.uri.path, pathOf(screen), reason: screen);
      expect(state.uri.queryParameters['mode'], 'edit', reason: screen);
      expect(state.extra, extra, reason: screen);
      // 값 없이 돌아오면 아무것도 바뀌지 않습니다.
      Navigator.of(tester.element(find.byKey(ValueKey(screen)))).pop();
      await settleWithIo(tester);
      expect(find.byKey(const ValueKey(ScreenIds.profileEdit)), findsOneWidget);
    }
    expect(_saveButton(tester).onPressed, isNull);
    expect(_patches(container, 'birth'), isEmpty);
    expect(_patches(container, 'honorific'), isEmpty);
  });

  testWidgets('호칭만 바꾸면 확인 창 없이 바로 PATCH합니다(가벼운 변경)', (tester) async {
    final container = await _openProfileEdit(tester);
    await _tapRow(tester, ProfileEditScreen.callRowKey);
    await tester.enterText(find.byType(EditableText), '달님');
    await tester.pump();
    await tapNext(tester);
    await settleWithIo(tester);

    expect(find.text(_ko.profileEditRecalcConfirmTitle), findsNothing);
    expect(_patches(container, 'honorific'), [
      {'honorific': '달님'},
    ]);
    expect(_row(tester, ProfileEditScreen.callRowKey).value, '달님');
    expect(_saveButton(tester).onPressed, isNull);

    // 같은 호칭으로 돌아오면 다시 보내지 않습니다.
    await _tapRow(tester, ProfileEditScreen.callRowKey);
    expect(_stateOf(tester, ScreenIds.onboardCall).extra, '달님');
    await tapNext(tester);
    await settleWithIo(tester);
    expect(_patches(container, 'honorific'), hasLength(1));
  });

  testWidgets('호칭 저장이 실패하면 오류 toast와 이전 값입니다', (tester) async {
    final container = await _openProfileEdit(
      tester,
      network: ProfileRequestGate(failures: 1),
    );
    await _tapRow(tester, ProfileEditScreen.callRowKey);
    await tester.enterText(find.byType(EditableText), '달님');
    await tester.pump();
    await tapNext(tester);
    await settleWithIo(tester);

    expect(find.byType(ToastPill), findsOneWidget);
    expect(find.text(_ko.errorServiceUnavailable), findsOneWidget);
    expect(_row(tester, ProfileEditScreen.callRowKey).value, '하늘');
    expect(_fake(container).callCountOf('updateProfile'), greaterThan(0));
    await tester.pump(const Duration(seconds: 5));
    await settleWithIo(tester);
  });

  testWidgets('무거운 변경은 화면 안 변경으로 남고, 저장하면 바뀐 항목만 before → after 확인 창', (
    tester,
  ) async {
    final container = await _openProfileEdit(tester);
    await _changeGender(tester, _ko.genderMale);
    expect(_row(tester, ProfileEditScreen.genderRowKey).value, _ko.genderMale);
    expect(_saveButton(tester).onPressed, isNotNull);
    // 저장하지 않았습니다.
    expect(_patches(container, 'birth'), isEmpty);
    // 다시 열면 바꾼 값에서 시작합니다.
    await _tapRow(tester, ProfileEditScreen.genderRowKey);
    expect(
      _stateOf(tester, ScreenIds.onboardGender).extra,
      BirthGenderEnum.male,
    );
    Navigator.of(
      tester.element(find.byKey(const ValueKey(ScreenIds.onboardGender))),
    ).pop();
    await settleWithIo(tester);

    await _changeBirthDay(tester);
    expect(_row(tester, ProfileEditScreen.birthRowKey).value, _birthLabel(16));

    await _tapSave(tester);
    expect(find.text(_ko.profileEditRecalcConfirmTitle), findsOneWidget);
    expect(
      find.text(
        _ko.profileEditRecalcConfirmBody(
          '${_birthLabel(15)}, ${_ko.genderFemale}',
          '${_birthLabel(16)}, ${_ko.genderMale}',
        ),
      ),
      findsOneWidget,
    );
    // 파괴적이지 않은 무거운 변경이라 경고 표시 없는 일반 확인 창입니다(V41).
    expect(
      tester.widget<DialogCard>(find.byType(DialogCard)).variant,
      DialogVariant.confirm,
    );
    final cancel = find.text(_ko.profileEditRecalcConfirmCancel);
    await tester.tap(cancel);
    await settleWithIo(tester);

    expect(_patches(container, 'birth'), isEmpty);
    expect(_row(tester, ProfileEditScreen.genderRowKey).value, _ko.genderMale);
    expect(_row(tester, ProfileEditScreen.birthRowKey).value, _birthLabel(16));
    expect(_saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('확정하면 PATCH 한 번(빠르게 두 번 눌러도) → 이전 사주 캐시를 지우고 my-saju로', (
    tester,
  ) async {
    final container = await _openProfileEdit(tester);
    final seeded = await _seedSajuCaches(tester, container);
    await _changeGender(tester, _ko.genderMale);

    // 저장 버튼을 빠르게 두 번 눌러도 확인 창은 하나입니다.
    await tester.tap(find.byKey(ProfileEditScreen.saveKey));
    await tester.tap(
      find.byKey(ProfileEditScreen.saveKey),
      warnIfMissed: false,
    );
    await settleWithIo(tester);
    expect(find.text(_ko.profileEditRecalcConfirmTitle), findsOneWidget);

    final confirm = find.text(_ko.profileEditRecalcConfirmSave);
    await tester.tap(confirm);
    await tester.tap(confirm, warnIfMissed: false);
    await pumpUntilScreen(tester, ScreenIds.mySaju);
    await settleWithIo(tester);

    final patch = _patches(container, 'birth').single;
    expect(patch.keys, ['birth']);
    final birth = Birth.fromJson(patch['birth']! as Map<String, dynamic>);
    expect(birth.gender, BirthGenderEnum.male);
    // 바꾸지 않은 값은 사본 그대로입니다.
    expect(birth.date.day, 15);
    expect(birth.time.value, '14:30');
    expect(birth.timezone, 'Asia/Seoul');
    expect(await _readCaches(tester, container, seeded), [null, null, null]);
    final saved = await tester.runAsync(
      () => container.read(cachedProfileProvider.future),
    );
    expect(saved!.birth.gender, BirthGenderEnum.male);
    // my-saju는 스택을 바꿔(go) 뒤로 정보 수정이 없습니다.
    expect(find.byKey(const ValueKey(ScreenIds.profileEdit)), findsNothing);
  });

  testWidgets('saveBirth를 겹쳐 불러도 진행 중인 시도 하나로 PATCH 한 번입니다(Review Focus 2)', (
    tester,
  ) async {
    final gate = Completer<void>();
    final container = await _openProfileEdit(
      tester,
      network: ProfileRequestGate(gate: gate),
    );
    await _changeGender(tester, _ko.genderMale);
    final controller = container.read(
      profileEditControllerProvider(null).notifier,
    );
    final profile = (await tester.runAsync(
      () => container.read(cachedProfileProvider.future),
    ))!;
    final first = controller.saveBirth(profile);
    final second = controller.saveBirth(profile);
    expect(identical(first, second), isTrue);
    await tester.pump();
    // 저장 중에는 줄과 저장 버튼이 비활성입니다.
    expect(_row(tester, ProfileEditScreen.genderRowKey).onTap, isNull);
    expect(_saveButton(tester).onPressed, isNull);
    gate.complete();
    await pumpUntil(tester, () => _patches(container, 'birth').isNotEmpty);
    expect(await tester.runAsync(() => first), isTrue);
    expect(_patches(container, 'birth'), hasLength(1));
  });

  testWidgets('호칭과 무거운 변경이 섞이면 호칭은 바로, 무거운 변경은 남았다가 확정 때 birth만 PATCH', (
    tester,
  ) async {
    final container = await _openProfileEdit(tester);
    await _changeGender(tester, _ko.genderMale);
    await _tapRow(tester, ProfileEditScreen.callRowKey);
    await tester.enterText(find.byType(EditableText), '달님');
    await tester.pump();
    await tapNext(tester);
    await settleWithIo(tester);

    expect(_patches(container, 'honorific'), [
      {'honorific': '달님'},
    ]);
    expect(_patches(container, 'birth'), isEmpty);
    // 호칭 저장(사본 갱신) 뒤에도 무거운 변경은 화면 안에 남아 있습니다.
    expect(_row(tester, ProfileEditScreen.genderRowKey).value, _ko.genderMale);
    expect(_row(tester, ProfileEditScreen.callRowKey).value, '달님');
    expect(_saveButton(tester).onPressed, isNotNull);

    await _tapSave(tester);
    expect(
      find.text(
        _ko.profileEditRecalcConfirmBody(_ko.genderFemale, _ko.genderMale),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(_ko.profileEditRecalcConfirmSave));
    await pumpUntilScreen(tester, ScreenIds.mySaju);
    await settleWithIo(tester);

    expect(_patches(container, 'birth').single.keys, ['birth']);
    expect(_patches(container, 'honorific'), hasLength(1));
  });

  testWidgets('저장 뒤 이전 사주 캐시 지우기가 실패해도 저장 성공으로 my-saju에 가고 요약만 보고합니다', (
    tester,
  ) async {
    final container = await _openProfileEdit(tester);
    await _changeGender(tester, _ko.genderMale);
    // 캐시 줄 지우기만 실패하게 합니다(쓰기는 그대로).
    await tester.runAsync(
      () => container
          .read(appDatabaseProvider)
          .customStatement(
            'CREATE TRIGGER fail_cache_delete '
            'BEFORE DELETE ON cached_responses '
            "BEGIN SELECT RAISE(ABORT, 'x'); END",
          ),
    );
    final reporter = container.read(crashReporterProvider) as FakeCrashReporter;
    final reported = reporter.errors.length;

    await _tapSave(tester);
    await tester.tap(find.text(_ko.profileEditRecalcConfirmSave));
    await pumpUntilScreen(tester, ScreenIds.mySaju);
    await settleWithIo(tester);

    expect(reporter.errors.length, greaterThan(reported));
    final saved = await tester.runAsync(
      () => container.read(cachedProfileProvider.future),
    );
    expect(saved!.birth.gender, BirthGenderEnum.male);
  });

  testWidgets('저장이 실패하면 오류 배너와 다시 시도, 바꾼 값과 이전 캐시는 그대로입니다', (tester) async {
    covers(const Covers(states: ['profile-edit:error']));
    final container = await _openProfileEdit(
      tester,
      network: ProfileRequestGate(failures: 1),
    );
    final seeded = await _seedSajuCaches(tester, container);
    await _changeGender(tester, _ko.genderMale);
    await _tapSave(tester);
    await tester.tap(find.text(_ko.profileEditRecalcConfirmSave));
    await settleWithIo(tester);

    final banner = tester.widget<NoticeBanner>(_banner);
    expect(banner.present, isTrue);
    expect(banner.variant, NoticeBannerVariant.error);
    expect(banner.message, _ko.errorServiceUnavailable);
    expect(find.byKey(const ValueKey(ScreenIds.profileEdit)), findsOneWidget);
    expect(_row(tester, ProfileEditScreen.genderRowKey).value, _ko.genderMale);
    expect(_saveButton(tester).label, _ko.actionRetry);
    expect(await _readCaches(tester, container, seeded), ['{}', '{}', '{}']);
    final kept = await tester.runAsync(
      () => container.read(cachedProfileProvider.future),
    );
    expect(kept!.birth.gender, BirthGenderEnum.female);

    // 다시 시도는 이미 확인한 같은 변경을 다시 보냅니다.
    await tester.tap(find.byKey(ProfileEditScreen.saveKey));
    await pumpUntilScreen(tester, ScreenIds.mySaju);
    await settleWithIo(tester);
    expect(await _readCaches(tester, container, seeded), [null, null, null]);
  });

  testWidgets('생일을 바꾼 뒤 시간 화면을 열면 시진 확인은 바꾼 생일로 묻습니다(D58)', (tester) async {
    covers(const Covers(decisions: ['D58']));
    final container = await _openProfileEdit(tester, locale: koreaLocale);
    await _changeBirthDay(tester);
    await _tapRow(tester, ProfileEditScreen.timeRowKey);
    expect(
      _stateOf(tester, ScreenIds.onboardTime).extra,
      TimeStepEdit(
        time: BirthTime(status: BirthTimeStatusEnum.known, value: '14:30'),
        date: const BirthDateValue(
          calendar: BirthCalendar.solar,
          year: 1990,
          month: 5,
          day: 16,
        ),
      ),
    );
    await pumpUntil(
      tester,
      () => _fake(container).callCountOf('getBirthHour') > 0,
    );
    final body = _bodyOf(_fake(container).requestBodiesOf('getBirthHour').last);
    expect(body['date'], {'year': 1990, 'month': 5, 'day': 16});
    expect(body['time'], '14:30');
  });

  testWidgets('실패 뒤 값을 또 바꾸면 배너가 풀리고 저장은 다시 확인 창입니다', (tester) async {
    await _openProfileEdit(tester, network: ProfileRequestGate(failures: 1));
    await _changeGender(tester, _ko.genderMale);
    await _tapSave(tester);
    await tester.tap(find.text(_ko.profileEditRecalcConfirmSave));
    await settleWithIo(tester);
    expect(_saveButton(tester).label, _ko.actionRetry);

    await _changeBirthDay(tester);
    expect(tester.widget<NoticeBanner>(_banner).present, isFalse);
    expect(_saveButton(tester).label, _ko.onboardingSave);
    await _tapSave(tester);
    expect(find.text(_ko.profileEditRecalcConfirmTitle), findsOneWidget);
  });

  testWidgets('사본이 없으면 getProfile로 채워 엽니다(#312)', (tester) async {
    // 앱 시작의 시간대 동기화(PATCH)가 실패해 사본이 없는 기기입니다.
    final container = await _openProfileEdit(
      tester,
      startNetwork: ProfileRequestGate(failures: 100),
    );
    // 받은 프로필을 사본으로 쓰는(로컬 DB) 동안 기다립니다.
    await pumpUntil(
      tester,
      () => _row(tester, ProfileEditScreen.callRowKey).value != null,
    );
    expect(_fake(container).callCountOf('getProfile'), 1);
    expect(_row(tester, ProfileEditScreen.callRowKey).value, '하늘');
    expect(
      _row(tester, ProfileEditScreen.genderRowKey).value,
      _ko.genderFemale,
    );
  });

  testWidgets('프로필을 받지 못하면 오류 toast, 줄을 누르면 다시 받습니다(#312)', (tester) async {
    final container = await _openProfileEdit(
      tester,
      startNetwork: ProfileRequestGate(failures: 100),
      network: ProfileRequestGate(failures: 1, method: 'GET'),
    );
    expect(find.byType(ToastPill), findsOneWidget);
    expect(_row(tester, ProfileEditScreen.callRowKey).value, isNull);
    expect(_row(tester, ProfileEditScreen.callRowKey).onTap, isNotNull);

    await tester.tap(find.byKey(ProfileEditScreen.genderRowKey));
    await settleWithIo(tester);
    expect(_fake(container).callCountOf('getProfile'), 1);
    expect(
      _row(tester, ProfileEditScreen.genderRowKey).value,
      _ko.genderFemale,
    );
    // 다시 받기는 입력 화면을 열지 않습니다.
    expect(find.byKey(const ValueKey(ScreenIds.onboardGender)), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await settleWithIo(tester);
  });

  testWidgets(
    'settings 출생지 안내에서 고른 도시는 켜진 저장 버튼으로 열리고, 한국 기기여도 그 도시로 저장합니다(D29)',
    (tester) async {
      covers(
        const Covers(exits: ['settings>profile-edit'], decisions: ['D29']),
      );
      final container = await pumpApp(tester, scenario: 'member');
      unawaited(
        container.read(routerProvider).push<void>(pathOf(ScreenIds.settings)),
      );
      await pumpUntilScreen(tester, ScreenIds.settings);
      await settleWithIo(tester);
      await tester.tap(find.byKey(SettingsScreen.languageRowKey));
      await settleWithIo(tester);
      await tester.tap(find.byKey(LanguageSheet.rowKey(Language.en)));
      await settleWithIo(tester);
      await tester.tap(find.byKey(BirthplaceNoticeSheet.ctaKey));
      await pumpUntilScreen(tester, ScreenIds.birthplace);
      await tester.enterText(find.byType(EditableText), 'new');
      await tester.pump(const Duration(milliseconds: 301));
      await settleWithIo(tester);
      await tester.tap(find.text('New York City'));
      await pumpUntilScreen(tester, ScreenIds.profileEdit);
      await settleWithIo(tester);

      expect(
        _row(tester, ProfileEditScreen.placeRowKey).value,
        'New York City, United States',
      );
      expect(_saveButton(tester).onPressed, isNotNull);
      expect(_patches(container, 'birth'), isEmpty);

      await _tapSave(tester);
      expect(find.text(_en.profileEditRecalcConfirmTitle), findsOneWidget);
      expect(
        find.text(
          _en.profileEditRecalcConfirmBody(
            _en.profileEditBirthplaceKorea,
            'New York City, United States',
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(_en.profileEditRecalcConfirmSave));
      await pumpUntilScreen(tester, ScreenIds.mySaju);
      await settleWithIo(tester);

      final birth = Birth.fromJson(
        _patches(container, 'birth').single['birth']! as Map<String, dynamic>,
      );
      expect(birth.place.status.value, 'city');
      expect(birth.place.cityId, '5128581');
      expect(birth.timezone, 'America/New_York');
    },
  );

  test('바뀐 항목은 생일·시간·성별·출생지 순서이고 같은 값으로 돌아오면 변경이 아닙니다', () {
    final profile = Profile.fromJson(_memberProfile);
    final values = BirthValues.of(profile);
    expect(values.applying(const BirthEdits()).changesFrom(values), isEmpty);
    final edits = BirthEdits(
      gender: BirthGenderEnum.male,
      time: BirthTime(status: BirthTimeStatusEnum.unknown),
      date: values.date,
    );
    expect(values.applying(edits).changesFrom(values), [
      BirthField.time,
      BirthField.gender,
    ]);
  });
}

final Map<String, dynamic> _memberProfile = {
  'honorific': '하늘',
  'language': 'ko',
  'currentTimezone': 'Asia/Seoul',
  'birth': {
    'calendar': 'solar',
    'date': {'year': 1990, 'month': 5, 'day': 15},
    'isLeapMonth': false,
    'time': {'status': 'known', 'value': '14:30'},
    'gender': 'female',
    'timezone': 'Asia/Seoul',
    'place': {'status': 'not_asked'},
  },
  'notification': {'status': 'not_asked'},
};
