import 'package:flutter/material.dart';
import 'package:myungli_diary/design/tokens/gen/tokens.g.dart';

/// 안내형 화면의 공통 골격. 위쪽 [body]와 아래쪽 [actions] 사이를 비우고,
/// 큰 글자·작은 화면에서는 전체가 스크롤됩니다(잘림 없음).
///
/// 화면이 충분히 크면 [actions]가 바닥에 붙고, 모자라면 [body] 뒤에 이어 붙어
/// 스크롤로 닿습니다. 기본은 [body]를 세로 가운데에 두고, [OnboardingPageLayout.top]은
/// 위에 붙입니다(제목 자리가 단계마다 같아야 하는 화면, 예 `account-merge`).
///
/// 입력 단계 화면은 `InputStep`을 씁니다(키보드 인셋 처리).
class OnboardingPageLayout extends StatelessWidget {
  /// 골격을 만듭니다.
  const new({required this.body, required this.actions, super.key})
    : alignTop = false;

  /// [body]를 위에 붙인 골격. 버튼은 그대로 바닥(내용이 길면 [body] 뒤)입니다.
  const new top({required this.body, required this.actions, super.key})
    : alignTop = true;

  /// 안내 글. 기본은 화면 가운데 아래로, [alignTop]이면 맨 위에 놓입니다.
  final List<Widget> body;

  /// true면 [body]를 위에 붙입니다.
  final bool alignTop;

  /// 바닥에 놓이는 버튼들.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Space.s20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!alignTop) const Spacer(),
                ...body,
                const SizedBox(height: Space.s32),
                const Spacer(),
                ...actions,
                const SizedBox(height: Space.s24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
