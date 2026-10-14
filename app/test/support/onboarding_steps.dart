import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';

import 'app_harness.dart';

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
  await tester.tap(find.text('여성'));
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
