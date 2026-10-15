import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/entry/entry_providers.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/core/storage/device_flags.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';

import 'app_harness.dart';

final _ko = AppLocalizationsKo();

const Locale koreaLocale = Locale('ko', 'KR');

/// 온보딩 화면 아래쪽의 다음 버튼(`PrimaryButton`)을 누르고 이동이 끝나길 기다립니다.
Future<void> tapNext(WidgetTester tester) async {
  await tester.tap(find.byType(PrimaryButton));
  await tester.pumpAndSettle();
}

/// 파일 DB·fixture의 실제 I/O가 끝나도록 시계를 풀어 줍니다.
Future<void> settleIo(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

/// welcome(세션 있는 사용자는 onboard-call)에서 호칭·생일을 넘겨 onboard-time까지 갑니다.
Future<ProviderContainer> openTimeStep(
  WidgetTester tester, {
  String scenario = 'new-user',
  Locale locale = koreaLocale,
  List<Override> overrides = const [],
  String honorific = '별님',
}) async {
  final container = await pumpApp(
    tester,
    scenario: scenario,
    locale: locale,
    overrides: overrides,
  );
  final start = find.byKey(const ValueKey(SlotIds.welcomeCtaStart));
  if (start.evaluate().isNotEmpty) {
    await tester.tap(start);
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byType(EditableText), honorific);
  await tester.pump();
  await tapNext(tester);
  await tapNext(tester);
  expect(find.byKey(const ValueKey(ScreenIds.onboardTime)), findsOneWidget);
  return container;
}

/// 한국 기기에서 입력을 모두 마치고 성별 다음을 눌러 preview까지 갑니다.
///
/// [settle]이 false면 요청이 아직 끝나지 않은 직후에 돌려줍니다(로딩 확인용).
Future<ProviderContainer> openPreviewStep(
  WidgetTester tester, {
  String scenario = 'new-user',
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  final container = await openTimeStep(
    tester,
    scenario: scenario,
    overrides: overrides,
  );
  await tapNext(tester); // 시간 → 성별
  await tester.tap(find.text(_ko.genderFemale));
  await tester.pumpAndSettle();
  await tapNext(tester); // 성별 → preview
  expect(find.byKey(const ValueKey(ScreenIds.preview)), findsOneWidget);
  if (settle) {
    await settlePreview(tester);
  }
  return container;
}

/// preview의 요청이 끝나(skeleton이 사라질) 때까지 실제 I/O와 프레임을 번갈아 돕니다.
///
/// skeleton은 계속 움직여 `pumpAndSettle`이 끝나지 않으므로 고정 간격으로 프레임을 줍니다.
Future<void> settlePreview(WidgetTester tester) async {
  final loading = find.byKey(const ValueKey('screen-state.loading'));
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    if (loading.evaluate().isEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('미리보기 요청이 끝나지 않음');
}

/// 실제 I/O와 프레임을 번갈아 돌며 [done]이 참이 될 때까지 기다린 뒤 움직임을 끝냅니다.
///
/// 처리 중 점이 계속 숨 쉬어 `pumpAndSettle`이 끝나지 않으므로 고정 간격으로 프레임을 줍니다.
/// 끝날 때도 [settleWithIo]로 정착합니다.
///
/// 조건이 찬 뒤에도 일부러 붙잡은 응답 때문에 움직임이 이어지면 [allowOngoing]을 true로 줍니다.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  bool allowOngoing = false,
}) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (done()) {
      // 도착한 화면이 응답을 기다리며 skeleton이 숨 쉬어도 멈추지 않게 I/O와 함께 정착합니다.
      await settleWithIo(tester, allowOngoing: allowOngoing);
      return;
    }
  }
  fail('기다리던 상태가 오지 않음');
}

/// [screenId] 화면이 보일 때까지 기다립니다.
Future<void> pumpUntilScreen(WidgetTester tester, String screenId) => pumpUntil(
  tester,
  () => find.byKey(ValueKey(screenId)).evaluate().isNotEmpty,
);

/// 프로필 저장을 마친 회원이 알림 허락 대기(`notifyAskPendingKey`) 상태로 notify-ask에 닿습니다.
///
/// 앞 단계(미리보기·로그인·동의)는 다른 흐름 테스트가 덮으므로, 회원 시나리오로 띄운 뒤
/// 플래그를 켜고(광고 동의는 아직 거치지 않은 기기로 되돌리고) 진입을 다시 계산해 곧바로 들어옵니다.
Future<ProviderContainer> openNotifyAsk(
  WidgetTester tester, {
  String scenario = 'member',
  List<Override> overrides = const [],
}) async {
  final container = await pumpApp(
    tester,
    scenario: scenario,
    overrides: overrides,
  );
  final flags = container.read(deviceFlagsStoreProvider);
  await tester.runAsync(() async {
    await flags.writeBool(notifyAskPendingKey, value: true);
    // 회원 시나리오는 시작할 때 광고 동의를 이미 거칩니다. 새 계정처럼 아직 거치지 않은 기기로 되돌립니다.
    await flags.writeBool(adConsentDoneKey, value: false);
  });
  unawaited(container.read(entryStateProvider.notifier).refresh());
  await pumpUntilScreen(tester, ScreenIds.notifyAsk);
  return container;
}
