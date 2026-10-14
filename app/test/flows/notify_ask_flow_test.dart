import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/api/fake/fake_server.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/platform/ad_consent.dart';
import 'package:myungli_diary/core/platform/fakes.dart';
import 'package:myungli_diary/core/platform/platform_providers.dart';
import 'package:myungli_diary/core/platform/push.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/input/input_step.dart';
import 'package:myungli_diary/design/components/input/time_picker.dart';
import 'package:myungli_diary/features/onboarding/presentation/notify_ask_screen.dart';
import 'package:myungli_diary/testing/covers.dart';

import '../support/onboarding_steps.dart';

final _ko = AppLocalizationsKo();

FakeServerInterceptor _fake(ProviderContainer container) =>
    container.read(fakeServerInterceptorProvider)! as FakeServerInterceptor;

Finder _screen(String id) => find.byKey(ValueKey(id));

Map<String, Object?> _bodyOf(Object? data) =>
    (data is String ? jsonDecode(data) : data)! as Map<String, Object?>;

/// 알림 설정을 바꾼 `updateProfile` 본문. 기기 시간대 동기화 요청은 거릅니다.
List<Map<String, Object?>> _notificationBodies(FakeServerInterceptor fake) => [
  for (final body in fake.requestBodiesOf('updateProfile'))
    if (_bodyOf(body).containsKey('notification')) _bodyOf(body),
];

Map<String, Object?> _notificationBody(FakeServerInterceptor fake) =>
    _notificationBodies(fake).single;

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// 광고 동의 SDK 호출 수를 세는 대역.
class _CountingAdConsent implements AdConsent {
  int gathers = 0;

  @override
  Future<AdConsentResult> gather() async {
    gathers++;
    return AdConsentResult.personalized;
  }
}

Finder get _allowButton => find.descendant(
  of: find.byType(InputStep),
  matching: find.byType(PrimaryButton),
);
Finder get _skipButton => find.byKey(notifyAskSkipKey);

/// 휠을 [steps]칸 내립니다(한 칸 40px, 음수면 올립니다).
Future<void> _dragWheel(WidgetTester tester, Key key, int steps) async {
  await tester.drag(find.byKey(key), Offset(0, -40.0 * steps));
  await tester.pumpAndSettle();
}

/// 기본 08:00에서 07:30으로 맞춥니다(시 한 칸 위, 분 여섯 칸 아래).
Future<void> _pick0730(WidgetTester tester) async {
  await _dragWheel(tester, TimePicker.hourWheelKey, -1);
  await _dragWheel(tester, TimePicker.minuteWheelKey, 6);
}

Future<bool> _pending(WidgetTester tester, ProviderContainer container) async =>
    (await tester.runAsync(
      () => container
          .read(deviceFlagsStoreProvider)
          .readBool(notifyAskPendingKey),
    ))!;

void main() {
  testWidgets('허락: 07:30을 골라 기기를 등록하고 알림을 켠 뒤 광고 동의를 거쳐 today', (tester) async {
    covers(
      const Covers(
        exits: ['notify-ask>ad-consent', 'ad-consent>today'],
        decisions: ['D53'],
      ),
    );
    final adConsent = _CountingAdConsent();
    final container = await openNotifyAsk(
      tester,
      overrides: [adConsentProvider.overrideWithValue(adConsent)],
    );

    // 갈래의 첫 화면이라 돌아갈 곳이 없어 뒤로 버튼을 두지 않습니다.
    expect(find.byKey(const ValueKey('app-bar.back')), findsNothing);
    expect(find.text(_ko.notifyAskWhyBody), findsOneWidget);
    expect(_skipButton, findsOneWidget);
    final gathersBefore = adConsent.gathers;

    await _pick0730(tester);
    await tester.tap(_allowButton);
    await pumpUntilScreen(tester, ScreenIds.today);

    final fake = _fake(container);
    expect(fake.callCountOf('registerDevice'), 1);
    expect(
      fake.requestHeadersOf('registerDevice').single['idempotency-key'],
      matches(_uuidPattern),
    );
    expect(_bodyOf(fake.requestBodiesOf('registerDevice').single), {
      'fcmToken': 'fake-push-token',
      'platform': 'android',
    });
    expect(_notificationBody(fake), {
      'notification': {'status': 'enabled', 'time': '07:30'},
    });
    expect(
      await tester.runAsync(
        () => container
            .read(deviceFlagsStoreProvider)
            .readString(registeredDeviceIdKey),
      ),
      '7c1e4a52-9b3d-4e08-a6f1-2d5b8c0e9f34',
    );
    expect(await _pending(tester, container), isFalse);
    expect(adConsent.gathers, gathersBefore + 1);
  });

  testWidgets('허락·건너뛰기 버튼에 IA 슬롯 id가 붙습니다(D68)', (tester) async {
    await openNotifyAsk(tester);

    expect(
      find.bySemanticsIdentifier(SlotIds.notifyAskCtaAllow),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier(SlotIds.notifyAskCtaSkip),
      findsOneWidget,
    );
  });

  testWidgets('기본 시각은 08:00입니다', (tester) async {
    final container = await openNotifyAsk(tester);

    await tester.tap(_allowButton);
    await pumpUntilScreen(tester, ScreenIds.today);

    expect(_notificationBody(_fake(container)), {
      'notification': {'status': 'enabled', 'time': '08:00'},
    });
  });

  testWidgets('권한을 거절하면 기기 등록 없이 알림을 끄고 today', (tester) async {
    final container = await openNotifyAsk(
      tester,
      overrides: [
        pushMessagingProvider.overrideWithValue(
          FakePushMessaging(permissionGranted: false),
        ),
      ],
    );

    await tester.tap(_allowButton);
    await pumpUntilScreen(tester, ScreenIds.today);

    final fake = _fake(container);
    expect(fake.callCountOf('registerDevice'), 0);
    expect(_notificationBody(fake), {
      'notification': {'status': 'disabled'},
    });
    expect(await _pending(tester, container), isFalse);
  });

  testWidgets('건너뛰기: 권한을 묻지 않고 알림을 끄고 같은 흐름으로 today', (tester) async {
    final adConsent = _CountingAdConsent();
    final container = await openNotifyAsk(
      tester,
      overrides: [
        adConsentProvider.overrideWithValue(adConsent),
        // 건너뛰기는 권한 요청을 하지 않습니다.
        pushMessagingProvider.overrideWithValue(_NoPermissionPush()),
      ],
    );

    final gathersBefore = adConsent.gathers;
    await tester.tap(_skipButton);
    await pumpUntilScreen(tester, ScreenIds.today);

    final fake = _fake(container);
    expect(fake.callCountOf('registerDevice'), 0);
    expect(_notificationBody(fake), {
      'notification': {'status': 'disabled'},
    });
    expect(await _pending(tester, container), isFalse);
    expect(adConsent.gathers, gathersBefore + 1);
  });

  testWidgets('허락 버튼을 빠르게 두 번 눌러도 요청은 한 번씩입니다', (tester) async {
    final container = await openNotifyAsk(tester);

    await tester.tap(_allowButton);
    await tester.pump();
    await tester.tap(_allowButton, warnIfMissed: false);
    await tester.tap(_skipButton, warnIfMissed: false);
    await tester.pump();
    await pumpUntilScreen(tester, ScreenIds.today);

    final fake = _fake(container);
    expect(fake.callCountOf('registerDevice'), 1);
    expect(_notificationBodies(fake).length, 1);
  });

  testWidgets('기기 등록이 실패하면 안내하고, 다시 눌러도 같은 Idempotency-Key로 보냅니다', (
    tester,
  ) async {
    covers(const Covers(exits: ['notify-ask>ad-consent']));
    final container = await openNotifyAsk(
      tester,
      scenario: 'notify-register-unavailable',
    );

    await tester.tap(_allowButton);
    await pumpUntil(
      tester,
      () => find.byKey(notifyAskErrorKey).evaluate().isNotEmpty,
    );
    final fake = _fake(container);
    expect(_screen(ScreenIds.notifyAsk), findsOneWidget);
    expect(fake.callCountOf('registerDevice'), 1);
    // 등록이 안 됐으니 프로필은 건드리지 않습니다.
    expect(_notificationBodies(fake).length, 0);
    expect(await _pending(tester, container), isTrue);

    await tester.tap(_allowButton);
    await pumpUntilScreen(tester, ScreenIds.today);

    final keys = [
      for (final headers in fake.requestHeadersOf('registerDevice'))
        headers['idempotency-key'],
    ];
    expect(keys, hasLength(2));
    expect(keys.first, matches(_uuidPattern));
    expect(keys.last, keys.first);
    expect(_notificationBodies(fake).length, 1);
  });

  testWidgets('권한을 허락했지만 토큰이 없으면 기기 등록 없이 알림을 끈다', (tester) async {
    final container = await openNotifyAsk(
      tester,
      overrides: [pushMessagingProvider.overrideWithValue(_NoTokenPush())],
    );

    await tester.tap(_allowButton);
    await pumpUntilScreen(tester, ScreenIds.today);

    final fake = _fake(container);
    expect(fake.callCountOf('registerDevice'), 0);
    expect(_notificationBody(fake), {
      'notification': {'status': 'disabled'},
    });
  });

  testWidgets('등록 뒤 프로필 저장이 실패하면 다시 눌러도 기기를 다시 등록하지 않는다', (tester) async {
    final container = await openNotifyAsk(
      tester,
      scenario: 'notify-profile-save-unavailable',
    );

    await tester.tap(_allowButton);
    await pumpUntil(
      tester,
      () => find.byKey(notifyAskErrorKey).evaluate().isNotEmpty,
    );
    final fake = _fake(container);
    expect(fake.callCountOf('registerDevice'), 1);
    expect(await _pending(tester, container), isTrue);

    await tester.tap(_allowButton);
    await pumpUntilScreen(tester, ScreenIds.today);

    expect(fake.callCountOf('registerDevice'), 1);
    expect(_notificationBodies(fake), hasLength(2));
  });

  testWidgets('플랫폼 오류는 안내하고 진단만 보고한다(값은 싣지 않음)', (tester) async {
    final reporter = FakeCrashReporter();
    final container = await openNotifyAsk(
      tester,
      overrides: [
        pushMessagingProvider.overrideWithValue(_NoPermissionPush()),
        crashReporterProvider.overrideWithValue(reporter),
      ],
    );

    await tester.tap(_allowButton);
    await pumpUntil(
      tester,
      () => find.byKey(notifyAskErrorKey).evaluate().isNotEmpty,
    );

    expect(_screen(ScreenIds.notifyAsk), findsOneWidget);
    expect(reporter.errors, hasLength(1));
    expect(_fake(container).callCountOf('registerDevice'), 0);
    expect(await _pending(tester, container), isTrue);
  });

  testWidgets('끝낸 뒤 진입을 다시 계산해도 notify-ask가 다시 나오지 않습니다', (tester) async {
    final container = await openNotifyAsk(tester);
    await tester.tap(_skipButton);
    await pumpUntilScreen(tester, ScreenIds.today);

    unawaited(container.read(entryStateProvider.notifier).refresh());
    await pumpUntil(
      tester,
      () => !container.read(entryStateProvider).isLoading,
    );

    expect(_screen(ScreenIds.today), findsOneWidget);
    expect(_screen(ScreenIds.notifyAsk), findsNothing);
  });

  testWidgets('처리 중에는 두 버튼 모두 다시 받지 않습니다', (tester) async {
    await openNotifyAsk(tester);

    await tester.tap(_allowButton);
    await tester.pump();

    expect(tester.widget<PrimaryButton>(_allowButton).loading, isTrue);
    expect(tester.widget<PrimaryButton>(_skipButton).onPressed, isNull);
    await pumpUntilScreen(tester, ScreenIds.today);
  });
}

/// 토큰을 받지 못하는 대역(권한은 허락).
class _NoTokenPush extends _NoPermissionPush {
  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<String?> token() async => null;
}

/// 권한을 요청하면 실패하는 대역(건너뛰기가 권한을 묻지 않는지 확인).
class _NoPermissionPush implements PushMessaging {
  @override
  Future<bool> requestPermission() => throw StateError('권한을 요청하면 안 됩니다');

  @override
  Future<String?> token() async => 'fake-push-token';

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();

  @override
  Stream<PushOpen> get opens => const Stream.empty();

  @override
  Future<PushOpen?> initialOpen() async => null;
}
