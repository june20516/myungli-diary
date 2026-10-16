import 'package:flutter/widgets.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 안내 글 화면(계산 기준 등)의 본문 골격. 문단을 위에서부터 쌓고 전체가 스크롤됩니다.
///
/// 앱 바 아래 inner 페이지 여백(좌우 `space.20`, 위 `space.24`, 아래 `space.32`)과 문단 사이
/// `space.20`을 한 곳에서 정합니다. 그리지 않을 문단은 [paragraphs]에 넣지 않으면 자리도
/// 남지 않습니다. 큰 글자·작은 화면에서도 잘리지 않고 스크롤로 닿습니다.
class ProsePageBody extends StatelessWidget {
  /// 본문 골격을 만듭니다.
  const new({required this.paragraphs, super.key});

  /// 화면에 놓을 문단(대개 `sentence-block` `body` 또는 그 자리의 skeleton).
  final List<Widget> paragraphs;

  /// 문단 사이 간격(px).
  static const double paragraphGap = Space.s20;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Space.s20,
        Space.s24,
        Space.s20,
        Space.s32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: paragraphGap,
        children: paragraphs,
      ),
    );
  }
}
