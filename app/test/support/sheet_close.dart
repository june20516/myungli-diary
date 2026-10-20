import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// [sheet]가 든 시트를 닫고(그 navigator에서 pop) 사라졌는지 확인합니다.
///
/// 화면 좌표(바깥 누르기)에 기대지 않아, 시트 높이·글자 크기가 바뀌어도 같은 시트를 닫습니다.
/// [settle]을 주면 그것으로 기다립니다(대역 서버 I/O가 있는 흐름은 `settleWithIo`). 없으면
/// `pumpAndSettle`입니다.
Future<void> closeSheet(
  WidgetTester tester,
  Finder sheet, {
  Future<void> Function(WidgetTester tester)? settle,
}) async {
  Navigator.of(tester.element(sheet)).pop();
  await (settle ?? (t) => t.pumpAndSettle())(tester);
  expect(sheet, findsNothing);
}

/// 시트 바깥(scrim)을 누릅니다. 바깥 누르기 동작 자체를 볼 때 씁니다.
///
/// 덮개(`sheet.scrim`)의 왼쪽 위 모서리 안쪽을 누릅니다(고정 좌표가 아님). 시트는 아래에서
/// 올라오므로 그 자리는 늘 바깥이고, 시트가 쌓였으면 맨 위 층의 바깥 누르기가 받습니다.
/// Patrol의 `closeSheets`(patrol_test/support/e2e_app.dart)와 같은 자리입니다.
Future<void> tapSheetScrim(WidgetTester tester) async {
  final scrim = find.byKey(const ValueKey('sheet.scrim'));
  expect(scrim, findsWidgets);
  await tester.tapAt(tester.getTopLeft(scrim.last) + const Offset(10, 10));
}
