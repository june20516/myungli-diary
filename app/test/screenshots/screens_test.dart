// 화면별·상태별 스크린샷(#336). `tool/screens_linux.sh`가 Docker(golden과 같은 렌더)에서
// MYUNGLI_SCREENSHOTS=1로 돌리고, 결과(build/screens/<화면>__<상태>.png)를
// `tool/register_screenshots.dart --origin render`로 app/docs/artifacts/에 등록합니다.
//
// 평소 테스트와 CI에서는 건너뜁니다. 화면을 새로 만들거나 바꾼 계획 PR에서 사례를 더하고 다시
// 돌립니다(세션 마무리 체크리스트의 산출물 등록).
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/app/router/app_router.dart';
import 'package:myungli_diary/core/api/api_providers.dart';
import 'package:myungli_diary/core/api/gen/model/language.dart';
import 'package:myungli_diary/core/clock/calendar_date.dart';
import 'package:myungli_diary/core/ia/gen/ia.g.dart';
import 'package:myungli_diary/core/l10n/gen/app_localizations_ko.dart';
import 'package:myungli_diary/design/components/action/settings_row.dart';
import 'package:myungli_diary/design/components/action/share_button.dart';
import 'package:myungli_diary/design/components/saju/saju_pillars.dart';
import 'package:myungli_diary/design/components/sentence/term_token.dart';
import 'package:myungli_diary/features/calendar/application/day_sheets.dart';
import 'package:myungli_diary/features/me/presentation/settings_screen.dart';
import 'package:myungli_diary/features/me/presentation/settings_sheets.dart';

import '../support/app_harness.dart';
import '../support/chart_network.dart';
import '../support/depth_link_finders.dart';
import '../support/golden.dart';
import '../support/onboarding_steps.dart';

final bool _enabled = Platform.environment['MYUNGLI_SCREENSHOTS'] == '1';

/// 스크린샷을 쓰는 곳(스크립트가 이 디렉터리를 등록 도구에 넘김).
const String _outDir = 'build/screens';

/// 휴대폰 크기(논리 390 × 844, 2배).
const Size _phone = Size(390, 844);
const double _pixelRatio = 2;

/// 화면을 여는 방법.
typedef _Open = Future<void> Function(
  WidgetTester tester,
  ProviderContainer container,
);

/// 사례 하나: [screen] 화면의 [state] 상태를 [scenario]로 띄워 [open]으로 엽니다.
final class _Shot {
  const new(this.screen, this.state, this.scenario, this.open);

  final String screen;
  final String state;
  final String scenario;
  final _Open open;
}

/// 앱이 진입 화면에 도착한 채로 둡니다.
Future<void> _arrived(WidgetTester tester, ProviderContainer _) =>
    settleWithIo(tester);

/// [path]를 push하고 [screen]이 보일 때까지 기다립니다.
_Open _push(String path, String screen) => (tester, container) async {
  unawaited(container.read(routerProvider).push<void>(path));
  await pumpUntilScreen(tester, screen);
  await settleWithIo(tester);
};

/// [index]번 탭을 누릅니다.
_Open _tab(int index, String screen) => (tester, _) async {
  await tester.tap(find.byKey(ValueKey('tab-bar.tab.$index')));
  await pumpUntilScreen(tester, screen);
  await settleWithIo(tester);
};

/// welcome의 시작을 누르고 [steps]번 다음을 누릅니다(호칭은 "별님").
_Open _onboarding(int steps) => (tester, _) async {
  await tester.tap(find.byKey(const ValueKey(SlotIds.welcomeCtaStart)));
  await tester.pumpAndSettle();
  if (steps == 0) return;
  await tester.enterText(find.byType(EditableText), '별님');
  await tester.pump();
  for (var i = 0; i < steps; i++) {
    await tapNext(tester);
  }
};

Future<void> _todayTerm(WidgetTester tester, ProviderContainer _) async {
  await settleWithIo(tester);
  await tester.tap(find.byType(TermToken).first);
  await settleWithIo(tester);
}

Future<void> _todayEvidence(WidgetTester tester, ProviderContainer _) async {
  await settleWithIo(tester);
  final link = depthLinkTarget(
    of: find.byKey(const Key(SlotIds.todayFortuneHead)),
  );
  await tester.ensureVisible(link);
  await tester.tap(link);
  await settleWithIo(tester, allowOngoing: true);
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _todayShare(WidgetTester tester, ProviderContainer _) async {
  await settleWithIo(tester);
  await tester.tap(find.byType(ShareButton));
  await settleWithIo(tester, allowOngoing: true);
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _daySheet(WidgetTester tester, ProviderContainer container) async {
  await settleWithIo(tester);
  final context = tester.element(find.byKey(const ValueKey(ScreenIds.today)));
  unawaited(
    container.read(daySheetsProvider).open(context, CalendarDate(2026, 10, 12)),
  );
  await pumpUntilScreen(tester, ScreenIds.daySheet);
  await settleWithIo(tester);
}

/// 사주 표를 엽니다. [gate]가 있으면 대역 서버 앞에 끼우고, [after]로 화면 안을 더 조작합니다.
_Open _sajuChart({
  ChartNetwork? gate,
  Future<void> Function(WidgetTester tester)? after,
}) => (tester, container) async {
  if (gate != null) {
    final interceptors = container.read(dioProvider).interceptors;
    interceptors.insert(interceptors.length - 1, gate);
  }
  unawaited(
    container.read(routerProvider).push<void>(pathOf(ScreenIds.sajuChart)),
  );
  await pumpUntilScreen(tester, ScreenIds.sajuChart);
  if (gate != null && gate.hold) {
    // 받는 중 skeleton이 숨 쉬는 채로 찍습니다.
    await tester.pump(const Duration(seconds: 1));
    return;
  }
  await settleWithIo(tester);
  await after?.call(tester);
};

/// "만세력·대운" 탭을 누릅니다.
Future<void> _sajuLuckTab(WidgetTester tester) async {
  await tester.tap(find.text(AppLocalizationsKo().sajuChartTabLuck));
  await settleWithIo(tester);
}

/// 원국표 십성 용어 → 풀이 시트 → 근거 보기(내 사주에서는).
Future<void> _sajuPersonal(WidgetTester tester) async {
  final term = find.descendant(
    of: find.byType(SajuPillars),
    matching: find.byType(TermToken),
  );
  await tester.tap(term.first);
  await settleWithIo(tester);
  await tester.tap(
    depthLinkTarget(of: find.byKey(const Key(ScreenIds.explainSheet))),
  );
  await settleWithIo(tester, allowOngoing: true);
  await tester.pump(const Duration(seconds: 1));
}

/// 설정을 열고 [after]로 화면 안을 더 조작합니다.
_Open _settings({Future<void> Function(WidgetTester tester)? after}) =>
    (tester, container) async {
      unawaited(
        container.read(routerProvider).push<void>(pathOf(ScreenIds.settings)),
      );
      await pumpUntilScreen(tester, ScreenIds.settings);
      await settleWithIo(tester);
      await after?.call(tester);
    };

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await settleWithIo(tester);
}

/// 알림 시각 시트를 열고 켭니다.
Future<void> _settingsNotify(WidgetTester tester) async {
  await _tapAndSettle(tester, find.byKey(SettingsScreen.notifyRowKey));
  await _tapAndSettle(
    tester,
    find.descendant(
      of: find.byKey(NotifyTimeSheet.sheetKey),
      matching: find.byKey(SettingsRow.toggleKey),
    ),
  );
}

/// 언어 시트를 엽니다.
Future<void> _settingsLanguage(WidgetTester tester) =>
    _tapAndSettle(tester, find.byKey(SettingsScreen.languageRowKey));

/// 언어를 English로 바꿔 출생지 안내 시트를 띄웁니다.
Future<void> _settingsBirthplaceNotice(WidgetTester tester) async {
  await _settingsLanguage(tester);
  await _tapAndSettle(tester, find.byKey(LanguageSheet.rowKey(Language.en)));
}

/// 로그아웃 확인 창을 엽니다.
Future<void> _settingsLogout(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(SettingsScreen.logoutRowKey));
  await tester.pumpAndSettle();
  await _tapAndSettle(tester, find.byKey(SettingsScreen.logoutRowKey));
}

/// 등록할 화면·상태. 계획 2~6에서 만든 화면입니다.
final List<_Shot> _shots = [
  // 계획 2: 온보딩·로그인
  const _Shot('welcome', 'default', 'new-user', _arrived),
  const _Shot('force-update', 'default', 'force-update', _arrived),
  _Shot('onboard-call', 'default', 'new-user', _onboarding(0)),
  _Shot('onboard-birth', 'default', 'new-user', _onboarding(1)),
  _Shot('onboard-time', 'default', 'new-user', _onboarding(2)),
  _Shot('onboard-gender', 'default', 'new-user', _onboarding(3)),
  const _Shot('consent', 'default', 'consent-required', _arrived),
  _Shot('notify-ask', 'default', 'member', (tester, _) async {
    // openNotifyAsk가 앱을 다시 띄우므로 여기서는 이미 띄운 앱을 쓰지 않습니다.
  }),
  _Shot(
    'calc-basis',
    'default',
    'new-user',
    _push(pathOf(ScreenIds.calcBasis), ScreenIds.calcBasis),
  ),
  // 계획 3: 오늘·깊이 시트
  const _Shot('today', 'default', 'member', _arrived),
  const _Shot('today', 'time-unknown', 'member-time-unknown', _arrived),
  const _Shot('today', 'error', 'daily-error', _arrived),
  const _Shot('explain-sheet', 'default', 'member', _todayTerm),
  const _Shot('evidence-sheet', 'locked', 'member', _todayEvidence),
  const _Shot(
    'evidence-sheet',
    'unlocked',
    'evidence-unlocked',
    _todayEvidence,
  ),
  const _Shot('share-preview', 'default', 'member', _todayShare),
  // 계획 4: 달력·일정
  _Shot('calendar', 'default', 'member', _tab(1, ScreenIds.calendar)),
  _Shot('calendar', 'error', 'calendar-error', _tab(1, ScreenIds.calendar)),
  const _Shot('day-sheet', 'default', 'member', _daySheet),
  _Shot(
    'event-edit',
    'default',
    'member',
    _push(pathOf(ScreenIds.eventEdit), ScreenIds.eventEdit),
  ),
  // 계획 5: 일기
  _Shot('diary-list', 'default', 'member', _tab(2, ScreenIds.diaryList)),
  _Shot(
    'diary-edit',
    'default',
    'member',
    _push(
      datedPathOf(ScreenIds.diaryEdit, CalendarDate(2026, 10, 13)),
      ScreenIds.diaryEdit,
    ),
  ),
  _Shot(
    'diary-view',
    'default',
    'member',
    _push(
      datedPathOf(ScreenIds.diaryView, CalendarDate(2026, 10, 12)),
      ScreenIds.diaryView,
    ),
  ),
  _Shot(
    'tag-diary',
    'default',
    'member',
    _push(taggedPathOf('cheoneul_gwiin'), ScreenIds.tagDiary),
  ),
  // 계획 6: 나·설정
  _Shot('my-saju', 'default', 'member', _tab(3, ScreenIds.mySaju)),
  _Shot(
    'my-saju',
    'time-unknown',
    'member-time-unknown',
    _tab(3, ScreenIds.mySaju),
  ),
  _Shot('saju-chart', 'default', 'member', _sajuChart()),
  _Shot('saju-chart', 'luck', 'member', _sajuChart(after: _sajuLuckTab)),
  _Shot('saju-chart', 'unlocked', 'evidence-unlocked', _sajuChart()),
  _Shot('saju-chart', 'time-unknown', 'member-time-unknown', _sajuChart()),
  _Shot(
    'saju-chart',
    'loading',
    'member',
    _sajuChart(gate: ChartNetwork()..hold = true),
  ),
  _Shot(
    'saju-chart',
    'error',
    'member',
    _sajuChart(gate: ChartNetwork()..fail = true),
  ),
  _Shot(
    'evidence-sheet',
    'personal',
    'evidence-unlocked',
    _sajuChart(after: _sajuPersonal),
  ),
  _Shot(
    'evidence-sheet',
    'personal-locked',
    'member',
    _sajuChart(after: _sajuPersonal),
  ),
  _Shot('settings', 'default', 'member', _settings()),
  _Shot('settings', 'ad-free', 'ad-free-active', _settings()),
  _Shot(
    'settings',
    'notify-sheet',
    'member',
    _settings(after: _settingsNotify),
  ),
  _Shot(
    'settings',
    'language-sheet',
    'member',
    _settings(after: _settingsLanguage),
  ),
  _Shot(
    'settings',
    'birthplace-notice',
    'member',
    _settings(after: _settingsBirthplaceNotice),
  ),
  _Shot(
    'settings',
    'logout-confirm',
    'member',
    _settings(after: _settingsLogout),
  ),
];

/// 지금 화면 전체를 PNG로 씁니다.
Future<void> _write(WidgetTester tester, _Shot shot) async {
  final element = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('$_outDir/${shot.screen}__${shot.state}.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  for (final shot in _shots) {
    testWidgets('${shot.screen}__${shot.state} (${shot.scenario})', (
      tester,
    ) async {
      await tester.runAsync(ensureGoldenFonts);
      // 산출물에 디버그 띠를 찍지 않습니다.
      WidgetsApp.debugAllowBannerOverride = false;
      addTearDown(() => WidgetsApp.debugAllowBannerOverride = true);
      tester.view
        ..devicePixelRatio = _pixelRatio
        ..physicalSize = _phone * _pixelRatio;
      addTearDown(tester.view.reset);
      if (shot.screen == 'notify-ask') {
        await openNotifyAsk(tester);
        await settleWithIo(tester);
      } else {
        final container = await pumpApp(tester, scenario: shot.scenario);
        await shot.open(tester, container);
      }
      await _write(tester, shot);
      // 남은 타이머(toast 등)를 흘려보냅니다.
      await tester.pump(const Duration(seconds: 5));
      await settleWithIo(tester, allowOngoing: true);
    }, skip: !_enabled);
  }
}
