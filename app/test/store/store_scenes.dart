// 스토어 스크린샷 장면을 여는 방법(#1203, D133). 생성(`store_images_test.dart`)과 계약 검사
// (`store_spec_test.dart`)가 함께 씁니다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/design/components/action/share_button.dart';
import 'package:myungli_diary/design/interaction/unlock_glint.dart';
import 'package:myungli_diary/features/calendar/application/day_sheets.dart';

import '../support/app_harness.dart';
import '../support/depth_link_finders.dart';
import '../support/onboarding_steps.dart';

/// 장면을 여는 방법. 앱은 시나리오의 진입 화면(오늘)에 도착해 있습니다.
typedef SceneOpener = Future<void> Function(
  WidgetTester tester,
  ProviderContainer container,
);

/// 명세 장면(화면, 상태) → 여는 방법. 화면 렌더 사례(`test/screenshots/screens_test.dart`)와 같은
/// 조작입니다. 명세에 없는 쌍이 오면 계약 검사(`store_spec_test.dart`)가 실패합니다.
final Map<(String, String), SceneOpener> sceneOpeners = {
  (ScreenIds.today, 'default'): (tester, _) => settleWithIo(tester),
  (ScreenIds.evidenceSheet, 'unlocked'): _openEvidence,
  (ScreenIds.calendar, 'default'): _tab(1, ScreenIds.calendar),
  (ScreenIds.daySheet, 'default'): _openDaySheet,
  (ScreenIds.mySaju, 'default'): _tab(3, ScreenIds.mySaju),
  (ScreenIds.sharePreview, 'default'): _openShare,
};

/// [index]번 탭을 누릅니다.
SceneOpener _tab(int index, String screen) => (tester, _) async {
  await settleWithIo(tester);
  await tester.tap(find.byKey(ValueKey('tab-bar.tab.$index')));
  await pumpUntilScreen(tester, screen);
  await settleWithIo(tester);
};

/// 오늘 총운의 근거 시트를 열고, 반짝임 띠가 지나가지 않는 순간에 멈춥니다(명세 렌더 조건).
Future<void> _openEvidence(WidgetTester tester, ProviderContainer _) async {
  await settleWithIo(tester);
  final link = depthLinkTarget(
    of: find.byKey(const Key(SlotIds.todayFortuneHead)),
  );
  await tester.ensureVisible(link);
  await tester.tap(link);
  await settleWithIo(tester, allowOngoing: true);
  await tester.pump(const Duration(seconds: 1));
  bool sweeping() => tester.allRenderObjects.whereType<RenderUnlockGlint>().any(
    (glint) => glint.glinting,
  );
  for (var i = 0; i < 400 && sweeping(); i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(sweeping(), isFalse, reason: '반짝임 띠가 멈춘 순간을 찾지 못했습니다');
}

/// 오늘 화면 위에 일기와 일정이 있는 날(2026-10-12, 화면 렌더 사례와 같음)의 그날 시트를 엽니다.
Future<void> _openDaySheet(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await settleWithIo(tester);
  final context = tester.element(find.byKey(const ValueKey(ScreenIds.today)));
  unawaited(
    container.read(daySheetsProvider).open(context, CalendarDate(2026, 10, 12)),
  );
  await pumpUntilScreen(tester, ScreenIds.daySheet);
  await settleWithIo(tester);
}

Future<void> _openShare(WidgetTester tester, ProviderContainer _) async {
  await settleWithIo(tester);
  await tester.tap(find.byType(ShareButton));
  await settleWithIo(tester, allowOngoing: true);
  await tester.pump(const Duration(seconds: 1));
}
