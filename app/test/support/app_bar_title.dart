import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/frame/app_bar.dart';

/// 화면의 app-bar 제목이 IA 슬롯 [slotId]로 그려지고 글자가 [title]인지 확인합니다.
///
/// 질문 글자와 제목 글자가 같을 수 있는 화면(온보딩 단계)을 위해 글자 찾기 대신
/// app-bar 위젯의 슬롯 id와 제목으로 좁힙니다.
void expectAppBarTitle(String slotId, String title) {
  final appBar = find.byType(MyungliAppBar);
  expect(appBar, findsOneWidget);
  final widget = appBar.evaluate().single.widget as MyungliAppBar;
  expect(widget.titleIdentifier, slotId);
  expect(widget.title, title);
}
