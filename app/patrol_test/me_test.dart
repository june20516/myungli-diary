import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart'
    show Finder, expect, find, findsNothing, findsOneWidget;
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations.dart';
import 'package:myungli_diary/design/components/action/primary_button.dart';
import 'package:myungli_diary/design/components/input/date_picker.dart';
import 'package:myungli_diary/design/components/saju/daeun_table.dart';
import 'package:myungli_diary/design/components/saju/manse_table.dart';
import 'package:myungli_diary/design/components/saju/saju_pillars.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/features/me/presentation/my_saju_screen.dart';
import 'package:myungli_diary/features/me/presentation/settings_screen.dart';
import 'package:myungli_diary/features/profile/presentation/profile_edit_screen.dart';
import 'package:myungli_diary/testing/covers.dart';
import 'package:patrol/patrol.dart';

import 'support/e2e_app.dart';

Finder _screen(String id) => find.byKey(ValueKey(id));

/// [id] 화면(또는 시트) 안에서 [matching]을 찾습니다.
Finder _inScreen(String id, Finder matching) =>
    find.descendant(of: _screen(id), matching: matching);

/// [id] 화면(또는 시트) 안의 "근거 보기"(`depth-link`) 누를 자리.
Finder _depthLink(String id) => _inScreen(
  id,
  find.descendant(
    of: find.byType(DepthLink),
    matching: find.byType(PressInkTarget),
  ),
);

/// [done]이 참이 될 때까지 프레임을 돌립니다(대역 서버 응답·화면 움직임을 기다림).
Future<void> _waitUntil(
  PatrolIntegrationTester $,
  bool Function() done, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('$timeout 안에 조건을 만족하지 못했습니다');
    }
    await $.pump(const Duration(milliseconds: 100));
  }
}

/// 맨 위 화면의 뒤로 가기를 누릅니다.
Future<void> _back(PatrolIntegrationTester $) async {
  await $(find.byKey(const ValueKey('app-bar.back')).last).tap();
  await $.pumpAndTrySettle();
}

void main() {
  patrolTest('evidence-unlocked: 나의 사주 → 사주 표 두 탭 → 용어 → 풀이 → 근거, '
      '정보 수정에서 생일을 바꿔 저장, 로그아웃', ($) async {
    covers(
      const Covers(
        exits: [
          'my-saju>saju-chart',
          'saju-chart>explain-sheet',
          'explain-sheet>evidence-sheet',
          'my-saju>settings',
          'settings>profile-edit',
          'profile-edit>onboard-birth',
          'settings>welcome',
        ],
        decisions: ['D60'],
      ),
    );
    // 문구는 기기 언어를 따르므로 표시 언어를 한국어로 고정합니다(탭·용어 이름을 글자로 찾음).
    await launchApp(
      $,
      flow: 'me',
      scenario: 'evidence-unlocked',
      deviceLocale: const Locale('ko', 'KR'),
    );
    await waitForScreen($, ScreenIds.today);

    // 나 탭 → 나의 사주.
    await $(find.byKey(const ValueKey('tab-bar.tab.3'))).tap();
    await expectScreen($, ScreenIds.mySaju);
    final l10n = AppLocalizations.of(
      $.tester.element(_screen(ScreenIds.mySaju)),
    );

    // 근거 보기 → 사주 표(원국부터).
    await $(_depthLink(ScreenIds.mySaju)).scrollTo();
    await $(_depthLink(ScreenIds.mySaju)).tap();
    await expectScreen($, ScreenIds.sajuChart);
    await _waitUntil(
      $,
      () => _inScreen(
        ScreenIds.sajuChart,
        find.byType(SajuPillars),
      ).evaluate().isNotEmpty,
    );

    // 만세력·대운 탭 → 만세력·대운 표, 다시 원국 탭.
    await $(_inScreen(ScreenIds.sajuChart, find.text(l10n.sajuChartTabLuck)))
        .tap();
    await $(_inScreen(ScreenIds.sajuChart, find.byType(ManseTable)))
        .waitUntilVisible();
    expect(
      _inScreen(ScreenIds.sajuChart, find.byType(DaeunTable)),
      findsOneWidget,
    );
    await $.takeNativeScreenshot('${ScreenIds.sajuChart}__luck-me');
    await $(_inScreen(ScreenIds.sajuChart, find.text(l10n.sajuChartTabNatal)))
        .tap();
    await $(_inScreen(ScreenIds.sajuChart, find.byType(SajuPillars)))
        .waitUntilVisible();

    // 원국표의 십성 용어 → 풀이 시트 → 근거 보기 → 근거 시트의 "내 사주에서는".
    await $(
      _inScreen(
        ScreenIds.sajuChart,
        find.widgetWithText(TermToken, '비견'),
      ).first,
    ).tap();
    await expectScreen($, ScreenIds.explainSheet);
    await $(_depthLink(ScreenIds.explainSheet)).tap();
    await expectScreen($, ScreenIds.evidenceSheet, state: 'unlocked');
    await $(
      _inScreen(
        ScreenIds.evidenceSheet,
        find.text(l10n.evidenceSheetSectionPersonal),
      ),
    ).waitUntilVisible();
    await closeSheets($);
    expect(_screen(ScreenIds.evidenceSheet), findsNothing);

    // 사주 표 → 나의 사주 → 톱니 → 설정 → 정보 수정.
    await _back($);
    await waitForScreen($, ScreenIds.mySaju);
    await $(find.byKey(MySajuScreen.settingsKey)).tap();
    await expectScreen($, ScreenIds.settings);
    await $(find.byKey(SettingsScreen.profileEditRowKey)).tap();
    await expectScreen($, ScreenIds.profileEdit);

    // 생일 줄 → 수정 모드 생일 화면에서 일을 한 칸 내려 돌아옵니다(저장 버튼이 켜짐).
    await $(find.byKey(ProfileEditScreen.birthRowKey)).tap();
    await expectScreen($, ScreenIds.onboardBirth);
    await $.tester.drag(
      find.byKey(BirthDatePicker.dayWheelKey),
      const Offset(0, -40),
    );
    await $.pumpAndTrySettle();
    await $(find.byType(PrimaryButton)).tap();
    await waitForScreen($, ScreenIds.profileEdit);

    // 저장 → 확인 창(기본 선택 취소) → 다시 계산 → 나의 사주.
    await $(find.byKey(ProfileEditScreen.saveKey)).tap();
    await $(find.text(l10n.profileEditRecalcConfirmTitle)).waitUntilVisible();
    await $(find.text(l10n.profileEditRecalcConfirmSave)).tap();
    await _waitUntil(
      $,
      () =>
          _screen(ScreenIds.mySaju).evaluate().isNotEmpty &&
          _screen(ScreenIds.profileEdit).evaluate().isEmpty,
    );
    // 화면 도착만 확인합니다. 새 원국 내용은 흐름 테스트(me_journey_flow_test)가 봅니다.
    await expectScreen($, ScreenIds.mySaju, state: 'after-edit');

    // 톱니 → 설정 → 로그아웃 → 확인 → welcome.
    await $(find.byKey(MySajuScreen.settingsKey)).tap();
    await waitForScreen($, ScreenIds.settings);
    await $(find.byKey(SettingsScreen.logoutRowKey)).scrollTo();
    await $(find.byKey(SettingsScreen.logoutRowKey)).tap();
    await $(find.text(l10n.settingsLogoutConfirm)).waitUntilVisible();
    await $(find.text(l10n.settingsLogoutConfirmLogout).last).tap();
    await expectScreen($, ScreenIds.welcome);
    expect(_screen(ScreenIds.mySaju), findsNothing);
  });
}
