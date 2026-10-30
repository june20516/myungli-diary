import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/api/gen/model/birth_place.dart';
import 'package:myungli_diary/core/api/gen/model/city.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_en.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/push.dart';
import 'package:myungli_diary/design/components/action/settings_row.dart';
import 'package:myungli_diary/design/components/feedback/toast.dart';
import 'package:myungli_diary/design/components/input/segmented.dart';
import 'package:myungli_diary/design/components/input/time_picker.dart';
import 'package:myungli_diary/features/me/application/settings_controller.dart';
import 'package:myungli_diary/features/me/presentation/settings_screen.dart';
import 'package:myungli_diary/features/me/presentation/settings_sheets.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/app_bar_title.dart';
import '../support/app_harness.dart';
import '../support/onboarding_steps.dart';

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

/// [method] [path] 요청을 [gate]가 끝날 때까지 붙잡고, [failures]번은 503으로 답합니다.
/// 기본은 프로필 저장(PATCH)입니다.
final class _ProfilePatchGate extends Interceptor {
  new({
    this.failures = 0,
    this.gate,
    this.method = 'PATCH',
    this.path = '/v1/me/profile',
  });

  int failures;
  final Completer<void>? gate;
  final String method;
  final String path;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.method != method || options.path != path) {
      handler.next(options);
      return;
    }
    await gate?.future;
    if (failures == 0) {
      handler.next(options);
      return;
    }
    failures--;
    handler.reject(
      DioException.badResponse(
        statusCode: 503,
        requestOptions: options,
        response: Response<Object?>(
          requestOptions: options,
          statusCode: 503,
          headers: Headers.fromMap({
            Headers.contentTypeHeader: ['application/problem+json'],
          }),
          data: {
            'status': 503,
            'code': 'service.unavailable',
            'title': 'x',
            'traceId': 't',
          },
        ),
      ),
      true,
    );
  }
}

/// 프로필 응답의 출생지를 도시로 바꿉니다(출생지를 이미 입력한 회원).
final class _BirthCity extends Interceptor {
  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final data = response.data;
    if (response.requestOptions.path == '/v1/me/profile' && data is Map) {
      final body = Map<String, Object?>.of(data.cast<String, Object?>());
      final profile = Map<String, Object?>.of(
        (body['profile']! as Map).cast<String, Object?>(),
      );
      final birth = Map<String, Object?>.of(
        (profile['birth']! as Map).cast<String, Object?>(),
      );
      birth['place'] = {'status': 'city', 'cityId': '5128581'};
      profile['birth'] = birth;
      body['profile'] = profile;
      response.data = body;
    }
    handler.next(response);
  }
}

/// 프로필 응답의 언어를 계약에 없는 값으로 바꿉니다(REST 1.0.0 열린 enum).
final class _UnknownLanguage extends Interceptor {
  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final data = response.data;
    if (response.requestOptions.path == '/v1/me/profile' && data is Map) {
      final body = Map<String, Object?>.of(data.cast<String, Object?>());
      body['profile'] = {
        ...(body['profile']! as Map).cast<String, Object?>(),
        'language': 'xx',
      };
      response.data = body;
    }
    handler.next(response);
  }
}

/// 알림 권한 요청 수를 세는 푸시 대역.
final class _CountingPush implements PushMessaging {
  new({this.granted = true});

  final bool granted;
  int permissionRequests = 0;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<bool> hasPermission() async => granted && permissionRequests > 0;

  @override
  Future<String?> token() async => 'fake-push-token';

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();

  @override
  Stream<PushOpen> get opens => const Stream.empty();

  @override
  Future<PushOpen?> initialOpen() async => null;
}

/// [scenario]로 앱을 띄우고 설정을 엽니다. [network]는 앱 시작(기기 시간대 동기화) 뒤에 끼웁니다.
Future<ProviderContainer> _openSettings(
  WidgetTester tester, {
  String scenario = 'member',
  List<Override> overrides = const [],
  Interceptor? startNetwork,
  Interceptor? network,
}) async {
  final container = await pumpApp(
    tester,
    scenario: scenario,
    overrides: overrides,
    network: startNetwork,
  );
  if (network != null) {
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, network);
  }
  unawaited(
    container.read(routerProvider).push<void>(pathOf(ScreenIds.settings)),
  );
  await pumpUntilScreen(tester, ScreenIds.settings);
  await settleWithIo(tester);
  return container;
}

/// [screenId] 화면의 라우터 상태(경로·query·extra).
GoRouterState _stateOf(WidgetTester tester, String screenId) =>
    GoRouterState.of(tester.element(find.byKey(ValueKey(screenId))));

SettingsRow _row(WidgetTester tester, Key key) =>
    tester.widget<SettingsRow>(find.byKey(key));

Future<void> _tapRow(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await settleWithIo(tester);
}

/// 알림 시각 시트에서 스위치를 누릅니다.
Future<void> _toggleNotify(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(NotifyTimeSheet.sheetKey),
      matching: find.byKey(SettingsRow.toggleKey),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _saveNotify(WidgetTester tester) async {
  await tester.tap(find.byKey(NotifyTimeSheet.saveKey));
  await settleWithIo(tester);
}

String _timeLabel(int hour, int minute) =>
    DateFormat.jm('ko').format(DateTime(2000, 1, 1, hour, minute));

void main() {
  testWidgets('제목과 묶음·줄: 기본 깊이 줄과 segmented가 없습니다(A59, D79)', (tester) async {
    covers(const Covers(decisions: ['D79', 'D39']));
    await _openSettings(tester);
    await expectAppBarTitle(
      tester,
      SlotIds.settingsBarTitle,
      _ko.settingsBarTitle,
    );

    expect(find.byType(SettingsGroup), findsNWidgets(4));
    expect(find.byType(Segmented<Object?>), findsNothing);
    final labels = [
      for (final row in tester.widgetList<SettingsRow>(
        find.byType(SettingsRow),
      ))
        row.label,
    ];
    expect(labels, [
      _ko.settingsNotifyLabel,
      _ko.settingsLanguageLabel,
      _ko.settingsAdFreeLabel,
      _ko.loginMethodsBarTitle,
      _ko.profileEditBarTitle,
      _ko.calcBasisBarTitle,
      _ko.legalBarTitle,
      _ko.settingsLogoutLabel,
      _ko.accountDeleteBarTitle,
    ]);
    // 알림은 묻지 않은 상태라 꺼짐, 언어는 사본 그대로입니다.
    expect(
      _row(tester, SettingsScreen.notifyRowKey).value,
      _ko.settingsNotifyOff,
    );
    expect(_row(tester, SettingsScreen.languageRowKey).value, '한국어');
    expect(
      _row(tester, SettingsScreen.logoutRowKey).variant,
      SettingsRowVariant.destructive,
    );
    expect(
      _row(tester, SettingsScreen.accountDeleteRowKey).variant,
      SettingsRowVariant.destructive,
    );
  });

  testWidgets('알림을 켜면 권한을 묻고 기기를 등록한 뒤 PATCH, 시각만 바꾸면 권한을 다시 묻지 않고, 끌 수 있습니다', (
    tester,
  ) async {
    covers(const Covers(decisions: ['D18']));
    final push = _CountingPush();
    final container = await _openSettings(
      tester,
      overrides: [pushMessagingProvider.overrideWithValue(push)],
    );

    await _tapRow(tester, SettingsScreen.notifyRowKey);
    expect(find.byKey(NotifyTimeSheet.sheetKey), findsOneWidget);
    final picker = tester.widget<TimePicker>(find.byType(TimePicker));
    expect(picker.variant, TimePickerVariant.notify);
    await _toggleNotify(tester);
    await _saveNotify(tester);

    expect(push.permissionRequests, 1);
    expect(_fake(container).callCountOf('registerDevice'), 1);
    expect(_patches(container, 'notification').single, {
      'notification': {'status': 'enabled', 'time': '08:00'},
    });
    expect(find.byKey(NotifyTimeSheet.sheetKey), findsNothing);
    expect(_row(tester, SettingsScreen.notifyRowKey).value, _timeLabel(8, 0));

    // 켜진 채 시각만 바꿉니다(분 여섯 칸 = 30분).
    await _tapRow(tester, SettingsScreen.notifyRowKey);
    await tester.drag(
      find.byKey(TimePicker.minuteWheelKey),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    await _saveNotify(tester);
    expect(push.permissionRequests, 1);
    expect(_fake(container).callCountOf('registerDevice'), 1);
    expect(_patches(container, 'notification').last, {
      'notification': {'status': 'enabled', 'time': '08:30'},
    });
    expect(_row(tester, SettingsScreen.notifyRowKey).value, _timeLabel(8, 30));

    // 끕니다.
    await _tapRow(tester, SettingsScreen.notifyRowKey);
    await _toggleNotify(tester);
    await _saveNotify(tester);
    expect(_patches(container, 'notification').last, {
      'notification': {'status': 'disabled'},
    });
    expect(
      _row(tester, SettingsScreen.notifyRowKey).value,
      _ko.settingsNotifyOff,
    );
  });

  testWidgets('권한을 거절하면 disabled로 저장하고 기기를 등록하지 않습니다', (tester) async {
    final push = _CountingPush(granted: false);
    final container = await _openSettings(
      tester,
      overrides: [pushMessagingProvider.overrideWithValue(push)],
    );
    await _tapRow(tester, SettingsScreen.notifyRowKey);
    await _toggleNotify(tester);
    await _saveNotify(tester);

    expect(push.permissionRequests, 1);
    expect(_fake(container).callCountOf('registerDevice'), 0);
    expect(_patches(container, 'notification').single, {
      'notification': {'status': 'disabled'},
    });
    expect(
      _row(tester, SettingsScreen.notifyRowKey).value,
      _ko.settingsNotifyOff,
    );
  });

  testWidgets('바꾸지 않고 저장하거나 시트를 닫으면 PATCH하지 않습니다', (tester) async {
    final container = await _openSettings(tester);
    await _tapRow(tester, SettingsScreen.notifyRowKey);
    await _saveNotify(tester);
    expect(_patches(container, 'notification'), isEmpty);
    expect(find.byKey(NotifyTimeSheet.sheetKey), findsNothing);

    // 켜 놓고 저장하지 않은 채 닫아도 저장하지 않습니다.
    await _tapRow(tester, SettingsScreen.notifyRowKey);
    await _toggleNotify(tester);
    Navigator.of(tester.element(find.byKey(NotifyTimeSheet.sheetKey))).pop();
    await settleWithIo(tester);
    expect(_patches(container, 'notification'), isEmpty);
    expect(
      _row(tester, SettingsScreen.notifyRowKey).value,
      _ko.settingsNotifyOff,
    );
  });

  testWidgets('프로필 언어가 모르는 값이면 언어 줄에 English가 보인다', (tester) async {
    await _openSettings(tester, startNetwork: _UnknownLanguage());
    expect(_row(tester, SettingsScreen.languageRowKey).value, 'English');
  });

  testWidgets('언어를 바꾸면 PATCH 뒤 앱이 그 언어로, 출생지를 묻지 않았으면 안내 → birthplace 수정 모드', (
    tester,
  ) async {
    covers(
      const Covers(exits: ['settings>birthplace'], decisions: ['D28', 'D29']),
    );
    final container = await _openSettings(tester);
    await _tapRow(tester, SettingsScreen.languageRowKey);
    expect(find.byKey(LanguageSheet.sheetKey), findsOneWidget);
    await tester.tap(find.byKey(LanguageSheet.rowKey(Language.en)));
    await settleWithIo(tester);

    expect(_patches(container, 'language').single, {'language': 'en'});
    expect(container.read(localeProvider).languageCode, 'en');
    expect(find.text(_en.settingsBarTitle), findsOneWidget);
    expect(_row(tester, SettingsScreen.languageRowKey).value, 'English');

    final notice = find.byKey(
      const ValueKey(SlotIds.settingsLanguageBirthplaceNotice),
    );
    expect(notice, findsOneWidget);
    expect(find.text(_en.settingsLanguageBirthplaceNotice), findsOneWidget);
    await tester.tap(find.byKey(BirthplaceNoticeSheet.ctaKey));
    await pumpUntilScreen(tester, ScreenIds.birthplace);
    final location = _stateOf(tester, ScreenIds.birthplace).uri;
    expect(location.path, pathOf(ScreenIds.birthplace));
    expect(location.queryParameters['mode'], 'edit');
  });

  testWidgets('출생지 수정 모드에서 고른 도시는 정보 수정으로 넘깁니다(무거운 변경 확인은 그 화면, A6)', (
    tester,
  ) async {
    covers(const Covers(exits: ['settings>profile-edit']));
    await _openSettings(tester);
    await _tapRow(tester, SettingsScreen.languageRowKey);
    await tester.tap(find.byKey(LanguageSheet.rowKey(Language.en)));
    await settleWithIo(tester);
    await tester.tap(find.byKey(BirthplaceNoticeSheet.ctaKey));
    await pumpUntilScreen(tester, ScreenIds.birthplace);

    await tester.enterText(find.byType(EditableText), 'new');
    await tester.pump(const Duration(milliseconds: 301));
    await settleWithIo(tester);
    await tester.tap(find.text('New York City'));
    await pumpUntilScreen(tester, ScreenIds.profileEdit);

    final configuration = _stateOf(tester, ScreenIds.profileEdit);
    expect(configuration.uri.path, pathOf(ScreenIds.profileEdit));
    expect((configuration.extra as City?)?.id, '5128581');
  });

  testWidgets('출생지를 이미 입력했거나 한국어로 바꾸면 안내가 없습니다', (tester) async {
    final container = await _openSettings(tester, startNetwork: _BirthCity());
    await _tapRow(tester, SettingsScreen.languageRowKey);
    await tester.tap(find.byKey(LanguageSheet.rowKey(Language.ja)));
    await settleWithIo(tester);
    expect(container.read(localeProvider).languageCode, 'ja');
    expect(
      find.byKey(const ValueKey(SlotIds.settingsLanguageBirthplaceNotice)),
      findsNothing,
    );
  });

  test('출생지 안내는 한국어가 아니고 출생지를 묻지 않았을 때만입니다(A60)', () {
    expect(
      offersBirthplaceNotice(Language.en, BirthPlaceStatusEnum.notAsked),
      isTrue,
    );
    expect(
      offersBirthplaceNotice(Language.ja, BirthPlaceStatusEnum.notAsked),
      isTrue,
    );
    expect(
      offersBirthplaceNotice(Language.ko, BirthPlaceStatusEnum.notAsked),
      isFalse,
    );
    expect(
      offersBirthplaceNotice(Language.en, BirthPlaceStatusEnum.skipped),
      isFalse,
    );
    expect(
      offersBirthplaceNotice(Language.en, BirthPlaceStatusEnum.city),
      isFalse,
    );
  });

  testWidgets(
    '저장 중에는 줄이 비활성, 실패하면 오류 toast와 이전 언어이고 안내가 없습니다(Review Focus 3)',
    (tester) async {
      final gate = Completer<void>();
      final container = await _openSettings(
        tester,
        network: _ProfilePatchGate(failures: 1, gate: gate),
      );
      await _tapRow(tester, SettingsScreen.languageRowKey);
      await tester.tap(find.byKey(LanguageSheet.rowKey(Language.en)));
      await tester.pumpAndSettle();
      expect(_row(tester, SettingsScreen.languageRowKey).onTap, isNull);

      gate.complete();
      await settleWithIo(tester);
      expect(find.byType(ToastPill), findsOneWidget);
      expect(container.read(localeProvider).languageCode, 'ko');
      expect(_row(tester, SettingsScreen.languageRowKey).value, '한국어');
      expect(_row(tester, SettingsScreen.languageRowKey).onTap, isNotNull);
      expect(
        find.byKey(const ValueKey(SlotIds.settingsLanguageBirthplaceNotice)),
        findsNothing,
      );
      // toast가 사라질 때까지 둡니다.
      await tester.pump(const Duration(seconds: 5));
      await settleWithIo(tester);
    },
  );

  testWidgets('같은 값을 빨리 두 번 저장해도 PATCH는 한 번입니다', (tester) async {
    final gate = Completer<void>();
    final container = await _openSettings(
      tester,
      network: _ProfilePatchGate(gate: gate),
    );
    final controller = container.read(settingsControllerProvider.notifier);
    final first = controller.setLanguage(Language.ja);
    final second = controller.setLanguage(Language.ja);
    expect(identical(first, second), isTrue);
    gate.complete();
    await settleWithIo(tester);
    expect(_patches(container, 'language'), hasLength(1));
    expect(container.read(localeProvider).languageCode, 'ja');
  });

  testWidgets('광고 제거 줄: 비활성이면 이름만, 누르면 ad-free', (tester) async {
    covers(const Covers(exits: ['settings>ad-free'], decisions: ['D53']));
    await _openSettings(tester);
    final row = _row(tester, SettingsScreen.adFreeRowKey);
    expect(row.variant, SettingsRowVariant.navigate);
    await _tapRow(tester, SettingsScreen.adFreeRowKey);
    expect(find.byKey(const ValueKey(ScreenIds.adFree)), findsOneWidget);
  });

  testWidgets('광고 제거 줄: 활성이면 만료 날짜(프로필 시간대)', (tester) async {
    await _openSettings(tester, scenario: 'ad-free-active');
    final row = _row(tester, SettingsScreen.adFreeRowKey);
    expect(row.variant, SettingsRowVariant.value);
    expect(
      row.value,
      _ko.settingsAdFreeLabelActive(
        DateFormat.yMMMd('ko').format(DateTime(2026, 11, 12)),
      ),
    );
  });

  for (final (key, screen, exit) in [
    (
      SettingsScreen.profileEditRowKey,
      ScreenIds.profileEdit,
      'settings>profile-edit',
    ),
    (
      SettingsScreen.calcBasisRowKey,
      ScreenIds.calcBasis,
      'settings>calc-basis',
    ),
    (SettingsScreen.legalRowKey, ScreenIds.legal, 'settings>legal'),
    (
      SettingsScreen.accountDeleteRowKey,
      ScreenIds.accountDelete,
      'settings>account-delete',
    ),
  ]) {
    testWidgets('$exit 줄', (tester) async {
      covers(
        const Covers(
          exits: [
            'settings>profile-edit',
            'settings>calc-basis',
            'settings>legal',
            'settings>account-delete',
          ],
        ),
      );
      final container = await _openSettings(tester);
      await _tapRow(tester, key);
      expect(find.byKey(ValueKey(screen)), findsOneWidget);
      container.read(routerProvider).pop();
      await settleWithIo(tester);
      expect(find.byKey(const ValueKey(ScreenIds.settings)), findsOneWidget);
    });
  }

  testWidgets('로그아웃: 확인 창에서 취소하면 그대로, 확정하면 revokeAndSignOut → welcome', (
    tester,
  ) async {
    covers(const Covers(exits: ['settings>welcome']));
    final container = await _openSettings(tester);
    await _tapRow(tester, SettingsScreen.logoutRowKey);
    expect(find.text(_ko.settingsLogoutConfirm), findsOneWidget);
    await tester.tap(find.text(_ko.settingsLogoutConfirmCancel));
    await settleWithIo(tester);
    expect(find.byKey(const ValueKey(ScreenIds.settings)), findsOneWidget);
    expect(_fake(container).callCountOf('logout'), 0);

    await _tapRow(tester, SettingsScreen.logoutRowKey);
    await tester.tap(find.text(_ko.settingsLogoutConfirmLogout).last);
    await pumpUntilScreen(tester, ScreenIds.welcome);
    expect(_fake(container).callCountOf('logout'), 1);
  });

  testWidgets('알림 줄도 저장 중에는 비활성이고, 끝나면 다시 눌립니다', (tester) async {
    final gate = Completer<void>();
    await _openSettings(tester, network: _ProfilePatchGate(gate: gate));
    await _tapRow(tester, SettingsScreen.notifyRowKey);
    await _toggleNotify(tester);
    await tester.tap(find.byKey(NotifyTimeSheet.saveKey));
    await tester.pumpAndSettle();
    expect(_row(tester, SettingsScreen.notifyRowKey).onTap, isNull);
    // 다른 값(언어) 줄은 그대로 눌립니다.
    expect(_row(tester, SettingsScreen.languageRowKey).onTap, isNotNull);

    gate.complete();
    // 대역 서버가 fixture를 실제 I/O로 읽으므로 저장이 끝날 때까지 기다립니다.
    await pumpUntil(
      tester,
      () => _row(tester, SettingsScreen.notifyRowKey).onTap != null,
    );
    expect(_row(tester, SettingsScreen.notifyRowKey).value, _timeLabel(8, 0));
  });

  testWidgets('프로필을 받지 못하면 오류 toast, 알림·언어 줄을 누르면 다시 받습니다(#312)', (
    tester,
  ) async {
    // 앱 시작의 시간대 동기화(PATCH)가 실패해 사본이 없는 기기입니다.
    final read = _ProfilePatchGate(failures: 1, method: 'GET');
    final container = await _openSettings(
      tester,
      startNetwork: _ProfilePatchGate(failures: 100),
      network: read,
    );
    expect(find.byType(ToastPill), findsOneWidget);
    final row = _row(tester, SettingsScreen.notifyRowKey);
    expect(row.value, isNull);
    expect(row.onTap, isNotNull);
    expect(_row(tester, SettingsScreen.languageRowKey).value, isNull);

    await tester.tap(find.byKey(SettingsScreen.languageRowKey));
    await settleWithIo(tester);
    expect(_fake(container).callCountOf('getProfile'), 1);
    expect(
      _row(tester, SettingsScreen.notifyRowKey).value,
      _ko.settingsNotifyOff,
    );
    expect(_row(tester, SettingsScreen.languageRowKey).value, '한국어');
    // 다시 받기는 시트를 열지 않습니다.
    expect(find.byKey(LanguageSheet.sheetKey), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await settleWithIo(tester);
  });

  testWidgets('빠르게 두 번 눌러도 시트·화면은 한 번만 열립니다', (tester) async {
    final container = await _openSettings(tester);
    await tester.tap(find.byKey(SettingsScreen.notifyRowKey));
    await tester.tap(find.byKey(SettingsScreen.notifyRowKey));
    await settleWithIo(tester);
    expect(find.byKey(NotifyTimeSheet.sheetKey), findsOneWidget);
    Navigator.of(tester.element(find.byKey(NotifyTimeSheet.sheetKey))).pop();
    await settleWithIo(tester);

    await tester.tap(find.byKey(SettingsScreen.calcBasisRowKey));
    await tester.tap(find.byKey(SettingsScreen.calcBasisRowKey));
    await settleWithIo(tester);
    expect(find.byKey(const ValueKey(ScreenIds.calcBasis)), findsOneWidget);
    container.read(routerProvider).pop();
    await settleWithIo(tester);
    // 한 번만 쌓였으므로 한 번 돌아오면 설정입니다.
    expect(find.byKey(const ValueKey(ScreenIds.calcBasis)), findsNothing);
    expect(find.byKey(const ValueKey(ScreenIds.settings)), findsOneWidget);
  });

  testWidgets('로그아웃 중에는 모든 줄이 비활성입니다', (tester) async {
    final gate = Completer<void>();
    await _openSettings(
      tester,
      network: _ProfilePatchGate(
        gate: gate,
        method: 'POST',
        path: '/v1/auth/logout',
      ),
    );
    await _tapRow(tester, SettingsScreen.logoutRowKey);
    await tester.tap(find.text(_ko.settingsLogoutConfirmLogout).last);
    await tester.pumpAndSettle();
    for (final key in [
      SettingsScreen.notifyRowKey,
      SettingsScreen.languageRowKey,
      SettingsScreen.adFreeRowKey,
      SettingsScreen.profileEditRowKey,
      SettingsScreen.calcBasisRowKey,
      SettingsScreen.legalRowKey,
      SettingsScreen.logoutRowKey,
      SettingsScreen.accountDeleteRowKey,
    ]) {
      expect(_row(tester, key).onTap, isNull, reason: '$key');
    }
    gate.complete();
    await pumpUntilScreen(tester, ScreenIds.welcome);
  });

  testWidgets('같은 필드에 진행 중과 다른 값을 저장하면 StateError입니다', (tester) async {
    final gate = Completer<void>();
    final container = await _openSettings(
      tester,
      network: _ProfilePatchGate(gate: gate),
    );
    final controller = container.read(settingsControllerProvider.notifier);
    final first = controller.setLanguage(Language.ja);
    expect(() => controller.setLanguage(Language.en), throwsStateError);
    gate.complete();
    await settleWithIo(tester);
    await first;
    expect(_patches(container, 'language'), [
      {'language': 'ja'},
    ]);
  });
}
