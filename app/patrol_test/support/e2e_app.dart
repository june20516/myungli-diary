import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart'
    show expect, find, findsNothing, findsWidgets;
import 'package:myungli_diary/app/bootstrap.dart';
import 'package:myungli_diary/app/myungli_app.dart';
import 'package:myungli_diary/core/api/http_client.dart';
import 'package:patrol/patrol.dart';

/// 지금 도는 테스트의 흐름 이름입니다. 스크린샷 이름에 붙여, 여러 테스트가 같은 화면·상태를
/// 찍어도 이름이 겹치지 않게 합니다(`launchApp`이 정합니다).
String _flow = '';

/// 흐름 이름 형식(소문자·숫자·-, 비어 있지 않음).
final _flowPattern = RegExp(r'^[a-z0-9-]+$');

/// fake 모드의 [scenario]로 앱을 띄웁니다. 모드 전환(http)은 후속 계획(A2)에서 더합니다.
///
/// [flow]는 스크린샷 이름 충돌을 막는 테스트 흐름 이름(소문자·숫자·-)입니다.
/// [deviceLocale]을 주면 기기 언어·지역을 그 값으로 고정합니다. 에뮬레이터 설정에 따라
/// 갈래(D29 출생지 입력 등)가 달라지지 않게 할 때 씁니다.
Future<ProviderContainer> launchApp(
  PatrolIntegrationTester $, {
  required String flow,
  required String scenario,
  Locale? deviceLocale,
}) async {
  assert(_flowPattern.hasMatch(flow), '흐름 이름은 소문자·숫자·-입니다: "$flow"');
  _flow = flow;
  final container = await bootstrap(
    mode: ApiMode.fake,
    scenarioId: scenario,
    deviceLocale: deviceLocale,
    // Patrol의 오류 처리를 지킵니다.
    installErrorHandlers: false,
  );
  await $.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MyungliApp()),
  );
  return container;
}

/// IA 화면 [screenId](선택: [state])에 도착했는지 보고 스크린샷을 남깁니다.
///
/// 태그는 `<화면>__<상태|default>-<흐름>`이고(흐름은 `launchApp`의 `flow`),
/// `tool/collect_e2e_screenshots.sh`가 이 이름으로 `build/e2e-screenshots/`에
/// 모읍니다. 네이티브 캡처는 Android만 동작하고 iOS에서는 아무것도 하지 않습니다
/// (Patrol 4.10).
Future<void> expectScreen(
  PatrolIntegrationTester $,
  String screenId, {
  String state = 'default',
}) async {
  await $(find.byKey(ValueKey(screenId))).waitUntilVisible();
  await $.takeNativeScreenshot('${screenId}__$state-$_flow');
}

/// IA 화면 [screenId]가 보일 때까지 기다립니다. 스크린샷을 남기지 않습니다.
///
/// 한 흐름에서 같은 화면·상태를 두 번 지날 때처럼 스크린샷 이름이 겹치는 자리에 씁니다.
Future<void> waitForScreen(PatrolIntegrationTester $, String screenId) =>
    $(find.byKey(ValueKey(screenId))).waitUntilVisible();

/// 시트 덮개(`sheet.scrim`)의 왼쪽 위 모서리 안쪽을 눌러 열린 시트를 모두 닫습니다.
///
/// 덮개는 화면 전체이고 시트가 아래쪽을 가리므로, 시트에 가려지지 않는 모서리를
/// 덮개 위치에서 구해 누릅니다(고정 좌표가 아님). 덮개에 의미 있는 탭 대상(`Semantics`)이
/// 있지만 그 자식은 `ExcludeSemantics`라 finder로 직접 누르면 가운데(시트 위)를 눌러 버립니다.
/// 시트가 쌓여 덮개가 여럿이면 맨 위(`.last`)를 누르고, 덮개가 모두 사라질 때까지 되풀이합니다.
Future<void> closeSheets(PatrolIntegrationTester $) async {
  final scrim = find.byKey(const ValueKey('sheet.scrim'));
  expect(scrim, findsWidgets);
  // 쌓일 수 있는 시트 수보다 넉넉하게 시도하고, 그래도 남으면 실패로 알립니다.
  for (var attempt = 0; attempt < 5 && scrim.evaluate().isNotEmpty; attempt++) {
    await $.tester.tapAt(
      $.tester.getTopLeft(scrim.last) + const Offset(10, 10),
    );
    await $.pumpAndTrySettle();
  }
  expect(scrim, findsNothing, reason: '열린 시트가 모두 닫혀야 합니다');
}
