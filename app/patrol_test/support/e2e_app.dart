import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' show find;
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
