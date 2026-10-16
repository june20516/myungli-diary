import 'package:flutter_test/flutter_test.dart';
import 'package:myungli_diary/design/components/sentence/depth_link.dart';
import 'package:myungli_diary/design/components/sentence/press_ink_target.dart';

/// [DepthLink]의 눌리는 글자 영역. [of] 안에 있는 링크만 찾습니다.
///
/// block 링크는 줄 전체 폭을 차지해 링크 중앙을 누르면 글자를 빗나가므로,
/// 위치를 짐작하지 않고 눌림 대상 위젯을 찾아 누릅니다.
Finder depthLinkTarget({Finder? of}) {
  final link = of == null
      ? find.byType(DepthLink)
      : find.descendant(of: of, matching: find.byType(DepthLink));
  return find.descendant(of: link, matching: find.byType(PressInkTarget));
}
