import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';

/// 화면의 app-bar 제목이 IA 슬롯 [slotId]로 그려지고 글자가 [title]인지 확인합니다.
///
/// 질문 글자와 제목 글자가 같을 수 있는 화면(온보딩 단계)을 위해 글자 찾기 대신
/// 슬롯 id로 좁힙니다. app-bar 위젯의 프로퍼티와, 렌더된 Semantics identifier 노드가 하나이고
/// 그 글자가 [title]인지를 함께 봅니다.
Future<void> expectAppBarTitle(
  WidgetTester tester,
  String slotId,
  String title,
) async {
  final appBar = find.byType(MyungliAppBar);
  expect(appBar, findsOneWidget);
  final widget = appBar.evaluate().single.widget as MyungliAppBar;
  expect(widget.titleIdentifier, slotId);
  expect(widget.title, title);

  final handle = tester.ensureSemantics();
  // 단언이 실패해도 semantics를 닫아, 다음 실패가 semantics 누수로 가려지지 않게 합니다.
  try {
    await tester.pump();
    final node = find.bySemanticsIdentifier(slotId);
    expect(node, findsOneWidget);
    expect(tester.getSemantics(node).label, title);
  } finally {
    handle.dispose();
  }
}
